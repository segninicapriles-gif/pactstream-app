-- =====================================================================
-- Sprint 5 chunk 1 · Migration 0029
-- Modelo v2.1 · Adelanto con doble garantía (reserva + variable)
-- =====================================================================
-- Cambia el modelo conceptual del Sprint 4:
--
--   v2.0: "Depósito en custodia" del 15-40% del presupuesto.
--   v2.1: "Adelanto" del 10-40% que se descompone internamente en:
--           - 10% fijo  → reserva custodiada hasta el finiquito
--           - 0-30% var → entregado al constructor el día 1
--
-- Nuevos componentes:
--   - Por cada certificación, el promotor debe pre-depositar el NETO
--     (bruto - amortización del adelanto) antes de que el constructor
--     pueda emitirla. Plazo: 3 días desde la creación del borrador.
--   - Si el plazo expira sin pre-depósito → obra paralizada
--     (o el constructor activa el toggle "avanzar bajo responsabilidad").
--   - Cobertura del adelanto vía seguro de caución (tabla nueva).
--
-- Compatibilidad: los pacts v2.0 ya creados siguen funcionando — los
-- nuevos campos tienen DEFAULT 0/false y no afectan al modelo viejo.
-- =====================================================================


-- =====================================================================
-- 1 · ALTER pacts · campos del Adelanto v2.1
-- =====================================================================

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS advance_reserve_pct numeric(5,2)
    NOT NULL DEFAULT 10.00
    CHECK (advance_reserve_pct >= 0 AND advance_reserve_pct <= 20);

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS advance_released_cents bigint
    NOT NULL DEFAULT 0
    CHECK (advance_released_cents >= 0);

ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS advance_outstanding_cents bigint
    NOT NULL DEFAULT 0
    CHECK (advance_outstanding_cents >= 0);

COMMENT ON COLUMN public.pacts.advance_reserve_pct IS
  'v2.1 · Porcentaje fijo del presupuesto que queda custodiado como reserva '
  'de finiquito (default 10). El resto del adelanto se entrega al constructor.';

COMMENT ON COLUMN public.pacts.advance_released_cents IS
  'v2.1 · Importe del adelanto efectivamente entregado al constructor el día 1 '
  '(= deposit_required_pct - advance_reserve_pct sobre el total).';

COMMENT ON COLUMN public.pacts.advance_outstanding_cents IS
  'v2.1 · Saldo vivo del adelanto (cobertura activa de la póliza de caución). '
  'Decrece con cada certificación pagada en función de la amortización.';


-- =====================================================================
-- 2 · ALTER milestones · campos v2.1
-- =====================================================================

-- amount_cents (existente) sigue representando el BRUTO certificado.
-- net_amount_cents (nuevo) es el importe a pagar al constructor.

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS advance_amortization_cents bigint
    NOT NULL DEFAULT 0
    CHECK (advance_amortization_cents >= 0);

-- Columna generada: amount_cents - advance_amortization_cents.
-- Garantiza coherencia automática (no se puede desincronizar).
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS net_amount_cents bigint
    GENERATED ALWAYS AS (amount_cents - advance_amortization_cents) STORED;

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS predeposit_received_cents bigint
    NOT NULL DEFAULT 0
    CHECK (predeposit_received_cents >= 0);

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS predeposit_deadline_at timestamptz;

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS forced_under_responsibility boolean
    NOT NULL DEFAULT false;

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS forced_under_responsibility_at timestamptz;

COMMENT ON COLUMN public.milestones.advance_amortization_cents IS
  'v2.1 · Importe que esta certificación amortiza del adelanto entregado al '
  'constructor (= amount_cents * advance_pct / 100).';

COMMENT ON COLUMN public.milestones.net_amount_cents IS
  'v2.1 · Importe neto a pagar al constructor (bruto - amortización). '
  'Columna calculada automáticamente.';

COMMENT ON COLUMN public.milestones.predeposit_received_cents IS
  'v2.1 · Importe que el promotor ha pre-depositado en custodia para esta '
  'certificación. Debe igualar net_amount_cents antes de que se pueda emitir.';

COMMENT ON COLUMN public.milestones.predeposit_deadline_at IS
  'v2.1 · Plazo límite (3 días desde creación del borrador) para que el '
  'promotor complete el pre-depósito. Si expira, la cert pasa a paused_no_predeposit.';

COMMENT ON COLUMN public.milestones.forced_under_responsibility IS
  'v2.1 · El constructor decidió avanzar sin pre-depósito completo, asumiendo '
  'el riesgo. Libera a PactStream/aseguradora de responsabilidad sobre lo '
  'ejecutado en este intervalo.';


-- =====================================================================
-- 3 · Enum milestone_state · nuevos estados v2.1
-- =====================================================================
-- ALTER TYPE ... ADD VALUE no se puede ejecutar dentro de una transacción
-- explícita. Supabase SQL Editor hace auto-commit por statement, así que
-- estas líneas deberían pasar sin problema.

ALTER TYPE public.milestone_state ADD VALUE IF NOT EXISTS 'pending_predeposit';
ALTER TYPE public.milestone_state ADD VALUE IF NOT EXISTS 'paused_no_predeposit';


-- =====================================================================
-- 4 · Enum deposit_movement_type · nuevos tipos v2.1
-- =====================================================================

ALTER TYPE public.deposit_movement_type ADD VALUE IF NOT EXISTS 'reserve_deposit';
ALTER TYPE public.deposit_movement_type ADD VALUE IF NOT EXISTS 'predeposit_for_cert';
ALTER TYPE public.deposit_movement_type ADD VALUE IF NOT EXISTS 'surety_claim_payout';
ALTER TYPE public.deposit_movement_type ADD VALUE IF NOT EXISTS 'final_reserve_release';


-- =====================================================================
-- 5 · NUEVA TABLA surety_policies · pólizas de caución
-- =====================================================================
-- En MVP los datos se rellenan manualmente desde el panel admin.
-- Cuando cerremos integración con aseguradora real (Mapfre, Crédito y
-- Caución, Atradius), pasarán a alimentarse vía API.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'surety_policy_status') THEN
    CREATE TYPE public.surety_policy_status AS ENUM (
      'draft',         -- registrada pero pendiente de emisión
      'active',        -- emitida y cubriendo el adelanto
      'claimed',       -- siniestro abierto (constructor desaparecido, etc.)
      'released',      -- liberada al cierre normal de la obra
      'cancelled'      -- cancelada antes de cierre (acuerdo, anulación...)
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.surety_policies (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id                  uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,

  -- Datos de la póliza
  insurer_name             text NOT NULL,             -- 'Mapfre Caución y Crédito', etc.
  policy_number            text,                       -- número externo asignado
  premium_cents            bigint CHECK (premium_cents IS NULL OR premium_cents >= 0),

  -- Cobertura
  initial_coverage_cents   bigint NOT NULL CHECK (initial_coverage_cents > 0),
  current_coverage_cents   bigint NOT NULL CHECK (current_coverage_cents >= 0),

  -- Estado y fechas
  status                   surety_policy_status NOT NULL DEFAULT 'draft',
  issued_at                timestamptz,
  released_at              timestamptz,
  cancelled_at             timestamptz,

  -- Siniestros (jsonb append-only)
  claims                   jsonb NOT NULL DEFAULT '[]'::jsonb,

  -- Notas
  notes                    text,                        -- visible para las partes
  admin_notes              text,                        -- interno PactStream

  -- Audit
  created_at               timestamptz NOT NULL DEFAULT now(),
  created_by_user_id       uuid REFERENCES public.users(id),
  updated_at               timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT surety_policies_one_active_per_pact
    UNIQUE (pact_id)
);

CREATE INDEX IF NOT EXISTS idx_surety_policies_pact
  ON public.surety_policies(pact_id);
CREATE INDEX IF NOT EXISTS idx_surety_policies_status
  ON public.surety_policies(status);

COMMENT ON TABLE public.surety_policies IS
  'v2.1 · Póliza de caución que respalda el adelanto entregado al constructor. '
  'En MVP se rellena manualmente; en producción se sincronizará con la API '
  'de la aseguradora elegida.';

COMMENT ON COLUMN public.surety_policies.current_coverage_cents IS
  'Saldo vivo de la cobertura (= initial_coverage_cents - amortizado). '
  'Se actualiza por trigger cuando una cert pasa a paid.';


-- =====================================================================
-- 6 · RLS de surety_policies
-- =====================================================================

ALTER TABLE public.surety_policies ENABLE ROW LEVEL SECURITY;

-- Las partes del pacto ven la póliza de su pacto
DROP POLICY IF EXISTS surety_policies_select_party ON public.surety_policies;
CREATE POLICY surety_policies_select_party ON public.surety_policies
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = surety_policies.pact_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
  );

-- Solo service_role escribe (los admins crean/editan vía RPCs SECURITY DEFINER)
GRANT SELECT ON public.surety_policies TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.surety_policies TO service_role;


-- =====================================================================
-- 7 · Trigger · al pagar una cert, decrementar cobertura de la póliza
-- =====================================================================
-- Cuando un milestone pasa a 'paid', restamos su amortización de la
-- cobertura de la póliza correspondiente al pacto.

CREATE OR REPLACE FUNCTION public.handle_milestone_paid_surety_decrement()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_amortization bigint;
BEGIN
  -- Solo aplica al transicionar a 'paid'
  IF NEW.state = 'paid' AND (OLD.state IS DISTINCT FROM 'paid') THEN
    v_amortization := NEW.advance_amortization_cents;

    IF v_amortization > 0 THEN
      -- Actualizar advance_outstanding del pacto
      UPDATE public.pacts
      SET advance_outstanding_cents = greatest(0, advance_outstanding_cents - v_amortization)
      WHERE id = NEW.pact_id;

      -- Actualizar cobertura de la póliza activa (si existe)
      UPDATE public.surety_policies
      SET current_coverage_cents = greatest(0, current_coverage_cents - v_amortization),
          updated_at = now()
      WHERE pact_id = NEW.pact_id
        AND status = 'active';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_milestone_paid_surety_decrement ON public.milestones;
CREATE TRIGGER trg_milestone_paid_surety_decrement
  AFTER UPDATE OF state ON public.milestones
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_milestone_paid_surety_decrement();


-- =====================================================================
-- 8 · Migración del pacto v2.0 existente al schema v2.1
-- =====================================================================
-- Para los pacts ya creados con model_version='v2', completamos los
-- nuevos campos con valores derivados sensatos. NO los marcamos como
-- v2.1 (mantienen 'v2') porque su flujo de RPCs sigue siendo el del
-- Sprint 4 — solo aprovechamos para tener consistencia de datos.
--
-- Para forzar la migración explícita a v2.1, descomenta el bloque
-- correspondiente al final del archivo.

UPDATE public.pacts
SET
  -- Reserva implícita del 10% (lo nuevo del modelo v2.1)
  advance_reserve_pct = 10.00,
  -- Lo "entregado" al constructor en v2.0 era el balance del depósito
  -- en el momento de hacer fund_initial. Aproximamos con el balance
  -- actual menos lo consumido.
  advance_released_cents = coalesce(deposit_current_cents, 0),
  advance_outstanding_cents = coalesce(deposit_current_cents, 0)
WHERE model_version = 'v2'
  AND advance_released_cents = 0;  -- solo si aún no se había seteado


-- =====================================================================
-- 9 · BLOQUE OPCIONAL · Migración a v2.1 del pacto del usuario actual
-- =====================================================================
-- DESCOMENTA Y EDITA el display_id si quieres convertir tu pacto de
-- pruebas "Reforma Calle Galapagar" al modelo v2.1 explícito (model_version='v2.1').
--
-- BEGIN;
-- SET LOCAL session_replication_role = 'replica';
--
-- UPDATE public.pacts
-- SET
--   model_version = 'v2.1',
--   advance_reserve_pct = 10.00,
--   -- El total custodiado día 1 sería advance + reserva.
--   -- Si tu pacto tenía deposit_required_pct=30, el "adelanto total" v2.1 es 40
--   -- (30 al constructor + 10 reserva). Pero como queremos respetar el slider
--   -- original, asumimos que ese 30 era el adelanto total y desglosamos:
--   --   reserva = total * 10 / 30  ~ irreal, mejor reasignar a mano.
--   --   Recomendación: para el pacto de prueba, pon ambos pcts a su valor v2.1 ideal.
--   deposit_required_pct = 40,   -- adelanto total v2.1
--   advance_released_cents = (total_amount_cents * 30 / 100),  -- 30% al constructor
--   advance_outstanding_cents = (total_amount_cents * 30 / 100),
--   deposit_current_cents = (total_amount_cents * 10 / 100),    -- reserva custodiada
--   state = 'signed',
--   state_updated_at = now()
-- WHERE display_id = 'PS-PCT-20260514-590407';  -- ← reemplaza por el tuyo
--
-- COMMIT;


-- =====================================================================
-- 10 · Recarga del schema cache
-- =====================================================================
NOTIFY pgrst, 'reload schema';
