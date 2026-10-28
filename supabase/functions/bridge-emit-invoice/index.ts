// Edge Function: bridge-emit-invoice  (puente del ecosistema R3, sentido
// PactStream → FiscalCore/CostPact)
//
// Regla: factura CostPact y la factura nace de la CERTIFICACIÓN. Al aprobarse
// un hito enlazado a una certificación de CostPact (sf_link_costpact_cert),
// PactStream pide a CostPact la factura de ESA certificación: una por
// certificación (si ya se emitió desde CostPact, devuelve la misma) y guarda
// su número en el hito. Sin enlace no se factura nada desde aquí: la empresa
// que no usa CostPact adjunta su factura externa (sf_attach_cert_invoice).
// Después, si el dinero del hito ya se liberó (pago milestone_release
// succeeded), lo registra como el cobro de esa certificación en CostPact
// (puente F; de ahí lo lee FiscalCore). Los dos pasos son idempotentes.
//
// Pacto que NO viene de CostPact (las apps no obligan al pack): no hay factura
// que pedir (la adjunta el constructor), y el cobro liberado va directo a
// FiscalCore (pactstream-cobro), que identifica la empresa constructora por el
// NIF de su organización y solo lo acepta si la empresa conectó PactStream.
// Server-to-server: la clave vive como secreto de la función, nunca en el cliente.
//
// Body: { "milestone_id": "<uuid>" }
// Env: COSTPACT_BRIDGE_URL (base de las rutas /api/bridge de CostPact, p.ej.
//      https://constructpro.es/api/bridge) + COSTPACT_BRIDGE_KEY;
//      FISCALCORE_BRIDGE_URL (función pactstream-cobro) + FISCALCORE_BRIDGE_KEY.
//      Sin los de un camino, ese camino responde 503 (inerte).
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
      .from('milestones').select('id, pact_id, name, costpact_certificacion_id, invoice_number')
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

    // Dinero liberado del hito (libro único de pagos), para el cobro.
    const { data: pago } = await admin
      .from('payments').select('amount_cents, succeeded_at')
      .eq('milestone_id', milestoneId).eq('payment_type', 'milestone_release')
      .eq('state', 'succeeded').maybeSingle()

    if (!presupuestoId) {
      // Pacto sin CostPact: el cobro va directo a FiscalCore.
      const fcUrl = Deno.env.get('FISCALCORE_BRIDGE_URL')
      const fcKey = Deno.env.get('FISCALCORE_BRIDGE_KEY')
      if (!fcUrl || !fcKey) return json({ error: 'Puente con FiscalCore no configurado' }, 503)
      if (!pago) return json({ skipped: true, reason: 'El hito aún no se ha liberado' }, 200)
      const { data: pact } = await admin
        .from('pacts').select('title, iva_rate_pct, iva_included').eq('id', ms.pact_id).maybeSingle()
      const { data: parte } = await admin
        .from('pact_parties').select('organizations(cif)')
        .eq('pact_id', ms.pact_id).eq('role', 'constructor').maybeSingle()
      const nif = (parte as { organizations?: { cif?: string } | null } | null)?.organizations?.cif
      if (!nif) return json({ skipped: true, reason: 'El constructor no tiene organización con NIF' }, 200)
      const resp = await fetch(fcUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-bridge-key': fcKey },
        body: JSON.stringify({
          nif,
          ref: `ps:release:${milestoneId}`,
          fecha: pago.succeeded_at,
          importe_cents: Number(pago.amount_cents),
          iva_rate_pct: Number(pact?.iva_rate_pct ?? 0),
          iva_incluido: !!pact?.iva_included,
          concepto: ms.name ?? null,
          obra: pact?.title ?? null,
          factura_numero: ms.invoice_number ?? null,
        }),
      }).catch(() => null)
      const result = resp ? await resp.json().catch(() => ({})) : {}
      if (!resp || !resp.ok) {
        console.error('[bridge-emit-invoice] FiscalCore respondió', resp?.status, result)
        return json({ error: result?.error || 'FiscalCore rechazó el cobro' }, 502)
      }
      return json({ ok: true, cobro: result }, 200)
    }

    const bridgeUrl = Deno.env.get('COSTPACT_BRIDGE_URL')
    const bridgeKey = Deno.env.get('COSTPACT_BRIDGE_KEY')
    if (!bridgeUrl || !bridgeKey) return json({ error: 'Puente con CostPact no configurado' }, 503)

    // Sin certificación de CostPact enlazada no hay factura ni cobro que
    // enviar: una factura «por hito» duplicaría la de la certificación.
    if (!ms.costpact_certificacion_id) {
      return json({ skipped: true, reason: 'Hito sin certificación de CostPact enlazada' }, 200)
    }
    const base = bridgeUrl.replace(/\/$/, '')
    const post = (path: string, payload: unknown) => fetch(`${base}/${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-bridge-key': bridgeKey },
      body: JSON.stringify(payload),
    })

    // 1. Factura de la certificación (una por certificación).
    let invoice: Record<string, unknown> = { skipped: true, invoice_number: ms.invoice_number }
    if (!ms.invoice_number) {
      const resp = await post('factura-certificacion', {
        presupuesto_id: presupuestoId,
        certificacion_id: ms.costpact_certificacion_id,
        external_ref: `ps:milestone:${milestoneId}`,
      })
      const result = await resp.json().catch(() => ({}))
      if (!resp.ok) {
        console.error('[bridge-emit-invoice] factura: CostPact respondió', resp.status, result)
        invoice = { error: result?.error || 'CostPact rechazó la emisión', status: resp.status }
      } else {
        // El número de la factura de CostPact queda en la certificación de PactStream.
        const numero = result?.num_serie_factura as string | undefined
        if (numero) {
          await admin.from('milestones').update({ invoice_number: numero }).eq('id', milestoneId)
          await admin.from('pact_events').insert({
            pact_id: ms.pact_id, event_type: 'invoice_attached', actor_type: 'system',
            payload: { cert_id: milestoneId, invoice_number: numero, source: 'costpact' },
          })
        }
        invoice = { ok: true, invoice_number: numero ?? null, reused: !!result?.reused }
      }
    }

    // 2. Cobro: el dinero liberado del hito (libro único de pagos).
    let cobro: Record<string, unknown> = { skipped: true, reason: 'El hito aún no se ha liberado' }
    if (pago) {
      const resp = await post('cobro-certificacion', {
        presupuesto_id: presupuestoId,
        certificacion_id: ms.costpact_certificacion_id,
        importe: Number(pago.amount_cents) / 100,
        fecha: pago.succeeded_at,
        ref: `ps:release:${milestoneId}`,
      })
      const result = await resp.json().catch(() => ({}))
      if (!resp.ok) console.error('[bridge-emit-invoice] cobro: CostPact respondió', resp.status, result)
      cobro = resp.ok ? { ok: true, ...result } : { error: result?.error || 'CostPact rechazó el cobro', status: resp.status }
    }

    const fallo = 'error' in invoice || 'error' in cobro
    return json({ ok: !fallo, invoice, cobro }, fallo ? 502 : 200)
  } catch (error) {
    console.error('bridge-emit-invoice error:', error instanceof Error ? error.message : error)
    return json({ error: 'Error emitiendo la factura' }, 500)
  }
})
