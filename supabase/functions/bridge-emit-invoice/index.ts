// Edge Function: bridge-emit-invoice  (puente del ecosistema R3, sentido
// PactStream → FiscalCore/CostPact)
//
// Al aprobarse un hito, PactStream pide a CostPact que emita la factura
// Verifactu de esa certificación. Server-to-server: la clave del puente
// (INVOICE_BRIDGE_KEY) vive como secreto de la función, NUNCA en el cliente.
//
// Body: { "milestone_id": "<uuid>" }
// Env: INVOICE_BRIDGE_URL (endpoint emit-invoice-external de CostPact) +
//      INVOICE_BRIDGE_KEY. Sin ellos → 503 (inerte). Idempotencia la garantiza
//      el lado CostPact por ref_externa = 'ps:milestone:<id>'.
//
// No bloqueante: el fallo aquí NO revierte la aprobación del hito. El caller
// (Flutter) lo invoca en fire-and-forget tras aprobar.

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

  try {
    const bridgeUrl = Deno.env.get('INVOICE_BRIDGE_URL')
    const bridgeKey = Deno.env.get('INVOICE_BRIDGE_KEY')
    if (!bridgeUrl || !bridgeKey) return json({ error: 'Puente de facturación no configurado' }, 503)

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
    const milestoneId: string | undefined = body?.milestone_id
    if (!milestoneId) return json({ error: 'Falta milestone_id' }, 400)

    const { data: ms } = await admin
      .from('milestones').select('id, pact_id, amount_cents, name')
      .eq('id', milestoneId).maybeSingle()
    if (!ms) return json({ error: 'Hito no encontrado' }, 404)

    // Autorización: el caller debe ser el promotor del pacto.
    const { data: profile } = await admin
      .from('users').select('id').eq('auth_provider_id', userData.user.id).maybeSingle()
    const { data: party } = await admin
      .from('pact_parties').select('role').eq('pact_id', ms.pact_id).eq('user_id', profile?.id ?? '').maybeSingle()
    if (party?.role !== 'promotor') return json({ error: 'Solo el promotor puede emitir la factura' }, 403)

    // Enlace con CostPact: sin presupuesto origen no hay factura que emitir
    // (el pacto no vino del ecosistema). No es un error: se omite.
    const { data: meta } = await admin
      .from('pact_metadata').select('costpact_presupuesto_id').eq('pact_id', ms.pact_id).maybeSingle()
    if (!meta?.costpact_presupuesto_id) {
      return json({ skipped: true, reason: 'Pacto sin presupuesto CostPact enlazado' }, 200)
    }

    // Llamada server-to-server a CostPact.
    const resp = await fetch(bridgeUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-bridge-key': bridgeKey },
      body: JSON.stringify({
        presupuesto_id: meta.costpact_presupuesto_id,
        external_ref: `ps:milestone:${milestoneId}`,
        amount_cents: Number(ms.amount_cents),
        concepto: ms.name ? `Certificación · ${ms.name}` : undefined,
      }),
    })
    const result = await resp.json().catch(() => ({}))
    if (!resp.ok) {
      console.error('[bridge-emit-invoice] CostPact respondió', resp.status, result)
      return json({ error: result?.error || 'CostPact rechazó la emisión', status: resp.status }, 502)
    }

    return json({ ok: true, invoice: result }, 200)
  } catch (error) {
    console.error('bridge-emit-invoice error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error emitiendo la factura' }, 500)
  }
})
