-- =====================================================================
-- Sprint 4 chunk 1 · Migration 0022
-- Refactor del schema al modelo de producto v2.0
-- =====================================================================
-- Cambios principales:
--   1. pacts: campos para depósito variable (15-40%) y consumo de presupuesto
--   2. milestones: versionado + documento detallado + factura obligatoria
--   3. NUEVA tabla pact_addendums: ampliaciones de presupuesto formales
--   4. NUEVA tabla deposit_movements: trail append-only del depósito
--   5. Nuevos enums: addendum_state, deposit_movement_type
--   6. pact_state: añadir paused_pending_tech
--   7. RLS policies y triggers append-only
--
-- Backwards-compat:
--   · Los pacts v1 existentes mantienen su comportamiento (deposit_required_pct
--     queda como 30 por defecto). Los nuevos campos en milestones son NULL.
--   · Las RPCs del modelo v1 (sf_create_pact_draft, sf_add_milestone,
--     sf_finalize_pact_draft) siguen funcionando. Las nuevas RPCs del v2.0
--     se añadirán en migraciones siguientes (chunks 2-5 del Sprint 4).
-- =====================================================================

-- =====================================================================
-- 1 · NUEVOS ENUMS
-- =====================================================================

DO $$ BEGIN
  CREATE TYPE addendum_state AS ENUM (
    'proposed',     -- recién creado, pendiente de firmas
    'signing',      -- alguna parte ha firmado
    'active',       -- todas las partes han firmado, el anexo está vigente
    'cancelled'     -- cancelado antes de firmarse o tras paralización
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE deposit_movement_type AS ENUM (
    'initial_deposit',           -- promotor deposita el % inicial (hito 0)
    'replenishment',             -- reposición tras una certificación aprobada
    'automatic_execution',       -- PactStream ejecuta tras T+72h de impago
    'addendum_replenishment',    -- reposición tras firmar un anexo (presupuesto ampliado)
    'refund'                     -- devolución al promotor (cancelación, exceso)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =====================================================================
-- 2 · pact_state: añadir paused_pending_tech
-- =====================================================================
DO $$ BEGIN
  ALTER TYPE pact_state ADD VALUE IF NOT EXISTS 'paused_pending_tech';
EXCEPTION WHEN others THEN NULL; END $$;

-- =====================================================================
-- 3 · TABLA pacts · nuevos campos del modelo v2.0
-- =====================================================================
ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS deposit_required_pct numeric(5,2)
    NOT NULL DEFAULT 30.00
    CHECK (deposit_required_pct BETWEEN 15.00 AND 40.00);

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS deposit_current_cents bigint
    NOT NULL DEFAULT 0
    CHECK (deposit_current_cents >= 0);

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS budget_consumed_cents bigint
    NOT NULL DEFAULT 0
    CHECK (budget_consumed_cents >= 0);

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS certification_frequency_text text;

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS insurance_premium_cents bigint
    NOT NULL DEFAULT 0
    CHECK (insurance_premium_cents >= 0);

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS model_version text
    NOT NULL DEFAULT 'v1';
-- Pacts creados antes de esta migración quedan marcados como 'v1'.
-- Pacts nuevos a partir del Sprint 4 chunk 2 se marcarán como 'v2'.

COMMENT ON COLUMN public.pacts.deposit_required_pct IS
  'v2.0 · Porcentaje del presupuesto total que debe mantenerse en custodia. Negociable 15-40, default 30.';
COMMENT ON COLUMN public.pacts.deposit_current_cents IS
  'v2.0 · Saldo actual del depósito de garantía en custodia.';
COMMENT ON COLUMN public.pacts.budget_consumed_cents IS
  'v2.0 · Suma acumulada de pagos liberados (sin contar depósito inicial).';
COMMENT ON COLUMN public.pacts.certification_frequency_text IS
  'v2.0 · Frecuencia orientativa de certificación pactada: semanal, quincenal, mensual, etc.';
COMMENT ON COLUMN public.pacts.insurance_premium_cents IS
  'v2.0 · Prima de la póliza del depósito, variable según deposit_required_pct.';
COMMENT ON COLUMN public.pacts.model_version IS
  'v1 = hitos predefinidos (sprint 1-2). v2 = certificaciones por demanda (sprint 4+).';

-- =====================================================================
-- 4 · TABLA milestones · versionado + documento detallado + factura
-- =====================================================================
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS version smallint
    NOT NULL DEFAULT 1
    CHECK (version >= 1);

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS previous_version_id uuid
    REFERENCES public.milestones(id);

-- Documento detallado (opcional · obligatorio en obra mayor > 50K€)
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS detailed_doc_storage_path text;
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS detailed_doc_sha256 text;
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS detailed_doc_mime_type text;
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS detailed_doc_size_bytes bigint
    CHECK (detailed_doc_size_bytes IS NULL OR detailed_doc_size_bytes > 0);

-- Factura del constructor (obligatoria en v2.0)
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS invoice_storage_path text;
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS invoice_sha256 text;
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS invoice_number text;
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS invoice_size_bytes bigint
    CHECK (invoice_size_bytes IS NULL OR invoice_size_bytes > 0);

CREATE INDEX IF NOT EXISTS idx_milestones_previous_version
  ON public.milestones(previous_version_id)
  WHERE previous_version_id IS NOT NULL;

COMMENT ON COLUMN public.milestones.version IS
  'v2.0 · Versión de la certificación. Incrementa con cada edición tras rechazo.';
COMMENT ON COLUMN public.milestones.previous_version_id IS
  'v2.0 · FK al milestone anterior si esta es una edición. NULL si es la versión 1.';
COMMENT ON COLUMN public.milestones.detailed_doc_storage_path IS
  'v2.0 · Path en Storage del documento detallado (mediciones, capítulos, etc.).';
COMMENT ON COLUMN public.milestones.invoice_storage_path IS
  'v2.0 · Path en Storage de la factura del constructor (obligatoria desde v2).';

-- =====================================================================
-- 5 · NUEVA TABLA pact_addendums
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.pact_addendums (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  display_id      text NOT NULL UNIQUE,         -- 'PS-ANX-YYYYMMDD-NNNNNN'
  ordinal         smallint NOT NULL CHECK (ordinal >= 1),

  -- Contenido
  title           text NOT NULL,
  description     text,
  extra_amount_cents bigint NOT NULL,           -- positivo o negativo (puede reducir alcance)
  extra_days      smallint NOT NULL DEFAULT 0,  -- días adicionales si aplica

  -- Justificación técnica (obligatoria si extra_amount_cents > 10000€)
  justification   text,

  -- Documento detallado del anexo (obligatorio si extra > 10K€)
  detailed_doc_storage_path text,
  detailed_doc_sha256       text,
  detailed_doc_mime_type    text,
  detailed_doc_size_bytes   bigint CHECK (detailed_doc_size_bytes IS NULL OR detailed_doc_size_bytes > 0),

  -- Propuesto por
  proposed_by_user_id uuid NOT NULL REFERENCES public.users(id),
  proposed_by_role  pact_party_role NOT NULL,

  -- Firmas de las partes
  signed_at_promotor    timestamptz,
  signed_at_constructor timestamptz,
  signed_at_tecnico     timestamptz,  -- NULL en obra menor

  -- Estado
  state           addendum_state NOT NULL DEFAULT 'proposed',
  state_updated_at timestamptz NOT NULL DEFAULT now(),

  -- Audit
  created_at      timestamptz NOT NULL DEFAULT now(),
  finalized_at    timestamptz,    -- cuando state pasa a 'active' o 'cancelled'
  cancelled_reason text,

  -- Constraint: solo un anexo activo por ordinal por pact
  CONSTRAINT pact_addendums_ordinal_per_pact UNIQUE (pact_id, ordinal)
);

CREATE INDEX IF NOT EXISTS idx_pact_addendums_pact
  ON public.pact_addendums(pact_id);
CREATE INDEX IF NOT EXISTS idx_pact_addendums_state
  ON public.pact_addendums(state);
CREATE INDEX IF NOT EXISTS idx_pact_addendums_proposed_by
  ON public.pact_addendums(proposed_by_user_id);

COMMENT ON TABLE public.pact_addendums IS
  'v2.0 · Modificaciones formales del pacto (ampliación de alcance, imprevisto técnico, cambio de materiales, extensión de plazo). Requiere re-firma de todas las partes.';

-- =====================================================================
-- 6 · NUEVA TABLA deposit_movements (append-only)
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.deposit_movements (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES public.pacts(id) ON DELETE RESTRICT,

  movement_type   deposit_movement_type NOT NULL,
  amount_cents    bigint NOT NULL,         -- positivo = entrada al depósito; negativo = salida

  -- Quién lo provocó
  triggered_by_user_id uuid REFERENCES public.users(id),

  -- Relaciones opcionales
  related_milestone_id uuid REFERENCES public.milestones(id),
  related_addendum_id  uuid REFERENCES public.pact_addendums(id),

  -- Snapshot del saldo
  balance_before_cents bigint NOT NULL CHECK (balance_before_cents >= 0),
  balance_after_cents  bigint NOT NULL CHECK (balance_after_cents >= 0),

  -- Trazabilidad externa
  mangopay_transaction_id text,    -- ID externo cuando integremos Mangopay
  notes           text,

  -- Sello temporal inmutable
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deposit_movements_pact
  ON public.deposit_movements(pact_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_deposit_movements_type
  ON public.deposit_movements(movement_type);

COMMENT ON TABLE public.deposit_movements IS
  'v2.0 · Trail append-only del depósito de garantía. Cada movimiento registra el saldo antes/después y un snapshot completo.';

-- =====================================================================
-- 7 · TRIGGERS append-only en deposit_movements
-- =====================================================================
CREATE OR REPLACE FUNCTION public.prevent_deposit_movement_modification()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Los movimientos del depósito son append-only. DELETE no permitido.';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Los movimientos del depósito son append-only. UPDATE no permitido.';
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_deposit_movements_append_only ON public.deposit_movements;
CREATE TRIGGER trg_deposit_movements_append_only
  BEFORE UPDATE OR DELETE ON public.deposit_movements
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_deposit_movement_modification();

-- =====================================================================
-- 8 · TRIGGER de actualización de presupuesto al activarse anexo
-- =====================================================================
CREATE OR REPLACE FUNCTION public.handle_addendum_active()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_total bigint;
  v_new_total bigint;
BEGIN
  -- Solo nos interesa la transición a 'active'
  IF NEW.state != 'active' OR OLD.state = 'active' THEN
    RETURN NEW;
  END IF;

  -- Re-calcular el presupuesto total del pacto
  SELECT total_amount_cents INTO v_old_total
  FROM public.pacts WHERE id = NEW.pact_id;

  v_new_total := v_old_total + NEW.extra_amount_cents;

  IF v_new_total < 0 THEN
    RAISE EXCEPTION 'El anexo deja el presupuesto en negativo (%). Operación denegada.', v_new_total;
  END IF;

  UPDATE public.pacts
  SET total_amount_cents = v_new_total
  WHERE id = NEW.pact_id;

  -- Marcar el anexo como finalizado
  NEW.finalized_at := now();

  -- Audit
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (NEW.pact_id, 'addendum_activated',
    jsonb_build_object(
      'addendum_id', NEW.id,
      'ordinal', NEW.ordinal,
      'extra_amount_cents', NEW.extra_amount_cents,
      'old_total_cents', v_old_total,
      'new_total_cents', v_new_total
    ),
    NEW.proposed_by_user_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_addendum_active_update_total ON public.pact_addendums;
CREATE TRIGGER trg_addendum_active_update_total
  BEFORE UPDATE OF state ON public.pact_addendums
  FOR EACH ROW
  WHEN (NEW.state = 'active' AND OLD.state != 'active')
  EXECUTE FUNCTION public.handle_addendum_active();

-- =====================================================================
-- 9 · TRIGGER de alerta cuando el depósito baja al 50% del % pactado
-- =====================================================================
-- Crea una notificación al promotor cuando deposit_current_cents
-- cae bajo el 50% del % requerido.
CREATE OR REPLACE FUNCTION public.handle_deposit_low_alert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_required_cents bigint;
  v_threshold_cents bigint;
  v_promotor_user_id uuid;
  v_idem text;
BEGIN
  -- Solo nos interesa cuando el saldo BAJA
  IF NEW.deposit_current_cents >= OLD.deposit_current_cents THEN
    RETURN NEW;
  END IF;

  v_required_cents := (NEW.total_amount_cents * NEW.deposit_required_pct / 100)::bigint;
  v_threshold_cents := v_required_cents / 2;

  -- Solo disparamos si cruzamos el threshold ahora
  IF OLD.deposit_current_cents >= v_threshold_cents
     AND NEW.deposit_current_cents < v_threshold_cents THEN

    SELECT user_id INTO v_promotor_user_id
    FROM public.pact_parties
    WHERE pact_id = NEW.id AND role = 'promotor'
    LIMIT 1;

    IF v_promotor_user_id IS NOT NULL THEN
      v_idem := 'deposit_low:' || NEW.id::text || ':' || extract(epoch from now())::bigint::text;

      INSERT INTO public.notifications (
        user_id, pact_id, notification_type, channel, priority,
        title, body, cta_url, idempotency_key
      ) VALUES
        (v_promotor_user_id, NEW.id, 'deposit_low',
         'email'::notification_channel, 'high'::notification_priority,
         'Depósito de garantía bajo · ' || NEW.title,
         'El depósito del pacto ' || NEW.display_id || ' ha bajado al 50% del mínimo pactado (' ||
         NEW.deposit_required_pct || '%). Reponlo cuanto antes para evitar paralización del pacto.',
         '/pacts/' || NEW.id, v_idem || ':email'),
        (v_promotor_user_id, NEW.id, 'deposit_low',
         'in_app'::notification_channel, 'high'::notification_priority,
         'Depósito de garantía bajo',
         'El depósito ha bajado al 50% del mínimo pactado. Repón cuanto antes.',
         '/pacts/' || NEW.id, v_idem || ':in_app');
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_deposit_low_alert error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deposit_low_alert ON public.pacts;
CREATE TRIGGER trg_deposit_low_alert
  AFTER UPDATE OF deposit_current_cents ON public.pacts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_deposit_low_alert();

-- =====================================================================
-- 10 · ROW LEVEL SECURITY en las nuevas tablas
-- =====================================================================

-- pact_addendums
ALTER TABLE public.pact_addendums ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pact_addendums_select_party ON public.pact_addendums;
CREATE POLICY pact_addendums_select_party ON public.pact_addendums
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = pact_addendums.pact_id
        AND u.auth_provider_id = (auth.uid())::text
        AND u.deleted_at IS NULL
    )
  );

-- INSERT/UPDATE/DELETE solo vía RPCs SECURITY DEFINER (no policies de cliente)

-- deposit_movements
ALTER TABLE public.deposit_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS deposit_movements_select_party ON public.deposit_movements;
CREATE POLICY deposit_movements_select_party ON public.deposit_movements
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = deposit_movements.pact_id
        AND u.auth_provider_id = (auth.uid())::text
        AND u.deleted_at IS NULL
    )
  );

-- =====================================================================
-- 11 · GRANTS para las nuevas tablas
-- =====================================================================
GRANT SELECT ON public.pact_addendums TO authenticated;
GRANT SELECT ON public.deposit_movements TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.pact_addendums TO service_role;
GRANT INSERT ON public.deposit_movements TO service_role;
-- Nota: UPDATE y DELETE en deposit_movements están bloqueados por trigger

-- =====================================================================
-- 12 · Actualizar el state machine de pacts (incluir paused_pending_tech)
-- =====================================================================
-- Solo reemplaza la función, el trigger se mantiene.
CREATE OR REPLACE FUNCTION public.validate_pact_state_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  valid_transitions text[];
BEGIN
  IF OLD.state = NEW.state THEN
    RETURN NEW;
  END IF;

  valid_transitions := CASE OLD.state
    WHEN 'draft' THEN ARRAY['inviting', 'cancelled']
    WHEN 'inviting' THEN ARRAY['signing', 'cancelled']
    WHEN 'signing' THEN ARRAY['signed', 'cancelled']
    WHEN 'signed' THEN ARRAY['funded', 'cancelled']
    WHEN 'funded' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'in_execution' THEN ARRAY['paused_pending_tech', 'disputed', 'completed', 'suspended']
    WHEN 'paused_pending_tech' THEN ARRAY['in_execution', 'disputed', 'cancelled']
    WHEN 'disputed' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'suspended' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'completed' THEN ARRAY['closed']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (NEW.state::text = ANY(valid_transitions)) THEN
    RAISE EXCEPTION 'Transición de estado de pacto inválida: % → %', OLD.state, NEW.state;
  END IF;

  INSERT INTO pact_state_transitions(pact_id, from_state, to_state, transitioned_by_user_id)
  VALUES (NEW.id, OLD.state, NEW.state, current_user_id());

  NEW.state_updated_at := now();
  RETURN NEW;
END;
$$;

-- =====================================================================
-- 13 · BACKFILL para pacts existentes (v1)
-- =====================================================================
-- Los pacts existentes quedan marcados como 'v1' y mantienen su comportamiento.
-- El default de model_version='v1' ya cubre esto, pero lo confirmamos explícito.
UPDATE public.pacts
SET model_version = 'v1'
WHERE model_version IS NULL;

NOTIFY pgrst, 'reload schema';

-- =====================================================================
-- VERIFICACIÓN DE LA MIGRACIÓN
-- =====================================================================
-- Tras aplicar, ejecuta:
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'pacts' AND column_name LIKE 'deposit%';
--   SELECT relname FROM pg_class WHERE relname IN ('pact_addendums', 'deposit_movements');
--   SELECT enumlabel FROM pg_enum WHERE enumtypid = 'addendum_state'::regtype;
--   SELECT enumlabel FROM pg_enum WHERE enumtypid = 'deposit_movement_type'::regtype;
-- =====================================================================
