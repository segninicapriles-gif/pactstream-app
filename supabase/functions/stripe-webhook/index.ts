// Edge Function: stripe-webhook
//
// Recibe eventos de Stripe (Connect) para el flujo de escrow y los procesa:
//   · payment_intent.succeeded   → confirma el pay-in del depósito (sf_pact_confirm_payin).
//   · payment_intent.payment_failed → marca el pago 'failed'.
//   · payout.paid / payout.failed → actualiza la fila de `payouts`.
//
// A diferencia de MangoPay (query params sin firma), Stripe firma el cuerpo con
// HMAC-SHA256 (cabecera Stripe-Signature). La AUTENTICIDAD se comprueba con
// STRIPE_WEBHOOK_SECRET sobre el cuerpo CRUDO — por eso se lee req.text() antes de
// parsear. Sin ese secret → 503 (inerte).
//
// Desplegar con --no-verify-jwt: Stripe no envía JWT de Supabase; la firma ES la auth.
// El endpoint escucha eventos de la plataforma Y de cuentas conectadas (payout.*).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4'
import { verifyStripeSignature } from '../_shared/stripe.ts'

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
  }).eq('provider', 'stripe').eq('external_id', externalId)
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405)

  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')
  if (!webhookSecret) return json({ error: 'Webhook de Stripe no configurado' }, 503)

  // Cuerpo CRUDO (necesario para verificar la firma).
  const raw = await req.text()
  const valid = await verifyStripeSignature(raw, req.headers.get('Stripe-Signature'), webhookSecret)
  if (!valid) return json({ error: 'Firma inválida' }, 400)

  let event: Record<string, unknown>
  try {
    event = JSON.parse(raw)
  } catch {
    return json({ error: 'JSON inválido' }, 400)
  }

  const eventId = String(event.id ?? '')
  const eventType = String(event.type ?? '')
  const dataObject = ((event.data as Record<string, unknown>)?.object as Record<string, unknown>) ?? {}
  if (!eventId || !eventType) return json({ error: 'Evento sin id/type' }, 400)

  try {
    const admin = makeAdmin()

    // Idempotencia por (provider, external_id=evt_id). El id de evento de Stripe es único.
    await admin.from('webhook_events').upsert(
      {
        provider: 'stripe',
        external_id: eventId,
        event_type: eventType,
        payload: event,
      },
      { onConflict: 'provider,external_id', ignoreDuplicates: true },
    )

    // ── Depósito inicial (pay-in) ──────────────────────────────────────────
    if (eventType === 'payment_intent.succeeded' || eventType === 'payment_intent.payment_failed') {
      const piId = String(dataObject.id ?? '')
      const { data: pay } = await admin
        .from('payments').select('id, pact_id, state')
        .eq('mangopay_transaction_id', piId).maybeSingle()

      if (pay && pay.state !== 'succeeded' && pay.state !== 'failed') {
        const nowIso = new Date().toISOString()
        if (eventType === 'payment_intent.payment_failed') {
          await admin.from('payments').update({
            state: 'failed', failed_at: nowIso, last_webhook_at: nowIso,
            failure_reason: 'Stripe payment_intent.payment_failed',
          }).eq('id', pay.id)
          await markProcessed(admin, eventId, 'success')
        } else {
          const creditedCents = Number(dataObject.amount_received ?? dataObject.amount ?? 0)
          await admin.from('payments').update({
            state: 'succeeded', succeeded_at: nowIso, last_webhook_at: nowIso,
          }).eq('id', pay.id)
          // Ledger real de custodia (idempotente, service_role).
          await admin.rpc('sf_pact_confirm_payin', {
            p_pact_id: pay.pact_id,
            p_amount_cents: creditedCents,
            p_payin_id: piId,
          })
          await markProcessed(admin, eventId, 'success')
        }
      }
    }

    // ── Cash-out (payout) ──────────────────────────────────────────────────
    if (eventType === 'payout.paid' || eventType === 'payout.failed') {
      const poId = String(dataObject.id ?? '')
      const { data: po } = await admin
        .from('payouts').select('id, state')
        .eq('mangopay_payout_id', poId).maybeSingle()
      if (po && po.state === 'pending') {
        const nowIso = new Date().toISOString()
        if (eventType === 'payout.paid') {
          await admin.from('payouts')
            .update({ state: 'succeeded', succeeded_at: nowIso }).eq('id', po.id)
        } else {
          await admin.from('payouts').update({
            state: 'failed', failed_at: nowIso,
            failure_reason: 'Stripe payout.failed',
          }).eq('id', po.id)
        }
        await markProcessed(admin, eventId, 'success')
      }
    }

    // 200: Stripe reintenta si no recibe 2xx.
    return json({ received: true }, 200)
  } catch (error) {
    console.error('stripe-webhook error:', error instanceof Error ? error.message : error)
    // 200 igualmente: el evento firmado ya quedó registrado y se puede reconciliar.
    return json({ received: true }, 200)
  }
})
