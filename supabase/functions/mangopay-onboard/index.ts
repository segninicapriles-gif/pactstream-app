// Edge Function: mangopay-onboard  (Fase 2.0 — sandbox, NO mueve dinero)
//
// Crea el usuario Mangopay del usuario autenticado y guarda mangopay_user_id en
// public.users. La creación de wallet y el pay-in llegan en la Fase 2.1.
//
// Body JSON:
//   { "category": "PAYER" | "OWNER",
//     "birthday": <unix segundos>, "nationality": "ES", "country": "ES" }
//   - PAYER (promotor, solo deposita): no requiere birthday/nationality/country.
//   - OWNER (constructor, puede cobrar → KYC Mangopay): los requiere.
//     (El KYC de identidad de la app lo sigue haciendo Veriff; Mangopay pide su
//      propio KYC solo para poder pagar al beneficiario.)
//
// Env (secrets de la function): MANGOPAY_CLIENT_ID, MANGOPAY_API_KEY,
//   MANGOPAY_BASE_URL (default sandbox). Sin ellos → 503 (inerte).

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
      .select('id, full_name, email, mangopay_user_id')
      .eq('auth_provider_id', userData.user.id)
      .maybeSingle()
    if (!profile) return json({ error: 'Perfil no encontrado' }, 404)

    // Idempotente: si ya tiene usuario Mangopay, no se crea otro.
    if (profile.mangopay_user_id) {
      return json({ mangopay_user_id: profile.mangopay_user_id, already: true }, 200)
    }

    const body = await req.json().catch(() => ({}))
    const category: 'PAYER' | 'OWNER' = body?.category === 'OWNER' ? 'OWNER' : 'PAYER'
    if (category === 'OWNER' && (!body?.birthday || !body?.nationality || !body?.country)) {
      return json(
        { error: 'OWNER requiere birthday (unix), nationality y country' },
        400,
      )
    }

    const nameParts = String(profile.full_name ?? '').trim().split(/\s+/)
    const firstName = nameParts[0] || String(profile.full_name ?? '—')
    const lastName = nameParts.slice(1).join(' ') || '—'

    const mpUser = await mangopay.createNaturalUser({
      firstName,
      lastName,
      email: String(profile.email),
      category,
      birthday: body?.birthday,
      nationality: body?.nationality,
      countryOfResidence: body?.country,
    })

    await admin.from('users').update({ mangopay_user_id: mpUser.id }).eq('id', profile.id)

    return json({ mangopay_user_id: mpUser.id, category }, 200)
  } catch (error) {
    console.error('mangopay-onboard error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error creando el usuario Mangopay' }, 500)
  }
})
