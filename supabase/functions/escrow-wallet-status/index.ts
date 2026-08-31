// Edge Function: escrow-wallet-status  (proveedor-neutral — solo lectura)
//
// Devuelve el estado de cobros del usuario autenticado para la pantalla de
// ganancias: si está dado de alta en Mangopay, su nivel KYC, si tiene cuenta
// bancaria registrada, y el saldo disponible en su wallet. NO mueve dinero.
//
// Env: MANGOPAY_* (sin ellos → { configured:false }).

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

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Sesión requerida' }, 401)

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: userData, error: authErr } = await userClient.auth.getUser()
    if (authErr || !userData.user) return json({ error: 'No autenticado' }, 401)

    const escrow = getEscrowClient()
    if (!escrow) {
      return json({ configured: false, onboarded: false, kyc_level: null, has_bank_account: false, balance_cents: 0 }, 200)
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const { data: profile } = await admin
      .from('users')
      .select('id, escrow_owner_id, mangopay_bank_account_id')
      .eq('auth_provider_id', userData.user.id).maybeSingle()

    if (!profile?.escrow_owner_id) {
      return json({ configured: true, onboarded: false, kyc_level: null, has_bank_account: false, balance_cents: 0 }, 200)
    }

    const mpUserId = String(profile.escrow_owner_id)
    const kyc = await escrow.getKycLevel(mpUserId)
    const walletId = await escrow.getOrCreateEurWallet(mpUserId, `PactStream constructor ${profile.id}`)
    const balance = await escrow.getWalletBalanceCents(walletId)

    return json({
      configured: true,
      onboarded: true,
      kyc_level: kyc,
      has_bank_account: !!profile.mangopay_bank_account_id,
      balance_cents: balance,
    }, 200)
  } catch (error) {
    console.error('mangopay-wallet-status error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error consultando el estado de cobros' }, 500)
  }
})
