-- Reconstruida el 2026-07-13 desde supabase_migrations.schema_migrations del remoto
-- (pactstream-dev / erqglsrnknhwqhfupckf). Esta migracion YA estaba aplicada en el
-- remoto pero no versionada en el repo local; se recupera para alinear el historial.
-- Fuente: statements[] almacenados por el CLI de Supabase.

-- Migration: Contradictorias → Ampliación escrow (Mejora 4.3)
--
-- Cuando se abre una disputa (contradictoria) sobre un hito, el sistema
-- amplía automáticamente el escrow del pacto para cubrir el coste potencial
-- del peritaje y la resolución. El promotor debe depositar fondos adicionales
-- que quedan custodiados hasta la resolución.
--
-- Flujo:
--   1. Hito pasa a 'disputed' → trigger crea un registro en dispute_escrows
--   2. Se calcula el importe de ampliación (% configurable del hito disputado)
--   3. El promotor recibe notificación para depositar la ampliación
--   4. Al resolver la disputa, los fondos se liberan según el resultado

-- ---------------------------------------------------------------------------
-- 1. Configuración
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value) VALUES
  ('dispute_escrow_pct', '10'),
  ('dispute_escrow_min_cents', '50000'),
  ('dispute_escrow_max_cents', '500000')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Tabla dispute_escrows — ampliaciones de escrow por disputa
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dispute_escrows (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id           uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  milestone_id      uuid NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
  dispute_amount_cents bigint NOT NULL,
  escrow_amount_cents bigint NOT NULL CHECK (escrow_amount_cents > 0),
  escrow_pct_used   numeric(5,2) NOT NULL,
  state             text NOT NULL DEFAULT 'pending_deposit'
    CHECK (state IN (
      'pending_deposit',
      'deposited',
      'released_to_promotor',
      'released_to_constructor',
      'split',
      'expired'
    )),
  deposited_at      timestamptz,
  resolved_at       timestamptz,
  resolution_note   text,
  released_to_promotor_cents  bigint DEFAULT 0,
  released_to_constructor_cents bigint DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE(milestone_id)
);

CREATE INDEX idx_dispute_escrows_pact ON public.dispute_escrows (pact_id, state);

ALTER TABLE dispute_escrows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "de_read_party" ON public.dispute_escrows FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      WHERE pp.pact_id = dispute_escrows.pact_id
        AND pp.user_id = (
          SELECT u.id FROM public.users u
          WHERE u.auth_provider_id = auth.uid()::text
          LIMIT 1
        )
    )
  );

GRANT SELECT ON public.dispute_escrows TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Trigger: auto-crear escrow al disputar un hito
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_dispute_escrow_auto_create()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pact_id uuid;
  v_amount_cents bigint;
  v_escrow_pct numeric;
  v_escrow_min bigint;
  v_escrow_max bigint;
  v_escrow_cents bigint;
BEGIN
  IF NEW.state = 'disputed' AND (OLD.state IS DISTINCT FROM 'disputed') THEN
    v_pact_id := NEW.pact_id;
    v_amount_cents := NEW.amount_cents;

    -- Leer configuración
    SELECT coalesce((SELECT (value)::numeric FROM public.app_settings
      WHERE key = 'dispute_escrow_pct'), 10)
    INTO v_escrow_pct;

    SELECT coalesce((SELECT (value)::bigint FROM public.app_settings
      WHERE key = 'dispute_escrow_min_cents'), 50000)
    INTO v_escrow_min;

    SELECT coalesce((SELECT (value)::bigint FROM public.app_settings
      WHERE key = 'dispute_escrow_max_cents'), 500000)
    INTO v_escrow_max;

    -- Calcular importe
    v_escrow_cents := greatest(
      v_escrow_min,
      least(
        v_escrow_max,
        (v_amount_cents * v_escrow_pct / 100)::bigint
      )
    );

    -- Crear registro (idempotente con ON CONFLICT)
    INSERT INTO public.dispute_escrows (
      pact_id, milestone_id, dispute_amount_cents,
      escrow_amount_cents, escrow_pct_used, state
    ) VALUES (
      v_pact_id, NEW.id, v_amount_cents,
      v_escrow_cents, v_escrow_pct, 'pending_deposit'
    )
    ON CONFLICT (milestone_id) DO UPDATE
      SET state = 'pending_deposit',
          escrow_amount_cents = EXCLUDED.escrow_amount_cents,
          dispute_amount_cents = EXCLUDED.dispute_amount_cents;

    -- Evento
    INSERT INTO public.pact_events (pact_id, event_type, payload)
    VALUES (v_pact_id, 'dispute_escrow_required',
      jsonb_build_object(
        'milestone_id', NEW.id,
        'dispute_amount_cents', v_amount_cents,
        'escrow_required_cents', v_escrow_cents,
        'escrow_pct', v_escrow_pct
      ));
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_dispute_escrow_auto
  AFTER UPDATE ON public.milestones
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_dispute_escrow_auto_create();

-- ---------------------------------------------------------------------------
-- 4. RPC: sf_deposit_dispute_escrow
--    Promotor deposita la ampliación del escrow por disputa.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_deposit_dispute_escrow(
  p_milestone_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_escrow record;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT de.*, m.pact_id
  INTO v_escrow
  FROM public.dispute_escrows de
  JOIN public.milestones m ON m.id = de.milestone_id
  WHERE de.milestone_id = p_milestone_id;

  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'No hay escrow de disputa para este hito';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_escrow.pact_id AND user_id = v_user_id;

  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede depositar el escrow de disputa';
  END IF;

  IF v_escrow.state != 'pending_deposit' THEN
    RAISE EXCEPTION 'El escrow ya fue depositado (estado: %)', v_escrow.state;
  END IF;

  -- Registrar depósito (mock — en producción va vía Mangopay)
  UPDATE public.dispute_escrows
  SET state = 'deposited', deposited_at = now()
  WHERE id = v_escrow.id;

  -- Incrementar el depósito del pacto
  UPDATE public.pacts
  SET deposit_current_cents = deposit_current_cents + v_escrow.escrow_amount_cents
  WHERE id = v_escrow.pact_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_escrow.pact_id, 'dispute_escrow_deposited',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'escrow_cents', v_escrow.escrow_amount_cents
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'dispute_escrow_deposited', 'dispute_escrow', v_escrow.id,
    jsonb_build_object('amount_cents', v_escrow.escrow_amount_cents));

  RETURN jsonb_build_object(
    'success', true,
    'escrow_cents', v_escrow.escrow_amount_cents,
    'state', 'deposited'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_deposit_dispute_escrow TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC: sf_resolve_dispute_escrow
--    Resuelve la disputa y distribuye los fondos del escrow.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_resolve_dispute_escrow(
  p_milestone_id uuid,
  p_resolution text,
  p_promotor_pct numeric DEFAULT 100,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_escrow record;
  v_to_promotor bigint;
  v_to_constructor bigint;
  v_final_state text;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT de.*
  INTO v_escrow
  FROM public.dispute_escrows de
  WHERE de.milestone_id = p_milestone_id;

  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'No hay escrow de disputa para este hito';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_escrow.pact_id AND user_id = v_user_id;

  -- Solo técnico o promotor pueden resolver
  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o promotor pueden resolver la disputa';
  END IF;

  IF v_escrow.state NOT IN ('deposited', 'pending_deposit') THEN
    RAISE EXCEPTION 'El escrow ya fue resuelto (estado: %)', v_escrow.state;
  END IF;

  IF p_resolution NOT IN ('favor_promotor', 'favor_constructor', 'split') THEN
    RAISE EXCEPTION 'Resolución inválida: %. Usar favor_promotor | favor_constructor | split', p_resolution;
  END IF;

  IF p_promotor_pct < 0 OR p_promotor_pct > 100 THEN
    RAISE EXCEPTION 'p_promotor_pct debe estar entre 0 y 100';
  END IF;

  -- Distribuir fondos
  v_to_promotor := (v_escrow.escrow_amount_cents * p_promotor_pct / 100)::bigint;
  v_to_constructor := v_escrow.escrow_amount_cents - v_to_promotor;

  IF p_resolution = 'favor_promotor' THEN
    v_final_state := 'released_to_promotor';
    v_to_promotor := v_escrow.escrow_amount_cents;
    v_to_constructor := 0;
  ELSIF p_resolution = 'favor_constructor' THEN
    v_final_state := 'released_to_constructor';
    v_to_promotor := 0;
    v_to_constructor := v_escrow.escrow_amount_cents;
  ELSE
    v_final_state := 'split';
  END IF;

  UPDATE public.dispute_escrows
  SET state = v_final_state,
      resolved_at = now(),
      resolution_note = p_note,
      released_to_promotor_cents = v_to_promotor,
      released_to_constructor_cents = v_to_constructor
  WHERE id = v_escrow.id;

  -- Descontar del depósito del pacto
  UPDATE public.pacts
  SET deposit_current_cents = greatest(0, deposit_current_cents - v_escrow.escrow_amount_cents)
  WHERE id = v_escrow.pact_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_escrow.pact_id, 'dispute_escrow_resolved',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'resolution', p_resolution,
      'to_promotor_cents', v_to_promotor,
      'to_constructor_cents', v_to_constructor,
      'note', p_note
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'dispute_escrow_resolved', 'dispute_escrow', v_escrow.id,
    jsonb_build_object('resolution', p_resolution, 'promotor_pct', p_promotor_pct));

  RETURN jsonb_build_object(
    'success', true,
    'resolution', p_resolution,
    'to_promotor_cents', v_to_promotor,
    'to_constructor_cents', v_to_constructor,
    'state', v_final_state
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_resolve_dispute_escrow TO authenticated;
