// Edge Function: escrow-bank-account  (proveedor-neutral vía getEscrowClient)
//
// El constructor registra su cuenta bancaria IBAN (destino del payout). Guarda
// el id en users.mangopay_bank_account_id. NO mueve dinero.
//
// Body: { "owner_name", "iban",
//         "address": { "line1", "city", "postal_code", "country" } }
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
    if (!profile?.mangopay_user_id) {
      return json({ error: 'Debes completar el alta en el proveedor de escrow primero (onboard OWNER)' }, 409)
    }

    const body = await req.json().catch(() => ({}))
    const ownerName: string = (body?.owner_name ?? '').toString().trim()
    const iban: string = (body?.iban ?? '').toString().replace(/\s+/g, '')
    const addr = body?.address ?? {}
    if (!ownerName || !iban) return json({ error: 'Faltan owner_name o iban' }, 400)

    const account = await escrow.createIbanBankAccount(
      String(profile.mangopay_user_id),
      ownerName,
      iban,
      {
        line1: (addr.line1 ?? '—').toString(),
        city: (addr.city ?? '—').toString(),
        postalCode: (addr.postal_code ?? '00000').toString(),
        country: (addr.country ?? 'ES').toString(),
      },
    )

    await admin.from('users')
      .update({ mangopay_bank_account_id: account.id }).eq('id', profile.id)

    return json({ bank_account_id: account.id }, 200)
  } catch (error) {
    console.error('mangopay-bank-account error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error registrando la cuenta bancaria' }, 500)
  }
})
