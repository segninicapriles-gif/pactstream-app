-- =====================================================================
-- Sprint 7 chunk 1 · Migration 0030
-- IA Features · Schema base (Vision verification + Asistente conversacional)
-- =====================================================================
-- Introduce la capa de IA sobre el modelo v2.1 existente:
--
--   - milestone_ai_verifications: dictamen de Claude Vision por certificación.
--     Append-only enforced (excepto campos de revisión humana).
--   - ai_assistant_messages: turnos del asistente conversacional scoped a pacto.
--     Solo el usuario del hilo y el admin del pacto pueden leer.
--   - ai_runs: observabilidad cross-pact sin PII (telemetría/coste/latencia).
--   - ai_prompts: store versionado de prompts (vision_v1, assistant_v1).
--   - ai_fixtures: respuestas pre-grabadas para Demo Mode.
--   - app_settings: tabla KV con el switch ai_provider y configuración global.
--
-- Cambios en tablas existentes:
--   - pact_health_scores: nueva columna ia_evidence_score.
--   - pacts: flag is_demo_only para aislar el pacto demo de live mode.
--   - Enums: pact_event_type +3, notification_type +2.
--
-- Compatibilidad: todo aditivo. Los pacts y milestones existentes siguen
-- funcionando sin tocar nada. Hasta que el feature flag ai_provider se cambie
-- a 'live', el sistema sirve respuestas demo desde ai_fixtures.
-- =====================================================================


-- =====================================================================
-- 1 · pact_health_scores · nueva métrica IA
-- =====================================================================

ALTER TABLE public.pact_health_scores
  ADD COLUMN IF NOT EXISTS ia_evidence_score numeric(5,2)
    CHECK (ia_evidence_score IS NULL OR (ia_evidence_score >= 0 AND ia_evidence_score <= 100));

COMMENT ON COLUMN public.pact_health_scores.ia_evidence_score IS
  'v2.1+IA · Media ponderada de los scores de milestone_ai_verifications '
  'del pacto. NULL si aún no hay verificaciones de IA.';


-- =====================================================================
-- 2 · pacts · flag is_demo_only
-- =====================================================================
-- Los pactos marcados como demo nunca llaman a la API real de Anthropic
-- aunque ai_provider esté en 'live'. La regla la aplica ai-gateway.

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS is_demo_only boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.pacts.is_demo_only IS
  'IA · Si TRUE, el pacto está aislado para demos: nunca llama a la API real '
  'de IA, siempre sirve fixtures. Preserva el demo como activo reproducible '
  'sin coste. Solo admin puede flipar este campo vía RPC.';


-- =====================================================================
-- 3 · pact_events.event_type y notifications.notification_type son text
-- =====================================================================
-- Confirmado contra el schema real: ambas columnas son `text NOT NULL`
-- (no enums), así que no hace falta ALTER TYPE. Los nuevos valores que
-- usaremos son strings libres validados a nivel de aplicación:
--
--   pact_events.event_type:
--     'ai_verification_completed'
--     'ai_assistant_message'
--     'ai_tool_executed'
--
--   notifications.notification_type:
--     'ai_verification_red'
--     'ai_assistant_action'


-- =====================================================================
-- 4 · app_settings · tabla KV para configuración global
-- =====================================================================
-- Una sola fila por key. Permite cambiar comportamiento del producto sin
-- redeploy. Lectura por authenticated (las edge functions lo usan),
-- escritura solo por service_role.

CREATE TABLE IF NOT EXISTS public.app_settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  description text,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by_user_id uuid REFERENCES public.users(id)
);

COMMENT ON TABLE public.app_settings IS
  'KV global del producto. Switch de feature flags, configuración runtime de '
  'edge functions, etc. Lectura amplia, escritura controlada.';

INSERT INTO public.app_settings (key, value, description) VALUES
  ('ai_provider',          '"demo"'::jsonb,
    'demo | live · Modo global del gateway IA. demo sirve fixtures, live llama a Anthropic.'),
  ('ai_demo_variant_m3',   '"review"'::jsonb,
    'review | ok | block · Cuál variante del dictamen del Hito 3 del pacto demo servir.'),
  ('ai_live_for_user_uids', '[]'::jsonb,
    'Array de auth_provider_id que FUERZAN live mode aunque ai_provider sea demo. Útil para piloto granular.'),
  ('ai_max_cost_eur_day',  '5'::jsonb,
    'Kill switch: si SUM(cost_cents) hoy > este valor (en euros), gateway vuelve a demo automáticamente.'),
  ('ai_streaming_enabled', 'true'::jsonb,
    'Habilita streaming SSE token a token en el asistente.'),
  ('ai_demo_latency_mult', '1.0'::jsonb,
    'Multiplicador de la latencia simulada en demo mode. 0.5 = más rápido, 2.0 = más lento.')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_select_all ON public.app_settings;
CREATE POLICY app_settings_select_all ON public.app_settings
  FOR SELECT TO authenticated USING (true);

GRANT SELECT ON public.app_settings TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.app_settings TO service_role;


-- =====================================================================
-- 6 · ai_prompts · store versionado de prompts
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.ai_prompts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prompt_key    text NOT NULL,                -- 'vision' | 'assistant'
  version       text NOT NULL,                -- 'v1' | 'v1.1' | ...
  system_prompt text NOT NULL,
  schema        jsonb,                         -- JSON Schema del output esperado
  is_active     boolean NOT NULL DEFAULT false,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by_user_id uuid REFERENCES public.users(id),

  CONSTRAINT ai_prompts_key_version_unique UNIQUE (prompt_key, version)
);

CREATE INDEX IF NOT EXISTS idx_ai_prompts_active
  ON public.ai_prompts(prompt_key) WHERE is_active = true;

COMMENT ON TABLE public.ai_prompts IS
  'IA · Store de prompts versionados. Cambiar de versión es UPDATE is_active = '
  'false / true sin redeploy. Auditoría completa de qué prompt generó qué dictum.';

ALTER TABLE public.ai_prompts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_prompts_select_active ON public.ai_prompts;
CREATE POLICY ai_prompts_select_active ON public.ai_prompts
  FOR SELECT TO authenticated USING (is_active = true);

GRANT SELECT ON public.ai_prompts TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.ai_prompts TO service_role;


-- =====================================================================
-- 7 · ai_fixtures · respuestas pre-grabadas para Demo Mode
-- =====================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_fixture_type') THEN
    CREATE TYPE public.ai_fixture_type AS ENUM (
      'vision',                -- dictamen Vision pre-grabado, keyed por milestone_id o slot demo
      'assistant_intent',      -- intent del asistente con keywords + respuesta
      'assistant_fallback'     -- respuesta canónica si no hay match
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.ai_fixtures (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fixture_key  text NOT NULL UNIQUE,         -- ej. 'vision_m3_review', 'intent_estado_actual'
  fixture_type ai_fixture_type NOT NULL,
  payload      jsonb NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_fixtures_type_active
  ON public.ai_fixtures(fixture_type) WHERE is_active = true;

COMMENT ON TABLE public.ai_fixtures IS
  'IA · Fixtures editables in-app que alimentan Demo Mode. Cada fila es una '
  'respuesta pre-grabada (dictamen Vision o intent del asistente). Editar en '
  'caliente desde el panel admin sin tocar código.';

ALTER TABLE public.ai_fixtures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_fixtures_select_active ON public.ai_fixtures;
CREATE POLICY ai_fixtures_select_active ON public.ai_fixtures
  FOR SELECT TO authenticated USING (is_active = true);

GRANT SELECT ON public.ai_fixtures TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.ai_fixtures TO service_role;


-- =====================================================================
-- 8 · ai_runs · observabilidad cross-pact (sin PII)
-- =====================================================================
-- Cada invocación al gateway escribe una fila aquí. Permite construir un
-- dashboard de uso, latencia, coste y errores sin exponer contenido sensible.

CREATE TABLE IF NOT EXISTS public.ai_runs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_type        text NOT NULL CHECK (run_type IN ('vision','assistant','tool_execute')),
  pact_id         uuid REFERENCES public.pacts(id) ON DELETE SET NULL,
  milestone_id    uuid REFERENCES public.milestones(id) ON DELETE SET NULL,
  user_uid_hash   text,                                  -- sha256(user.id) para anonimizar
  provider        text NOT NULL CHECK (provider IN ('demo','live')),
  model           text,
  prompt_version  text,
  input_tokens    int CHECK (input_tokens IS NULL OR input_tokens >= 0),
  output_tokens   int CHECK (output_tokens IS NULL OR output_tokens >= 0),
  cache_read_tokens int CHECK (cache_read_tokens IS NULL OR cache_read_tokens >= 0),
  cost_cents      bigint NOT NULL DEFAULT 0 CHECK (cost_cents >= 0),
  duration_ms     int CHECK (duration_ms IS NULL OR duration_ms >= 0),
  success         boolean NOT NULL,
  error_code      text,
  error_message   text,
  metadata        jsonb,                                  -- extras (tool_name, verdict, etc.)
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_runs_created ON public.ai_runs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_runs_pact ON public.ai_runs(pact_id, created_at DESC);
-- date_trunc(timestamptz) es STABLE (no IMMUTABLE) y rompe en índice.
-- Un índice compuesto (provider, created_at) sirve igual de bien para queries
-- tipo "SUM(cost_cents) WHERE provider='live' AND created_at >= today".
CREATE INDEX IF NOT EXISTS idx_ai_runs_provider_day
  ON public.ai_runs(provider, created_at DESC);

COMMENT ON TABLE public.ai_runs IS
  'IA · Telemetría cross-pact de cada invocación al gateway IA. Sin PII. '
  'Alimenta dashboard admin de coste, latencia, errores y kill switch.';

ALTER TABLE public.ai_runs ENABLE ROW LEVEL SECURITY;

-- Solo service_role puede leer (es data interna). Si en el futuro queremos
-- exponer parte al user, abriremos vista con agregados.
GRANT SELECT ON public.ai_runs TO service_role;
GRANT INSERT ON public.ai_runs TO service_role;


-- =====================================================================
-- 9 · milestone_ai_verifications · dictamen Vision por certificación
-- =====================================================================
-- Append-only enforced excepto campos de revisión humana (el técnico puede
-- justificar findings tras leer el dictamen).

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_verdict') THEN
    CREATE TYPE public.ai_verdict AS ENUM ('ok', 'review_needed', 'block');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.milestone_ai_verifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id    uuid NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
  pact_id         uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,

  -- versionado del modelo y del prompt
  provider        text NOT NULL CHECK (provider IN ('demo','live')),
  model           text NOT NULL,
  prompt_version  text NOT NULL,

  -- inputs hasheados (snapshot inmutable para auditoría)
  input_hash_sha256 text NOT NULL,
  evidences_count smallint NOT NULL CHECK (evidences_count >= 0),
  documents_count smallint NOT NULL CHECK (documents_count >= 0),

  -- output del modelo
  score           smallint NOT NULL CHECK (score BETWEEN 0 AND 100),
  verdict         public.ai_verdict NOT NULL,
  summary         text NOT NULL,
  findings        jsonb NOT NULL DEFAULT '[]'::jsonb,
  checklist_match jsonb NOT NULL DEFAULT '[]'::jsonb,
  recommendation  text,

  -- observabilidad
  input_tokens    int,
  output_tokens   int,
  cache_read_tokens int,
  cost_cents      bigint NOT NULL DEFAULT 0,
  duration_ms     int,

  -- revisión humana (mutables, ver trigger más abajo)
  reviewed_by_user_id uuid REFERENCES public.users(id),
  reviewed_at     timestamptz,
  justifications  jsonb NOT NULL DEFAULT '[]'::jsonb,

  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mai_verifications_milestone
  ON public.milestone_ai_verifications(milestone_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mai_verifications_pact
  ON public.milestone_ai_verifications(pact_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mai_verifications_verdict
  ON public.milestone_ai_verifications(verdict) WHERE verdict != 'ok';

COMMENT ON TABLE public.milestone_ai_verifications IS
  'IA · Dictamen de Claude Vision por certificación. Append-only en campos '
  'del modelo (score/verdict/findings); reviewed_*/justifications son mutables '
  'para que el técnico documente sus decisiones sobre el dictamen.';

COMMENT ON COLUMN public.milestone_ai_verifications.input_hash_sha256 IS
  'SHA-256 del payload exacto enviado al modelo. Permite verificar que el '
  'dictamen no se ha modificado y reproducir la llamada si fuera necesario.';

COMMENT ON COLUMN public.milestone_ai_verifications.justifications IS
  'Array de { finding_id, note, user_uid } con las justificaciones que el '
  'técnico añadió antes de firmar pese al hallazgo. Solo modificable vía RPC.';


-- =====================================================================
-- 10 · Trigger append-only en milestone_ai_verifications
-- =====================================================================
-- Bloquea UPDATE/DELETE excepto en reviewed_by_user_id, reviewed_at y
-- justifications (campos donde el técnico documenta su revisión).

CREATE OR REPLACE FUNCTION public.fn_block_ai_verification_mutations()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'milestone_ai_verifications es append-only (DELETE bloqueado)';
  END IF;

  -- UPDATE solo permitido en campos de revisión humana
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.milestone_id IS DISTINCT FROM OLD.milestone_id
     OR NEW.pact_id IS DISTINCT FROM OLD.pact_id
     OR NEW.provider IS DISTINCT FROM OLD.provider
     OR NEW.model IS DISTINCT FROM OLD.model
     OR NEW.prompt_version IS DISTINCT FROM OLD.prompt_version
     OR NEW.input_hash_sha256 IS DISTINCT FROM OLD.input_hash_sha256
     OR NEW.evidences_count IS DISTINCT FROM OLD.evidences_count
     OR NEW.documents_count IS DISTINCT FROM OLD.documents_count
     OR NEW.score IS DISTINCT FROM OLD.score
     OR NEW.verdict IS DISTINCT FROM OLD.verdict
     OR NEW.summary IS DISTINCT FROM OLD.summary
     OR NEW.findings IS DISTINCT FROM OLD.findings
     OR NEW.checklist_match IS DISTINCT FROM OLD.checklist_match
     OR NEW.recommendation IS DISTINCT FROM OLD.recommendation
     OR NEW.input_tokens IS DISTINCT FROM OLD.input_tokens
     OR NEW.output_tokens IS DISTINCT FROM OLD.output_tokens
     OR NEW.cache_read_tokens IS DISTINCT FROM OLD.cache_read_tokens
     OR NEW.cost_cents IS DISTINCT FROM OLD.cost_cents
     OR NEW.duration_ms IS DISTINCT FROM OLD.duration_ms
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'milestone_ai_verifications · solo reviewed_by_user_id, reviewed_at y justifications son mutables';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_ai_verification_mutations
  ON public.milestone_ai_verifications;
CREATE TRIGGER trg_block_ai_verification_mutations
  BEFORE UPDATE OR DELETE ON public.milestone_ai_verifications
  FOR EACH ROW EXECUTE FUNCTION public.fn_block_ai_verification_mutations();


-- =====================================================================
-- 11 · RLS milestone_ai_verifications
-- =====================================================================

ALTER TABLE public.milestone_ai_verifications ENABLE ROW LEVEL SECURITY;

-- Las partes del pacto leen los dictámenes de su pacto
DROP POLICY IF EXISTS mai_verifications_select_party ON public.milestone_ai_verifications;
CREATE POLICY mai_verifications_select_party ON public.milestone_ai_verifications
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = milestone_ai_verifications.pact_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
  );

GRANT SELECT ON public.milestone_ai_verifications TO authenticated;
GRANT INSERT, UPDATE ON public.milestone_ai_verifications TO service_role;


-- =====================================================================
-- 12 · ai_assistant_messages · turnos del asistente conversacional
-- =====================================================================
-- Hilo scoped a (pact_id, user_id). El usuario solo ve sus turnos y el
-- admin del pacto ve todos.

CREATE TABLE IF NOT EXISTS public.ai_assistant_messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id          uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  user_id          uuid NOT NULL REFERENCES public.users(id),

  role             text NOT NULL CHECK (role IN ('user', 'assistant', 'tool_result')),
  content          text,
  content_blocks   jsonb,

  -- Tool call propuesto (si role='assistant' y propone acción)
  tool_call_name   text,
  tool_call_input  jsonb,
  tool_call_status text CHECK (tool_call_status IS NULL
                              OR tool_call_status IN ('proposed','confirmed','executed','cancelled')),
  tool_call_result jsonb,

  feedback         text CHECK (feedback IS NULL OR feedback IN ('up','down')),

  -- Trazabilidad del modelo
  provider         text CHECK (provider IS NULL OR provider IN ('demo','live')),
  model            text,
  prompt_version   text,
  input_tokens     int,
  output_tokens    int,
  cost_cents       bigint NOT NULL DEFAULT 0,
  latency_ms       int,

  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aam_pact_user_time
  ON public.ai_assistant_messages(pact_id, user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_aam_tool_pending
  ON public.ai_assistant_messages(tool_call_status)
  WHERE tool_call_status = 'proposed';

COMMENT ON TABLE public.ai_assistant_messages IS
  'IA · Turnos del asistente conversacional embebido en cada pacto. Separado '
  'de la tabla messages (chat humano) para no contaminar conversaciones. '
  'Hilo aislado por usuario: cada parte ve solo su hilo, admin ve todos.';

ALTER TABLE public.ai_assistant_messages ENABLE ROW LEVEL SECURITY;

-- El usuario lee solo su hilo. Admin (rol admin del pacto) ve todos los hilos
-- del pacto.
DROP POLICY IF EXISTS aam_select_own_or_admin ON public.ai_assistant_messages;
CREATE POLICY aam_select_own_or_admin ON public.ai_assistant_messages
  FOR SELECT TO authenticated
  USING (
    -- El usuario lee su propio hilo
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = ai_assistant_messages.user_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
    OR
    -- Cualquier parte del pacto puede leer los hilos del asistente
    -- (el promotor necesita ver el contexto de todos los participantes)
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      JOIN public.users u2 ON u2.id = pp.user_id
      WHERE pp.pact_id = ai_assistant_messages.pact_id
        AND u2.auth_provider_id = auth.uid()::text
        AND u2.deleted_at IS NULL
    )
  );

GRANT SELECT ON public.ai_assistant_messages TO authenticated;
GRANT INSERT, UPDATE ON public.ai_assistant_messages TO service_role;


-- =====================================================================
-- 13 · Función helper · fn_user_in_pact
-- =====================================================================
-- Usada por la Edge Function ai-gateway para validar pertenencia.
-- Devuelve TRUE si el usuario actual es parte del pacto.

CREATE OR REPLACE FUNCTION public.fn_user_in_pact(p_pact_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.pact_parties pp
    JOIN public.users u ON u.id = pp.user_id
    WHERE pp.pact_id = p_pact_id
      AND u.auth_provider_id = auth.uid()::text
      AND u.deleted_at IS NULL
  );
$$;

GRANT EXECUTE ON FUNCTION public.fn_user_in_pact(uuid) TO authenticated, service_role;


-- =====================================================================
-- 14 · RPC · sf_get_pact_ai_context (SECURITY DEFINER)
-- =====================================================================
-- Devuelve el CONTEXT_BLOCK que el asistente conversacional necesita.
-- Compactado a JSON para minimizar tokens. Usado por ai-assistant-turn.

CREATE OR REPLACE FUNCTION public.sf_get_pact_ai_context(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_in_pact boolean;
  v_context jsonb;
BEGIN
  -- Validar pertenencia
  SELECT public.fn_user_in_pact(p_pact_id) INTO v_in_pact;
  IF NOT v_in_pact THEN
    RAISE EXCEPTION 'No autorizado: usuario no pertenece al pacto %', p_pact_id
      USING ERRCODE = '42501';
  END IF;

  SELECT id INTO v_user_id FROM public.users
  WHERE auth_provider_id = auth.uid()::text AND deleted_at IS NULL;

  -- Construir el contexto
  SELECT jsonb_build_object(
    'pact', (
      SELECT jsonb_build_object(
        'id', p.id,
        'display_id', p.display_id,
        'title', p.title,
        'state', p.state,
        'total_amount_eur', p.total_amount_cents / 100.0,
        'currency', 'EUR',
        'budget_consumed_eur', coalesce(p.budget_consumed_cents, 0) / 100.0,
        'deposit_current_eur', coalesce(p.deposit_current_cents, 0) / 100.0,
        'advance_released_eur', coalesce(p.advance_released_cents, 0) / 100.0,
        'advance_outstanding_eur', coalesce(p.advance_outstanding_cents, 0) / 100.0,
        'is_demo_only', p.is_demo_only,
        'model_version', p.model_version
      )
      FROM public.pacts p WHERE p.id = p_pact_id
    ),

    'current_user_role', (
      SELECT pp.role FROM public.pact_parties pp
      WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id LIMIT 1
    ),

    'parties', (
      SELECT jsonb_agg(jsonb_build_object(
        'role', pp.role,
        'display_name', coalesce(u.full_name, pp.snapshot_full_name, pp.snapshot_email::text),
        'state', CASE WHEN pp.signed_at IS NOT NULL THEN 'signed'
                      WHEN pp.accepted_at IS NOT NULL THEN 'accepted'
                      ELSE 'invited' END
      ))
      FROM public.pact_parties pp
      LEFT JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = p_pact_id
    ),

    'milestones', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', m.id,
        'display_id', m.display_id,
        'ordinal', m.ordinal,
        'name', m.name,
        'amount_eur', m.amount_cents / 100.0,
        'net_amount_eur', coalesce(m.net_amount_cents, m.amount_cents) / 100.0,
        'state', m.state,
        'has_invoice', m.invoice_storage_path IS NOT NULL
      ) ORDER BY m.ordinal)
      FROM public.milestones m
      WHERE m.pact_id = p_pact_id
    ),

    'last_verifications', (
      SELECT jsonb_agg(jsonb_build_object(
        'milestone_id', mav.milestone_id,
        'score', mav.score,
        'verdict', mav.verdict,
        'summary', mav.summary,
        'findings_count', jsonb_array_length(mav.findings),
        'created_at', mav.created_at
      ))
      FROM public.milestone_ai_verifications mav
      WHERE mav.pact_id = p_pact_id
      ORDER BY mav.created_at DESC
      LIMIT 6
    ),

    'health', (
      -- pact_health_scores es snapshot-based (varias filas por pacto, una
      -- por calculated_at). Tomamos la más reciente y completamos el
      -- ia_evidence_score con el cálculo on-demand desde las verificaciones.
      SELECT jsonb_build_object(
        'overall_score', phs.score,
        'milestone_compliance_pct', phs.milestone_compliance_pct,
        'no_disputes_pct', phs.no_disputes_pct,
        'snapshot_at', phs.calculated_at,
        'ia_evidence_score', (
          SELECT round(
            sum(mav.score::numeric * m.amount_cents) / nullif(sum(m.amount_cents), 0),
            2
          )
          FROM public.milestone_ai_verifications mav
          JOIN public.milestones m ON m.id = mav.milestone_id
          WHERE mav.pact_id = p_pact_id
            AND mav.id IN (
              SELECT DISTINCT ON (milestone_id) id
              FROM public.milestone_ai_verifications
              WHERE pact_id = p_pact_id
              ORDER BY milestone_id, created_at DESC
            )
        )
      )
      FROM public.pact_health_scores phs
      WHERE phs.pact_id = p_pact_id
      ORDER BY phs.calculated_at DESC
      LIMIT 1
    )
  ) INTO v_context;

  RETURN v_context;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_pact_ai_context(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.sf_get_pact_ai_context(uuid) IS
  'IA · Devuelve el contexto compactado del pacto en jsonb. Usado por '
  'ai-assistant-turn para construir el prompt del modelo. SECURITY DEFINER '
  'con validación de pertenencia al pacto.';


-- =====================================================================
-- 15 · RPC · sf_record_ai_verification (SECURITY DEFINER)
-- =====================================================================
-- La Edge Function ai-verify-milestone llama a este RPC para persistir el
-- dictamen y actualizar pact_health_scores.ia_evidence_score (media móvil
-- ponderada por importe del hito).

CREATE OR REPLACE FUNCTION public.sf_record_ai_verification(
  p_milestone_id uuid,
  p_provider text,
  p_model text,
  p_prompt_version text,
  p_input_hash text,
  p_evidences_count smallint,
  p_documents_count smallint,
  p_score smallint,
  p_verdict text,
  p_summary text,
  p_findings jsonb,
  p_checklist_match jsonb,
  p_recommendation text,
  p_input_tokens int,
  p_output_tokens int,
  p_cache_read_tokens int,
  p_cost_cents bigint,
  p_duration_ms int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pact_id uuid;
  v_verification_id uuid;
BEGIN
  -- Resolver pact_id desde milestone
  SELECT pact_id INTO v_pact_id FROM public.milestones WHERE id = p_milestone_id;
  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Milestone % no encontrado', p_milestone_id;
  END IF;

  -- INSERT en la tabla
  INSERT INTO public.milestone_ai_verifications (
    milestone_id, pact_id, provider, model, prompt_version,
    input_hash_sha256, evidences_count, documents_count,
    score, verdict, summary, findings, checklist_match, recommendation,
    input_tokens, output_tokens, cache_read_tokens, cost_cents, duration_ms
  ) VALUES (
    p_milestone_id, v_pact_id, p_provider, p_model, p_prompt_version,
    p_input_hash, p_evidences_count, p_documents_count,
    p_score, p_verdict::ai_verdict, p_summary, p_findings, p_checklist_match, p_recommendation,
    p_input_tokens, p_output_tokens, p_cache_read_tokens, p_cost_cents, p_duration_ms
  )
  RETURNING id INTO v_verification_id;

  -- NOTA: el ia_evidence_score se calcula on-demand vía sf_get_pact_ai_context.
  -- Si en el futuro quieres incorporarlo al snapshot de pact_health_scores,
  -- la lógica de recalculación de salud (que ya existe en tu sistema) puede
  -- consultar milestone_ai_verifications para incluirlo en el próximo snapshot.

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, actor_user_id, payload)
  VALUES (
    v_pact_id,
    'ai_verification_completed',
    null,
    jsonb_build_object(
      'verification_id', v_verification_id,
      'milestone_id', p_milestone_id,
      'verdict', p_verdict,
      'score', p_score,
      'provider', p_provider
    )
  );

  RETURN v_verification_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sf_record_ai_verification(uuid, text, text, text, text, smallint, smallint, smallint, text, text, jsonb, jsonb, text, int, int, int, bigint, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sf_record_ai_verification(uuid, text, text, text, text, smallint, smallint, smallint, text, text, jsonb, jsonb, text, int, int, int, bigint, int) TO service_role;


-- =====================================================================
-- 16 · RPC · sf_record_assistant_turn (SECURITY DEFINER)
-- =====================================================================
-- Persiste un par de turnos (user + assistant) en ai_assistant_messages.
-- Devuelve los IDs creados.

CREATE OR REPLACE FUNCTION public.sf_record_assistant_turn(
  p_pact_id uuid,
  p_user_message text,
  p_assistant_content text,
  p_assistant_blocks jsonb,
  p_tool_call_name text,
  p_tool_call_input jsonb,
  p_provider text,
  p_model text,
  p_prompt_version text,
  p_input_tokens int,
  p_output_tokens int,
  p_cost_cents bigint,
  p_latency_ms int
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_msg_id uuid;
  v_assistant_msg_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM public.users
  WHERE auth_provider_id = auth.uid()::text AND deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  IF NOT public.fn_user_in_pact(p_pact_id) THEN
    RAISE EXCEPTION 'Usuario no pertenece al pacto %', p_pact_id USING ERRCODE = '42501';
  END IF;

  -- Insert turno usuario
  INSERT INTO public.ai_assistant_messages (
    pact_id, user_id, role, content, provider
  ) VALUES (
    p_pact_id, v_user_id, 'user', p_user_message, p_provider
  ) RETURNING id INTO v_user_msg_id;

  -- Insert turno asistente
  INSERT INTO public.ai_assistant_messages (
    pact_id, user_id, role, content, content_blocks,
    tool_call_name, tool_call_input,
    tool_call_status,
    provider, model, prompt_version,
    input_tokens, output_tokens, cost_cents, latency_ms
  ) VALUES (
    p_pact_id, v_user_id, 'assistant', p_assistant_content, p_assistant_blocks,
    p_tool_call_name, p_tool_call_input,
    CASE WHEN p_tool_call_name IS NOT NULL THEN 'proposed' ELSE NULL END,
    p_provider, p_model, p_prompt_version,
    p_input_tokens, p_output_tokens, p_cost_cents, p_latency_ms
  ) RETURNING id INTO v_assistant_msg_id;

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, actor_user_id, payload)
  VALUES (
    p_pact_id, 'ai_assistant_message', v_user_id,
    jsonb_build_object(
      'assistant_msg_id', v_assistant_msg_id,
      'tool_proposed', p_tool_call_name,
      'provider', p_provider
    )
  );

  RETURN jsonb_build_object(
    'user_message_id', v_user_msg_id,
    'assistant_message_id', v_assistant_msg_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sf_record_assistant_turn(uuid, text, text, jsonb, text, jsonb, text, text, text, int, int, bigint, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sf_record_assistant_turn(uuid, text, text, jsonb, text, jsonb, text, text, text, int, int, bigint, int) TO service_role;


-- =====================================================================
-- 17 · RPC · sf_ai_today_cost_cents
-- =====================================================================
-- Devuelve el coste IA acumulado hoy (UTC). Usado por el kill switch del
-- gateway para decidir si forzar demo mode.

CREATE OR REPLACE FUNCTION public.sf_ai_today_cost_cents()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(sum(cost_cents), 0)
  FROM public.ai_runs
  WHERE created_at >= date_trunc('day', now())
    AND provider = 'live';
$$;

GRANT EXECUTE ON FUNCTION public.sf_ai_today_cost_cents() TO service_role;


-- =====================================================================
-- 18 · Recarga del schema cache
-- =====================================================================
NOTIFY pgrst, 'reload schema';
