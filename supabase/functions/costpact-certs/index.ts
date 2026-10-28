// Edge Function: costpact-certs  (puente del ecosistema, CostPact → PactStream)
//
// Certificaciones de CostPact del presupuesto de un pacto, para que el
// constructor enlace cada hito con la certificación que lo factura
// (sf_link_costpact_cert). Solo lectura. La llama la app con la sesión del
// usuario; la clave del puente vive aquí como secreto, nunca en el cliente.
//
// Body: { "pact_id": "<uuid>" }
// Env: COSTPACT_BRIDGE_URL (base /api/bridge de CostPact) + COSTPACT_BRIDGE_KEY.
//      Sin ellos → 503.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4'

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

  const bridgeUrl = Deno.env.get('COSTPACT_BRIDGE_URL')
  const bridgeKey = Deno.env.get('COSTPACT_BRIDGE_KEY')
  if (!bridgeUrl || !bridgeKey) return json({ error: 'Puente con CostPact no configurado' }, 503)

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
  const body = await req.json().catch(() => ({}))
  const pactId: string | undefined = body?.pact_id
  if (!pactId) return json({ error: 'Falta pact_id' }, 400)

  // Solo las partes del pacto ven las certificaciones de su presupuesto.
  const { data: profile } = await admin
    .from('users').select('id').eq('auth_provider_id', userData.user.id).maybeSingle()
  const { data: party } = await admin
    .from('pact_parties').select('role').eq('pact_id', pactId).eq('user_id', profile?.id ?? '').maybeSingle()
  if (!party) return json({ error: 'No eres parte de este pacto' }, 403)

  const { data: meta } = await admin
    .from('pact_metadata').select('value')
    .eq('pact_id', pactId).eq('key', 'costpact_presupuesto_id').maybeSingle()
  const presupuestoId = meta?.value?.trim()
  if (!presupuestoId) return json({ certificaciones: [], reason: 'Pacto sin presupuesto CostPact enlazado' }, 200)

  const resp = await fetch(
    `${bridgeUrl.replace(/\/$/, '')}/certificaciones?presupuesto_id=${encodeURIComponent(presupuestoId)}`,
    { headers: { 'x-bridge-key': bridgeKey } },
  ).catch(() => null)
  if (!resp || !resp.ok) {
    console.error('[costpact-certs] CostPact respondió', resp?.status)
    return json({ error: 'No se pudieron leer las certificaciones de CostPact' }, 502)
  }
  const data = await resp.json().catch(() => ({}))

  // Qué certificaciones ya facturan otro hito de este pacto.
  const { data: usados } = await admin
    .from('milestones').select('id, costpact_certificacion_id')
    .eq('pact_id', pactId).not('costpact_certificacion_id', 'is', null)
  const enlazadas: Record<string, string> = {}
  for (const m of usados ?? []) enlazadas[m.costpact_certificacion_id] = m.id

  return json({
    certificaciones: (data?.certificaciones ?? []).map((c: Record<string, unknown>) => ({
      ...c,
      milestone_id: enlazadas[String(c.id)] ?? null,
    })),
  }, 200)
})
