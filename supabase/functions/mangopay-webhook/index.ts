// Edge Function: mangopay-webhook  (Fase 2.0 — solo registra, no procesa)
//
// Mangopay notifica eventos (EventType, RessourceId, Date) por query params.
// Aquí SOLO los persistimos de forma idempotente en webhook_events; el
// procesamiento real (confirmar pay-in, disparar release/payout) llega en las
// Fases 2.1/2.2.
//
// Mangopay NO firma los webhooks con HMAC: la validez se comprueba re-consultando
// el recurso vía API (pendiente 2.1). Por eso signature_valid queda null.
//
// Desplegar con --no-verify-jwt (Mangopay no envía JWT de Supabase).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4'
import { getMangopayClient } from '../_shared/mangopay.ts'

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function makeAdmin() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
}

async function markProcessed(
  admin: ReturnType<typeof makeAdmin>,
  externalId: string,
  result: string,
): Promise<void> {
  await admin.from('webhook_events').update({
    processed_at: new Date().toISOString(),
    processed_result: result,
  }).eq('provider', 'mangopay').eq('external_id', externalId)
}

serve(async (req: Request) => {
  try {
    const url = new URL(req.url)
    const eventType = url.searchParams.get('EventType')
    const ressourceId = url.searchParams.get('RessourceId')
    if (!eventType || !ressourceId) {
      return json({ error: 'Faltan EventType/RessourceId' }, 400)
    }

    const admin = makeAdmin()

    // Idempotencia por (provider, external_id). Un mismo recurso genera varios
    // tipos de evento, así que combinamos ambos para no colisionar entre ellos.
    const externalId = `${ressourceId}:${eventType}`
    await admin.from('webhook_events').upsert(
      {
        provider: 'mangopay',
        external_id: externalId,
        event_type: eventType,
        payload: Object.fromEntries(url.searchParams),
        // processed_at / processed_result quedan null: sin procesar todavía (2.1).
      },
      { onConflict: 'provider,external_id', ignoreDuplicates: true },
    )

    // Procesamiento (Fase 2.1): confirmar el pay-in del depósito inicial.
    if (eventType === 'PAYIN_NORMAL_SUCCEEDED' || eventType === 'PAYIN_NORMAL_FAILED') {
      const { data: pay } = await admin
        .from('payments').select('id, pact_id, state')
        .eq('mangopay_transaction_id', ressourceId).maybeSingle()

      // Idempotencia: solo si el pago sigue pendiente (created/pending).
      if (pay && pay.state !== 'succeeded' && pay.state !== 'failed') {
        const nowIso = new Date().toISOString()

        if (eventType === 'PAYIN_NORMAL_FAILED') {
          await admin.from('payments').update({
            state: 'failed', failed_at: nowIso, last_webhook_at: nowIso,
            failure_reason: 'Mangopay PAYIN_NORMAL_FAILED',
          }).eq('id', pay.id)
          await markProcessed(admin, externalId, 'success')
        } else {
          // SUCCEEDED: verificar contra la API de Mangopay (fuente de verdad).
          const mangopay = getMangopayClient()
          if (mangopay) {
            const pin = await mangopay.getPayIn(ressourceId)
            if (pin.status === 'SUCCEEDED') {
              await admin.from('payments').update({
                state: 'succeeded', succeeded_at: nowIso, last_webhook_at: nowIso,
              }).eq('id', pay.id)
              // Ledger real de custodia (idempotente, service_role).
              await admin.rpc('sf_pact_confirm_payin', {
                p_pact_id: pay.pact_id,
                p_amount_cents: pin.creditedAmountCents,
                p_payin_id: ressourceId,
              })
              await markProcessed(admin, externalId, 'success')
            }
          }
        }
      }
    }

    // Procesamiento (Fase 2.3): resultado del payout (cash-out a banco).
    if (eventType === 'PAYOUT_NORMAL_SUCCEEDED' || eventType === 'PAYOUT_NORMAL_FAILED') {
      const { data: po } = await admin
        .from('payouts').select('id, state')
        .eq('mangopay_payout_id', ressourceId).maybeSingle()
      if (po && po.state === 'pending') {
        const nowIso = new Date().toISOString()
        if (eventType === 'PAYOUT_NORMAL_SUCCEEDED') {
          await admin.from('payouts')
            .update({ state: 'succeeded', succeeded_at: nowIso }).eq('id', po.id)
        } else {
          await admin.from('payouts').update({
            state: 'failed', failed_at: nowIso,
            failure_reason: 'Mangopay PAYOUT_NORMAL_FAILED',
          }).eq('id', po.id)
        }
        await markProcessed(admin, externalId, 'success')
      }
    }

    // Siempre 200: Mangopay reintenta el hook si no recibe 200.
    return json({ received: true }, 200)
  } catch (error) {
    console.error('mangopay-webhook error:', error instanceof Error ? error.message : error)
    // 200 igualmente para no provocar reintentos en un fallo nuestro de registro;
    // el evento se puede reconciliar re-consultando Mangopay (2.1).
    return json({ received: true }, 200)
  }
})
