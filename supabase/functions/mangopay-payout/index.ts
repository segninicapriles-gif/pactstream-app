// Edge Function: mangopay-payout  (Fase 2.3 — sandbox)
//
// El constructor retira su saldo de la wallet Mangopay a su banco (PayOut
// Bankwire). ASÍNCRONO: el estado final llega por webhook PAYOUT_NORMAL_*.
// Registra la operación en la tabla `payouts` (state 'pending').
//
// Requisitos (Mangopay los exige): usuario OWNER con KYC 'REGULAR' + cuenta
// bancaria registrada (mangopay-bank-account). Si el KYC no está verificado,
// devolvemos 409 con mensaje claro.
//
// Body: { "amount_cents"?: number }  // opcional; por defecto retira TODO el saldo.
// Env: MANGOPAY_* (sin ellos → 503).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4'
import { getMangopayClient } from '../_shared/mangopay.ts'

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
    const mangopay = getMangopayClient()
    if (!mangopay) return json({ error: 'Mangopay no configurado' }, 503)

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
      .from('users')
      .select('id, mangopay_user_id, mangopay_bank_account_id')
      .eq('auth_provider_id', userData.user.id).maybeSingle()
    if (!profile?.mangopay_user_id) {
      return json({ error: 'No estás dado de alta en Mangopay' }, 409)
    }
    if (!profile.mangopay_bank_account_id) {
      return json({ error: 'Registra primero tu cuenta bancaria' }, 409)
    }

    const mpUserId = String(profile.mangopay_user_id)

    // Prerrequisito duro de Mangopay: KYC REGULAR para poder cobrar.
    const kyc = await mangopay.getKycLevel(mpUserId)
    if (kyc !== 'REGULAR') {
      return json({ error: 'Tu verificación KYC de Mangopay está pendiente; no puedes retirar todavía' }, 409)
    }

    const walletId = await mangopay.getOrCreateEurWallet(
      mpUserId, `PactStream constructor ${profile.id}`,
    )
    const balance = await mangopay.getWalletBalanceCents(walletId)

    const body = await req.json().catch(() => ({}))
    const requested = Number(body?.amount_cents ?? balance)
    const amountCents = Math.min(requested, balance)
    if (!(amountCents > 0)) return json({ error: 'No hay saldo disponible para retirar' }, 400)

    const payout = await mangopay.createBankwirePayout(
      mpUserId, walletId, String(profile.mangopay_bank_account_id), amountCents,
    )

    await admin.from('payouts').insert({
      user_id: profile.id,
      mangopay_payout_id: payout.id,
      mangopay_bank_account_id: profile.mangopay_bank_account_id,
      amount_cents: amountCents,
      state: 'pending',
    })

    return json({ payout_id: payout.id, status: payout.status, amount_cents: amountCents }, 200)
  } catch (error) {
    console.error('mangopay-payout error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error solicitando la retirada' }, 500)
  }
})
