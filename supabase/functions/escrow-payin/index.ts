// Edge Function: escrow-payin  (proveedor-neutral vía getEscrowClient)
//
// Inicia el depósito inicial de un pacto vía Bankwire PayIn de Mangopay:
//   1. Asegura la wallet de custodia del pacto (pacts.mangopay_wallet_id).
//   2. Crea el Bankwire PayIn por el importe del depósito requerido.
//   3. Registra un `payments` (pay_in, created) y guarda el IBAN en el pacto.
//   4. Devuelve IBAN/BIC/referencia para que el promotor haga la transferencia.
//
// El dinero NO entra aquí: entra cuando el promotor transfiere y Mangopay lo
// confirma vía `mangopay-webhook` → `sf_pact_confirm_payin`.
//
// Body: { "pact_id": "<uuid>" }
// Env: MANGOPAY_* (sin ellos → 503).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4'
import { getEscrowClient } from '../_shared/escrow.ts'

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405)

  try {
    const escrow = getEscrowClient()
    if (!escrow) return json({ error: 'Proveedor de escrow no configurado' }, 503)

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Sesión requerida' }, 401)

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: userData, error: authErr } = await userClient.auth.getUser()
    if (authErr || !userData.user) return json({ error: 'No autenticado' }, 401)

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: profile } = await admin
      .from('users').select('id, mangopay_user_id')
      .eq('auth_provider_id', userData.user.id).maybeSingle()
    if (!profile) return json({ error: 'Perfil no encontrado' }, 404)
    if (!profile.mangopay_user_id) {
      return json({ error: 'El promotor debe completar el alta en el proveedor de escrow primero (onboard)' }, 409)
    }

    const body = await req.json().catch(() => ({}))
    const pactId: string | undefined = body?.pact_id
    if (!pactId) return json({ error: 'Falta pact_id' }, 400)

    const { data: pact } = await admin
      .from('pacts')
      .select('id, state, model_version, total_amount_cents, deposit_required_pct, mangopay_wallet_id')
      .eq('id', pactId).maybeSingle()
    if (!pact) return json({ error: 'Pacto no encontrado' }, 404)

    // El caller debe ser el promotor del pacto.
    const { data: party } = await admin
      .from('pact_parties').select('role')
      .eq('pact_id', pactId).eq('user_id', profile.id).maybeSingle()
    if (party?.role !== 'promotor') {
      return json({ error: 'Solo el promotor puede iniciar el depósito' }, 403)
    }
    if (pact.state !== 'signed') {
      return json({ error: `El pacto no está en 'signed' (actual: ${pact.state})` }, 409)
    }
    if (pact.model_version !== 'v2') {
      return json({ error: 'Pay-in solo aplica a pacts v2' }, 409)
    }

    const amountCents = Math.floor(
      Number(pact.total_amount_cents) * Number(pact.deposit_required_pct) / 100,
    )
    if (!(amountCents > 0)) return json({ error: 'Importe de depósito inválido' }, 400)

    // 1. Wallet de custodia por pacto (idempotente: crea solo si falta).
    let walletId: string = pact.mangopay_wallet_id ?? ''
    if (!walletId) {
      const wallet = await escrow.createWallet(
        String(profile.mangopay_user_id), `PactStream custodia ${pact.id}`,
      )
      walletId = wallet.id
      await admin.from('pacts').update({ mangopay_wallet_id: walletId }).eq('id', pact.id)
    }

    // 2. ¿Ya hay un pay-in en curso? Reusar y re-consultar sus datos bancarios.
    const { data: existing } = await admin
      .from('payments')
      .select('mangopay_transaction_id, state')
      .eq('pact_id', pact.id).eq('payment_type', 'pay_in')
      .in('state', ['created', 'pending'])
      .maybeSingle()
    if (existing?.mangopay_transaction_id) {
      const pin = await escrow.getPayIn(existing.mangopay_transaction_id)
      return json({
        payin_id: pin.id, status: pin.status, amount_cents: amountCents,
        iban: pin.iban, bic: pin.bic, owner_name: pin.ownerName, wire_reference: pin.wireReference,
        reused: true,
      }, 200)
    }

    // 3. Crear el Bankwire PayIn.
    const payin = await escrow.createBankwirePayIn(
      String(profile.mangopay_user_id), walletId, amountCents,
    )

    await admin.from('payments').insert({
      pact_id: pact.id,
      payment_type: 'pay_in',
      amount_cents: amountCents,
      state: 'created',
      source_user_id: profile.id,
      mangopay_transaction_id: payin.id,
      mangopay_wallet_id: walletId,
      // Única por pay-in (no por pacto): un reintento tras fallo crea un pay-in
      // nuevo con su propia key. La regla "un pay-in activo por pacto" la impone
      // la consulta de pendientes de arriba, no esta clave.
      idempotency_key: `payin:${payin.id}`,
    })
    await admin.from('pacts').update({ iban_custodia: payin.iban }).eq('id', pact.id)

    return json({
      payin_id: payin.id,
      status: payin.status,
      amount_cents: amountCents,
      iban: payin.iban,
      bic: payin.bic,
      owner_name: payin.ownerName,
      wire_reference: payin.wireReference,
    }, 200)
  } catch (error) {
    console.error('mangopay-payin error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error iniciando el depósito' }, 500)
  }
})
