// Edge Function: bridge-emit-invoice  (puente del ecosistema R3, sentido
// PactStream → FiscalCore/CostPact)
//
// Regla: factura CostPact y la factura nace de la CERTIFICACIÓN. Al aprobarse
// un hito enlazado a una certificación de CostPact (sf_link_costpact_cert),
// PactStream pide a CostPact la factura de ESA certificación: una por
// certificación (si ya se emitió desde CostPact, devuelve la misma) y guarda
// su número en el hito. Sin enlace no se factura nada desde aquí: la empresa
// que no usa CostPact adjunta su factura externa (sf_attach_cert_invoice).
// Server-to-server: la clave vive como secreto de la función, nunca en el cliente.
//
// Body: { "milestone_id": "<uuid>" }
// Env: COSTPACT_BRIDGE_URL (base de las rutas /api/bridge de CostPact, p.ej.
//      https://constructpro.es/api/bridge) + COSTPACT_BRIDGE_KEY.
//      Sin ellos → 503 (inerte).
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
    const bridgeUrl = Deno.env.get('COSTPACT_BRIDGE_URL')
    const bridgeKey = Deno.env.get('COSTPACT_BRIDGE_KEY')
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
      .from('milestones').select('id, pact_id, costpact_certificacion_id, invoice_number')
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
    // pact_metadata es clave-valor: (pact_id, key, value).
    const { data: meta, error: metaErr } = await admin
      .from('pact_metadata').select('value')
      .eq('pact_id', ms.pact_id).eq('key', 'costpact_presupuesto_id').maybeSingle()
    if (metaErr) {
      console.error('[bridge-emit-invoice] lectura de pact_metadata', metaErr.message)
      return json({ error: 'No se pudo leer el enlace con CostPact' }, 500)
    }
    const presupuestoId = meta?.value?.trim()
    if (!presupuestoId) {
      return json({ skipped: true, reason: 'Pacto sin presupuesto CostPact enlazado' }, 200)
    }

    if (ms.invoice_number) {
      return json({ skipped: true, reason: 'La certificación ya tiene factura', invoice_number: ms.invoice_number }, 200)
    }
    // Sin certificación de CostPact enlazada no hay factura que pedir: una
    // factura «por hito» duplicaría la de la certificación.
    if (!ms.costpact_certificacion_id) {
      return json({ skipped: true, reason: 'Hito sin certificación de CostPact enlazada' }, 200)
    }

    // Llamada server-to-server a CostPact.
    const resp = await fetch(`${bridgeUrl.replace(/\/$/, '')}/factura-certificacion`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-bridge-key': bridgeKey },
      body: JSON.stringify({
        presupuesto_id: presupuestoId,
        certificacion_id: ms.costpact_certificacion_id,
        external_ref: `ps:milestone:${milestoneId}`,
      }),
    })
    const result = await resp.json().catch(() => ({}))
    if (!resp.ok) {
      console.error('[bridge-emit-invoice] CostPact respondió', resp.status, result)
      return json({ error: result?.error || 'CostPact rechazó la emisión', status: resp.status }, 502)
    }

    // El número de la factura de CostPact queda en la certificación de PactStream.
    const numero = result?.num_serie_factura as string | undefined
    if (numero) {
      await admin.from('milestones').update({ invoice_number: numero }).eq('id', milestoneId)
      await admin.from('pact_events').insert({
        pact_id: ms.pact_id, event_type: 'invoice_attached', actor_type: 'system',
        payload: { cert_id: milestoneId, invoice_number: numero, source: 'costpact' },
      })
    }

    return json({ ok: true, invoice_number: numero ?? null, reused: !!result?.reused }, 200)
  } catch (error) {
    console.error('bridge-emit-invoice error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error emitiendo la factura' }, 500)
  }
})
