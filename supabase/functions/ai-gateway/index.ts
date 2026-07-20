// Edge Function: ai-gateway
//
// Único punto de entrada al servicio de IA de PactStream. Tres responsabilidades:
//   1. Validar JWT del usuario y su pertenencia al pacto.
//   2. Decidir entre modo "demo" (fixtures pre-grabadas) y modo "live"
//      (llamada real a Anthropic). El switch global está en app_settings.
//   3. Persistir telemetría en ai_runs y respetar el kill switch de coste.
//
// Flow:
//   Cliente Flutter → invoke('ai-gateway', { runType, pactId, milestoneId, payload })
//   ai-gateway → branch demo/live → respuesta JSON
//   ai-gateway → INSERT en ai_runs (success o fallo)
//
// Modo demo:
//   - Lee fixture por (run_type, milestone_id|intent_key) de la tabla ai_fixtures.
//   - Simula latencia con setTimeout (demo_simulated_latency_ms del payload).
//   - Cost = 0.
//   - Útil para pitch a inversores y demos sin generar coste de API.
//
// Modo live:
//   - POST a https://api.anthropic.com/v1/messages
//   - Modelo: claude-sonnet-4-6 (configurable via env)
//   - Prompt caching habilitado para reducir coste en asistente.
//   - Calcula cost_cents según precios oficiales del modelo.
//
// Variables de entorno requeridas:
//   - SUPABASE_URL                  (auto)
//   - SUPABASE_SERVICE_ROLE_KEY     (auto)
//   - ANTHROPIC_API_KEY             (necesario solo para modo live)
//   - ANTHROPIC_MODEL               (default: claude-sonnet-4-6)
//
// Variables opcionales:
//   - AI_GATEWAY_LOG_PAYLOADS       (default: false; nunca true en producción)
//
// Reglas de seguridad:
//   - Si el pacto tiene is_demo_only = true, FORZAR provider='demo' aunque
//     ai_provider global esté en 'live'. Esto preserva el pacto demo como
//     activo reproducible sin coste.
//   - Si SUM(cost_cents) hoy en ai_runs > ai_max_cost_eur_day → forzar demo
//     y enviar alerta.
//   - Redactor PII obligatorio antes de log (no antes de enviar al modelo,
//     porque el modelo necesita los nombres reales del pacto para responder
//     bien).

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY');
const ANTHROPIC_MODEL = Deno.env.get('ANTHROPIC_MODEL') ?? 'claude-sonnet-4-6';
const LOG_PAYLOADS = Deno.env.get('AI_GATEWAY_LOG_PAYLOADS') === 'true';

// Precios oficiales por millón de tokens (en céntimos de euro).
// Actualizar si Anthropic cambia el pricing.
const PRICING: Record<string, { input: number; output: number; cache_read: number }> = {
  'claude-sonnet-4-6': { input: 300, output: 1500, cache_read: 30 },
  'claude-haiku-4-5': { input: 100, output: 500, cache_read: 10 },
};

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type RunType = 'vision' | 'assistant';

interface GatewayRequest {
  runType: RunType;
  pactId: string;
  milestoneId?: string;
  intentKey?: string; // para asistente: matcheo de intent
  payload: Record<string, unknown>; // payload específico del runType
}

interface GatewayResponse {
  provider: 'demo' | 'live';
  model: string;
  prompt_version: string;
  content: string | null;
  content_blocks: unknown[] | null;
  tool_call?: { name: string; input: Record<string, unknown> };
  // Para Vision:
  vision_dictum?: VisionDictum;
  // Métricas
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  cost_cents: number;
  duration_ms: number;
}

interface VisionDictum {
  score: number;
  verdict: 'ok' | 'review_needed' | 'block';
  summary: string;
  findings: Array<{
    id: string;
    type: string;
    evidence_ref?: string;
    severity: 'green' | 'amber' | 'red';
    message: string;
  }>;
  checklist_match: Array<{
    task_id: string;
    title: string;
    evidence_ok: boolean;
    note?: string;
  }>;
  recommendation: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function sha256(input: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Redactor de PII para logs y telemetría. No se aplica al payload enviado al
 * modelo — solo a lo que se persiste en ai_runs.metadata o se loggea.
 */
function redactPII<T>(input: T): T {
  if (typeof input !== 'string') return input;
  let s = input as unknown as string;
  // DNI/NIE español
  s = s.replace(/\b[0-9]{8}[A-Z]\b/g, '[DNI]');
  s = s.replace(/\b[XYZ][0-9]{7}[A-Z]\b/g, '[NIE]');
  // IBAN (cualquier país)
  s = s.replace(/\b[A-Z]{2}[0-9]{2}[\sA-Z0-9]{11,30}\b/g, '[IBAN]');
  // Email
  s = s.replace(/\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b/g, '[EMAIL]');
  // Teléfono E.164 simple
  s = s.replace(/\+\d{8,15}/g, '[PHONE]');
  return s as unknown as T;
}

function computeCostCents(
  model: string,
  inputTokens: number,
  outputTokens: number,
  cacheReadTokens: number,
): number {
  const p = PRICING[model] ?? PRICING['claude-sonnet-4-6'];
  // Precios están en céntimos por millón de tokens
  return Math.round(
    (inputTokens * p.input + outputTokens * p.output + cacheReadTokens * p.cache_read) /
      1_000_000,
  );
}

async function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

// ---------------------------------------------------------------------------
// Provider resolver: demo vs live
// ---------------------------------------------------------------------------

async function resolveProvider(
  adminClient: ReturnType<typeof createClient>,
  authUid: string,
  pactId: string,
): Promise<'demo' | 'live'> {
  // 1. Pacto demo siempre fuerza demo
  const { data: pactRow } = await adminClient
    .from('pacts')
    .select('is_demo_only')
    .eq('id', pactId)
    .maybeSingle();

  if (pactRow?.is_demo_only) return 'demo';

  // 2. Lookup de settings
  const { data: settings } = await adminClient
    .from('app_settings')
    .select('key, value')
    .in('key', ['ai_provider', 'ai_live_for_user_uids', 'ai_max_cost_eur_day']);

  const map = new Map((settings ?? []).map((s) => [s.key, s.value as unknown]));
  const globalProvider = (map.get('ai_provider') as string) ?? 'demo';
  const liveForUids = (map.get('ai_live_for_user_uids') as string[]) ?? [];
  const maxCostEur = (map.get('ai_max_cost_eur_day') as number) ?? 5;

  // 3. Override granular: live forzado para ciertos uids
  if (globalProvider === 'demo' && liveForUids.includes(authUid)) {
    return 'live';
  }

  // 4. Kill switch de coste
  if (globalProvider === 'live') {
    const { data: costRow } = await adminClient.rpc('sf_ai_today_cost_cents');
    const costCents = (costRow as unknown as number) ?? 0;
    if (costCents > maxCostEur * 100) {
      console.warn(
        `[ai-gateway] kill switch activado: coste hoy ${costCents}c > ${maxCostEur * 100}c`,
      );
      return 'demo';
    }
  }

  return globalProvider as 'demo' | 'live';
}

// ---------------------------------------------------------------------------
// Demo path: servir desde ai_fixtures
// ---------------------------------------------------------------------------

async function serveFromFixture(
  adminClient: ReturnType<typeof createClient>,
  req: GatewayRequest,
): Promise<GatewayResponse> {
  let fixtureKey: string;

  if (req.runType === 'vision') {
    // Convención: fixture key = 'vision_' + milestoneId + '_' + variant
    // Resolver variante (review/ok/block) desde app_settings (solo aplicable
    // al milestone del pacto demo).
    const { data: variantRow } = await adminClient
      .from('app_settings')
      .select('value')
      .eq('key', 'ai_demo_variant_m3')
      .maybeSingle();
    const variant = (variantRow?.value as string) ?? 'review';

    // Intentar key específica por milestone primero, luego fallback genérico
    fixtureKey = `vision_${req.milestoneId}_${variant}`;
    let { data: fix } = await adminClient
      .from('ai_fixtures')
      .select('payload')
      .eq('fixture_key', fixtureKey)
      .eq('is_active', true)
      .maybeSingle();

    if (!fix) {
      fixtureKey = `vision_default_${variant}`;
      const r = await adminClient
        .from('ai_fixtures')
        .select('payload')
        .eq('fixture_key', fixtureKey)
        .eq('is_active', true)
        .maybeSingle();
      fix = r.data;
    }

    if (!fix) {
      throw new Error(`Fixture no encontrada para vision (${fixtureKey})`);
    }

    const payload = fix.payload as unknown as
      VisionDictum & { demo_simulated_latency_ms?: number };

    // Simular latencia
    const { data: latRow } = await adminClient
      .from('app_settings')
      .select('value')
      .eq('key', 'ai_demo_latency_mult')
      .maybeSingle();
    const latencyMult = (latRow?.value as number) ?? 1.0;
    const latency = Math.round(
      (payload.demo_simulated_latency_ms ?? 9000) * latencyMult,
    );
    await sleep(Math.min(latency, 25_000)); // cap por timeout edge function

    return {
      provider: 'demo',
      model: 'claude-sonnet-4-6 [demo-fixture]',
      prompt_version: 'vision_v1',
      content: payload.summary,
      content_blocks: null,
      vision_dictum: {
        score: payload.score,
        verdict: payload.verdict,
        summary: payload.summary,
        findings: payload.findings ?? [],
        checklist_match: payload.checklist_match ?? [],
        recommendation: payload.recommendation,
      },
      input_tokens: 0,
      output_tokens: 0,
      cache_read_tokens: 0,
      cost_cents: 0,
      duration_ms: latency,
    };
  }

  // ----- Asistente -----
  // Matcheo de intent por keywords sobre el texto del usuario.
  const userText = ((req.payload as { user_message?: string }).user_message ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, ''); // sin acentos

  const { data: intents } = await adminClient
    .from('ai_fixtures')
    .select('fixture_key, payload')
    .eq('fixture_type', 'assistant_intent')
    .eq('is_active', true);

  let matched: { fixture_key: string; payload: Record<string, unknown> } | null =
    null;
  for (const row of intents ?? []) {
    const p = row.payload as Record<string, unknown>;
    const keywords = (p.trigger_keywords as string[]) ?? [];
    if (
      keywords.some((kw) =>
        userText.includes(
          kw.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''),
        ),
      )
    ) {
      matched = { fixture_key: row.fixture_key, payload: p };
      break;
    }
  }

  // Si no hay match, servir fallback
  if (!matched) {
    const { data: fb } = await adminClient
      .from('ai_fixtures')
      .select('payload')
      .eq('fixture_type', 'assistant_fallback')
      .eq('is_active', true)
      .maybeSingle();
    matched = {
      fixture_key: 'assistant_fallback',
      payload: (fb?.payload as Record<string, unknown>) ?? {
        response: {
          text: 'Lo veo con soporte humano. Mientras tanto, ¿en qué del pacto te ayudo?',
        },
      },
    };

    // Loggear el turno no matcheado para enriquecer el script luego
    await adminClient.from('ai_runs').insert({
      run_type: 'assistant',
      pact_id: req.pactId,
      provider: 'demo',
      success: false,
      error_code: 'no_intent_match',
      metadata: { user_text_redacted: redactPII(userText) },
    });
  }

  // Simular delay y devolver
  await sleep(1200); // first-token delay
  const resp = matched.payload.response as Record<string, unknown>;
  const text = (resp?.text as string) ?? '';
  const toolCall = matched.payload.tool_call_proposed as
    | { name: string; input: Record<string, unknown> }
    | undefined;

  return {
    provider: 'demo',
    model: 'claude-sonnet-4-6 [demo-fixture]',
    prompt_version: 'assistant_v1',
    content: text,
    content_blocks: null,
    tool_call: toolCall,
    input_tokens: 0,
    output_tokens: 0,
    cache_read_tokens: 0,
    cost_cents: 0,
    duration_ms: 1200,
  };
}

// ---------------------------------------------------------------------------
// Live path: llamada real a Anthropic
// ---------------------------------------------------------------------------

async function callAnthropic(
  adminClient: ReturnType<typeof createClient>,
  req: GatewayRequest,
): Promise<GatewayResponse> {
  if (!ANTHROPIC_API_KEY) {
    throw new Error('ANTHROPIC_API_KEY no configurada — no se puede operar en modo live');
  }

  // 1. Recuperar prompt activo
  const promptKey = req.runType === 'vision' ? 'vision' : 'assistant';
  const { data: promptRow } = await adminClient
    .from('ai_prompts')
    .select('version, system_prompt, schema')
    .eq('prompt_key', promptKey)
    .eq('is_active', true)
    .maybeSingle();

  if (!promptRow) {
    throw new Error(`Prompt activo no encontrado para ${promptKey}`);
  }

  // 2. Construir messages (vision o assistant)
  // Para brevedad del MVP, esta parte es esqueleto; el detalle de cada runType
  // lo monta ai-verify-milestone y ai-assistant-turn antes de invocar gateway.
  const messages = (req.payload as { messages?: unknown[] }).messages ?? [];

  const t0 = performance.now();
  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: 2048,
      system: [
        {
          type: 'text',
          text: promptRow.system_prompt,
          cache_control: { type: 'ephemeral' }, // cache del system prompt
        },
      ],
      messages,
    }),
  });

  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Anthropic API error ${resp.status}: ${err}`);
  }

  const body = await resp.json();
  const duration = performance.now() - t0;

  const inputTokens = body.usage?.input_tokens ?? 0;
  const outputTokens = body.usage?.output_tokens ?? 0;
  const cacheReadTokens = body.usage?.cache_read_input_tokens ?? 0;
  const costCents = computeCostCents(
    ANTHROPIC_MODEL,
    inputTokens,
    outputTokens,
    cacheReadTokens,
  );

  // Extraer texto principal y tool_use si existe
  const contentBlocks = body.content ?? [];
  const textBlock = contentBlocks.find((b: { type: string }) => b.type === 'text');
  const toolBlock = contentBlocks.find((b: { type: string }) => b.type === 'tool_use');
  const text = (textBlock as { text?: string } | undefined)?.text ?? null;

  // Si es vision, parsear el JSON del dictamen del texto
  let visionDictum: VisionDictum | undefined;
  if (req.runType === 'vision' && text) {
    try {
      visionDictum = JSON.parse(text);
    } catch (_e) {
      console.warn('[ai-gateway] vision response no parseable como JSON, fallback');
    }
  }

  return {
    provider: 'live',
    model: ANTHROPIC_MODEL,
    prompt_version: promptRow.version,
    content: text,
    content_blocks: contentBlocks,
    tool_call: toolBlock
      ? {
          name: (toolBlock as { name?: string }).name ?? '',
          input: (toolBlock as { input?: Record<string, unknown> }).input ?? {},
        }
      : undefined,
    vision_dictum: visionDictum,
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    cache_read_tokens: cacheReadTokens,
    cost_cents: costCents,
    duration_ms: Math.round(duration),
  };
}

// ---------------------------------------------------------------------------
// Handler principal
// ---------------------------------------------------------------------------

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Unauthorized' }, 401);
  }

  // Cliente con JWT del usuario (para RLS y RPCs)
  const userClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  // Cliente con service_role (para inserts en tablas restringidas)
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  let body: GatewayRequest;
  try {
    body = (await req.json()) as GatewayRequest;
  } catch {
    return json({ error: 'JSON inválido' }, 400);
  }

  if (!body.runType || !body.pactId) {
    return json({ error: 'runType y pactId son requeridos' }, 400);
  }

  // 1. Validar pertenencia del usuario al pacto
  const { data: inPact, error: rpcErr } = await userClient.rpc('fn_user_in_pact', {
    p_pact_id: body.pactId,
  });

  if (rpcErr) {
    console.error('[ai-gateway] fn_user_in_pact error', rpcErr);
    return json({ error: 'Validación de pertenencia falló' }, 500);
  }
  if (!inPact) {
    return json({ error: 'Forbidden: usuario no pertenece al pacto' }, 403);
  }

  // 2. Obtener auth UID del JWT (sin parsear el token; usamos getUser del cliente)
  const { data: userData } = await userClient.auth.getUser();
  const authUid = userData?.user?.id ?? '';
  if (!authUid) {
    return json({ error: 'Auth UID no resoluble' }, 401);
  }

  // 3. Resolver provider
  const provider = await resolveProvider(adminClient, authUid, body.pactId);

  // 4. Ejecutar
  const t0 = performance.now();
  let response: GatewayResponse;
  let success = true;
  let errorCode: string | null = null;
  let errorMessage: string | null = null;

  try {
    if (provider === 'demo') {
      response = await serveFromFixture(adminClient, body);
    } else {
      response = await callAnthropic(adminClient, body);
    }
  } catch (e) {
    success = false;
    const err = e as Error;
    errorCode = 'gateway_error';
    errorMessage = err.message;
    console.error('[ai-gateway] error', err);

    // Fallback: si live falla, intentar servir demo
    if (provider === 'live') {
      try {
        response = await serveFromFixture(adminClient, body);
        success = true;
        errorCode = 'live_failed_demo_fallback';
        errorMessage = err.message;
      } catch (e2) {
        await adminClient.from('ai_runs').insert({
          run_type: body.runType,
          pact_id: body.pactId,
          milestone_id: body.milestoneId ?? null,
          user_uid_hash: await sha256(authUid),
          provider,
          success: false,
          error_code: errorCode,
          error_message: redactPII(errorMessage),
        });
        return json(
          { error: 'IA no disponible. Inténtalo de nuevo en unos segundos.' },
          503,
        );
      }
    } else {
      await adminClient.from('ai_runs').insert({
        run_type: body.runType,
        pact_id: body.pactId,
        milestone_id: body.milestoneId ?? null,
        user_uid_hash: await sha256(authUid),
        provider,
        success: false,
        error_code: errorCode,
        error_message: redactPII(errorMessage),
      });
      return json({ error: 'IA no disponible. Inténtalo de nuevo.' }, 503);
    }
  }

  const totalDuration = performance.now() - t0;

  // 5. Persistir ai_runs
  await adminClient.from('ai_runs').insert({
    run_type: body.runType,
    pact_id: body.pactId,
    milestone_id: body.milestoneId ?? null,
    user_uid_hash: await sha256(authUid),
    provider: response.provider,
    model: response.model,
    prompt_version: response.prompt_version,
    input_tokens: response.input_tokens || null,
    output_tokens: response.output_tokens || null,
    cache_read_tokens: response.cache_read_tokens || null,
    cost_cents: response.cost_cents,
    duration_ms: Math.round(totalDuration),
    success,
    error_code: errorCode,
    error_message: errorMessage ? redactPII(errorMessage) : null,
    metadata: {
      run_type: body.runType,
      has_tool_call: !!response.tool_call,
      verdict: response.vision_dictum?.verdict ?? null,
      // score_numeric alimenta sf_recalc_pact_health (métrica IA del trust
      // score). Sin esto, v_avg_ia_score era siempre NULL → ia_evidence_score
      // se quedaba en el neutral 75, nunca reflejaba la verificación real.
      score_numeric: response.vision_dictum?.score ?? null,
      // sf_check_quality_holdback busca por metadata->>'milestone_id' (no por
      // la columna) para hallar el último score del hito. Sin esto, la ruta
      // primaria del holdback no matcheaba y dependía solo del fallback.
      milestone_id: body.milestoneId ?? null,
    },
  });

  // 5b. Vision: persistir el dictamen en milestone_ai_verifications y refrescar
  //     el snapshot de salud. Las dos RPCs (sf_record_ai_verification y
  //     sf_recalc_pact_health) ya existían; el gateway simplemente no las
  //     invocaba, así que el dictamen no se guardaba y el score IA quedaba
  //     estático. Best-effort: un fallo de persistencia no rompe la respuesta.
  if (success && body.runType === 'vision' && body.milestoneId && response.vision_dictum) {
    const vd = response.vision_dictum;
    const p = body.payload as { evidences_count?: number; documents_count?: number };
    try {
      await adminClient.rpc('sf_record_ai_verification', {
        p_milestone_id: body.milestoneId,
        p_provider: response.provider,
        p_model: response.model,
        p_prompt_version: response.prompt_version,
        p_input_hash: await sha256(
          `${body.pactId}:${body.milestoneId}:${response.provider}:${response.prompt_version}:${vd.score}`,
        ),
        p_evidences_count: Number(p?.evidences_count ?? 0),
        p_documents_count: Number(p?.documents_count ?? 0),
        p_score: vd.score,
        p_verdict: vd.verdict,
        p_summary: vd.summary,
        p_findings: vd.findings ?? [],
        p_checklist_match: vd.checklist_match ?? [],
        p_recommendation: vd.recommendation ?? null,
        p_input_tokens: response.input_tokens || null,
        p_output_tokens: response.output_tokens || null,
        p_cache_read_tokens: response.cache_read_tokens || null,
        p_cost_cents: response.cost_cents,
        p_duration_ms: response.duration_ms,
      });
      // El recalc lee ai_runs.metadata.score_numeric (ya insertado arriba).
      await adminClient.rpc('sf_recalc_pact_health', { p_pact_id: body.pactId });
    } catch (persistErr) {
      console.error('[ai-gateway] persistencia/recalc de vision falló', persistErr);
    }
  }

  if (LOG_PAYLOADS) {
    console.log('[ai-gateway] response', JSON.stringify(response));
  }

  return json(response);
});
