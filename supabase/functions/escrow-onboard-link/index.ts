// Edge Function: escrow-onboard-link  (proveedor-neutral — NO mueve dinero)
//
// Genera el enlace de onboarding ALOJADO (KYC) para que el CONSTRUCTOR (OWNER)
// complete su verificación de identidad con el proveedor de escrow. Es la pieza
// que "activa cobros": sin completar este KYC, la capability de transferencias de
// su cuenta conectada queda 'inactive' y tanto la liberación de hitos (transfer)
// como la retirada a banco (payout) se rechazan.
//
// Hace dos cosas, de forma idempotente:
//   1. Asegura que el usuario tiene cuenta conectada OWNER (acct_… en Stripe). Si
//      no la tiene, la crea aquí — el proveedor alojado recoge fecha de nacimiento,
//      nacionalidad, etc., así que NO se piden por adelantado (a diferencia de
//      escrow-onboard, herencia del KYC-por-API de Mangopay).
//   2. Pide un Account Link de un solo uso (caduca ~10 min) y devuelve su URL para
//      que la app la abra en el navegador. Sirve tanto para el alta inicial como
//      para reanudar un KYC incompleto.
//
// El estado de la verificación NO se persiste aquí: escrow-wallet-status lo lee EN
// VIVO del proveedor (getKycLevel) tras volver del enlace. El webhook de capability
// solo se registra para auditoría (ver stripe-webhook).
//
// Restringida a primary_role='constructor' (403 en otro caso): escribe una cuenta
// OWNER en users.mangopay_user_id, columna compartida con el cus_ del promotor.
//
// Body JSON (opcional): { "country": "ES" }   // país de la cuenta (ISO-2), default ES.
// Env: STRIPE_SECRET_KEY (o proveedor equivalente) → sin credenciales, 503 (inerte).
//   ESCROW_ONBOARD_RETURN_URL  (default https://pactstream.io/escrow/onboarding-complete)
//   ESCROW_ONBOARD_REFRESH_URL (default https://pactstream.io/escrow/onboarding-refresh)

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
      .from('users')
      .select('id, full_name, email, mangopay_user_id, primary_role')
      .eq('auth_provider_id', userData.user.id)
      .maybeSingle()
    if (!profile) return json({ error: 'Perfil no encontrado' }, 404)

    // Solo el CONSTRUCTOR pasa por aquí. No es una restricción cosmética: esta función
    // escribe una cuenta OWNER (acct_…) en users.mangopay_user_id, la MISMA columna que
    // escrow-payin lee para el promotor (donde debe haber un cus_). Si un promotor la
    // invocase, su pay-in quedaría roto de forma permanente — escrow-onboard ve la
    // columna poblada, devuelve `already: true` y no la sobrescribe nunca.
    if (profile.primary_role !== 'constructor') {
      return json({ error: 'Solo el constructor verifica su identidad para cobros' }, 403)
    }

    const body = await req.json().catch(() => ({}))
    const country: string = (body?.country ?? 'ES').toString().trim().toUpperCase() || 'ES'

    // 1 · Asegurar cuenta conectada OWNER (idempotente).
    let accountId = profile.mangopay_user_id ? String(profile.mangopay_user_id) : ''
    if (!accountId) {
      const nameParts = String(profile.full_name ?? '').trim().split(/\s+/)
      const firstName = nameParts[0] || String(profile.full_name ?? '—')
      const lastName = nameParts.slice(1).join(' ') || '—'

      const owner = await escrow.createNaturalUser({
        firstName,
        lastName,
        email: String(profile.email),
        category: 'OWNER',
        countryOfResidence: country,
      })
      accountId = owner.id
      await admin.from('users').update({ mangopay_user_id: accountId }).eq('id', profile.id)
    }

    // 2 · Generar el Account Link (un solo uso). URLs de retorno configurables: la
    // app re-consulta wallet-status al reanudar, así que la página de retorno solo
    // necesita existir (no hay deep link).
    const returnUrl = Deno.env.get('ESCROW_ONBOARD_RETURN_URL') ??
      'https://pactstream.io/escrow/onboarding-complete'
    const refreshUrl = Deno.env.get('ESCROW_ONBOARD_REFRESH_URL') ??
      'https://pactstream.io/escrow/onboarding-refresh'

    const link = await escrow.createOnboardingLink(accountId, returnUrl, refreshUrl)

    return json({ url: link.url, account_id: accountId, expires_at: link.expiresAt ?? null }, 200)
  } catch (error) {
    console.error('escrow-onboard-link error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error generando el enlace de verificación de cobros' }, 500)
  }
})
