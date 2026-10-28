// Edge Function: budget-proposal  (puente del ecosistema D, sentido
// CostPact → PactStream)
//
// CostPact envía un presupuesto como PROPUESTA al email de su cliente. No crea
// el pacto: en v2.1 lo crea el promotor, que la acepta desde su panel
// (sf_accept_budget_proposal). Server-to-server: la api-key (scope
// import:budget) viaja en x-api-key y se valida en sf_propose_budget.
//
// Body: payload de sf_propose_budget (costpact_presupuesto_id, promotor_email,
//       constructor_email, constructor_name, title, total_amount_cents,
//       obra_*, iva_rate_pct, advance_pct, milestones[]).
// Idempotente: reenviar el mismo presupuesto actualiza la misma propuesta.
// Se despliega con --no-verify-jwt (el llamante no tiene sesión de PactStream).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4'

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

// sqlstate de sf_propose_budget → código HTTP
const STATUS_BY_CODE: Record<string, number> = {
  '28000': 401, // api-key inválida o revocada
  '42501': 403, // sin scope import:budget
  '22023': 422, // payload incompleto o inválido
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405)

  const apiKey = req.headers.get('x-api-key')
  if (!apiKey) return json({ error: 'Falta x-api-key' }, 401)

  const payload = await req.json().catch(() => null)
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return json({ error: 'Body JSON inválido' }, 400)
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
  const { data, error } = await admin.rpc('sf_propose_budget', {
    p_api_key: apiKey,
    p_payload: payload,
  })
  if (error) {
    const status = STATUS_BY_CODE[error.code ?? ''] ?? 500
    if (status === 500) console.error('[budget-proposal]', error.code, error.message)
    return json({ error: status === 500 ? 'Error interno' : error.message }, status)
  }
  return json(data, 200)
})
