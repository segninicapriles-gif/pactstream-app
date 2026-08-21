// Edge Function: escrow-release  (proveedor-neutral vía getEscrowClient)
//
// Al aprobar un hito (en modo ESCROW_PROVIDER=mangopay), libera el neto de la
// certificación: Transfer escrow-wallet → wallet del constructor (síncrono) y,
// si SUCCEEDED, confirma en BBDD vía sf_milestone_confirm_release (decremento
// de custodia + hito 'paid'). El PayOut a banco es Fase 2.3.
//
// Body: { "milestone_id": "<uuid>" }
// Env: MANGOPAY_* (sin ellos → 503).
//
// Idempotente: si el hito ya está 'paid' o ya hay un release registrado, NO
// vuelve a transferir (evita doble pago en reintentos).

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
    if (!profile?.mangopay_user_id) {
      return json({ error: 'El promotor no está dado de alta en el proveedor de escrow' }, 409)
    }

    const body = await req.json().catch(() => ({}))
    const milestoneId: string | undefined = body?.milestone_id
    if (!milestoneId) return json({ error: 'Falta milestone_id' }, 400)

    const { data: ms } = await admin
      .from('milestones')
      .select('id, pact_id, state, amount_cents, net_amount_cents')
      .eq('id', milestoneId).maybeSingle()
    if (!ms) return json({ error: 'Hito no encontrado' }, 404)

    // Idempotencia ANTES de mover dinero: si ya hay release, no repetir.
    if (ms.state === 'paid') return json({ already: true }, 200)
    const { data: existingRel } = await admin
      .from('payments').select('id')
      .eq('milestone_id', milestoneId).eq('payment_type', 'milestone_release')
      .maybeSingle()
    if (existingRel) return json({ already: true }, 200)

    const { data: pact } = await admin
      .from('pacts').select('id, pact_type, mangopay_wallet_id')
      .eq('id', ms.pact_id).maybeSingle()
    if (!pact) return json({ error: 'Pacto no encontrado' }, 404)
    if (!pact.mangopay_wallet_id) {
      return json({ error: 'El pacto no tiene custodia de escrow (sin pay-in)' }, 409)
    }

    // El caller debe ser el promotor del pacto.
    const { data: promotorParty } = await admin
      .from('pact_parties').select('role')
      .eq('pact_id', pact.id).eq('user_id', profile.id).maybeSingle()
    if (promotorParty?.role !== 'promotor') {
      return json({ error: 'Solo el promotor puede liberar el hito' }, 403)
    }

    // Estado liberable (el RPC hará la cascada de obra menor si aplica).
    const releasable = ms.state === 'awaiting_promotor' ||
      (pact.pact_type === 'obra_menor' && ms.state === 'ready_for_review')
    if (!releasable) {
      return json({ error: `El hito no está listo para liberar (estado: ${ms.state})` }, 409)
    }

    const netCents = Number(ms.net_amount_cents ?? ms.amount_cents)
    if (!(netCents > 0)) return json({ error: 'Neto del hito inválido' }, 400)

    // Wallet destino del constructor (descubierta o creada vía API).
    const { data: constructorParty } = await admin
      .from('pact_parties').select('user_id')
      .eq('pact_id', pact.id).eq('role', 'constructor').maybeSingle()
    if (!constructorParty?.user_id) return json({ error: 'Pacto sin constructor' }, 409)

    const { data: constructorUser } = await admin
      .from('users').select('mangopay_user_id')
      .eq('id', constructorParty.user_id).maybeSingle()
    if (!constructorUser?.mangopay_user_id) {
      return json({ error: 'El constructor no está dado de alta en el proveedor de escrow' }, 409)
    }

    const constructorWalletId = await escrow.getOrCreateEurWallet(
      String(constructorUser.mangopay_user_id),
      `PactStream constructor ${constructorParty.user_id}`,
    )

    // Transfer SÍNCRONO escrow → constructor. Solo si SUCCEEDED marcamos paid.
    const transfer = await escrow.createTransfer(
      String(profile.mangopay_user_id),
      String(pact.mangopay_wallet_id),
      constructorWalletId,
      netCents,
    )
    if (transfer.status !== 'SUCCEEDED') {
      return json({ error: `Transfer no completado (estado: ${transfer.status})`, transfer_id: transfer.id }, 502)
    }

    // Ledger + hito 'paid' (idempotente, service_role).
    const { error: rpcErr } = await admin.rpc('sf_milestone_confirm_release', {
      p_milestone_id: milestoneId,
      p_amount_cents: netCents,
      p_transfer_id: transfer.id,
    })
    if (rpcErr) {
      // El dinero YA se movió pero el ledger falló → reconciliación manual.
      console.error('RELEASE RECONCILE: transfer', transfer.id, 'ok pero RPC falló:', rpcErr.message)
      return json({
        error: 'Transfer realizado pero el registro falló; requiere reconciliación',
        transfer_id: transfer.id,
      }, 500)
    }

    return json({ transfer_id: transfer.id, released_cents: netCents }, 200)
  } catch (error) {
    console.error('mangopay-release error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error liberando el hito' }, 500)
  }
})
