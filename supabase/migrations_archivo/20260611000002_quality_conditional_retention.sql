-- Reconstruida el 2026-07-13 desde supabase_migrations.schema_migrations del remoto
-- (pactstream-dev / erqglsrnknhwqhfupckf). Esta migracion YA estaba aplicada en el
-- remoto pero no versionada en el repo local; se recupera para alinear el historial.
-- Fuente: statements[] almacenados por el CLI de Supabase.

-- Migration: Quality-conditional retention (Mejora 5.5)
--
-- Condiciona la liberación de fondos retenidos a la calidad documental
-- verificada por IA. Dos niveles:
--   1. Por hito: si el score IA < umbral, se retiene un % del pago.
--   2. Por pacto: al cerrar, la reserva del 10% solo se libera si la
--      calidad media ponderada >= umbral de liberación.

-- ---------------------------------------------------------------------------
-- 1. Configuración en app_settings
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value) VALUES
  ('quality_holdback_threshold', '75'),
  ('quality_holdback_pct', '15'),
  ('quality_release_threshold', '70'),
  ('quality_grace_period_days', '14')
ON CONFLICT (key) DO NOTHING;

COMMENT ON TABLE public.app_settings IS
  'quality_holdback_threshold: score IA mínimo para liberar pago sin retención. '
  'quality_holdback_pct: % del pago retenido si score < threshold. '
  'quality_release_threshold: score medio mínimo del pacto para liberar reserva final. '
  'quality_grace_period_days: días que tiene el constructor para mejorar calidad antes de retención definitiva.';

-- ---------------------------------------------------------------------------
-- 2. Tabla quality_holdbacks — retenciones a nivel de hito
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.quality_holdbacks (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id           uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  milestone_id      uuid NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
  amount_cents      bigint NOT NULL CHECK (amount_cents > 0),
  ai_score          smallint NOT NULL CHECK (ai_score BETWEEN 0 AND 100),
  threshold_used    smallint NOT NULL,
  holdback_pct_used smallint NOT NULL,
  state             text NOT NULL DEFAULT 'held'
                      CHECK (state IN ('held', 'released', 'forfeited', 'under_review')),
  reason            text NOT NULL DEFAULT 'low_quality_score',
  released_at       timestamptz,
  released_by       uuid REFERENCES public.users(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE(milestone_id)
);

CREATE INDEX idx_quality_holdbacks_pact ON public.quality_holdbacks (pact_id, state);

ALTER TABLE quality_holdbacks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "qh_read_party" ON public.quality_holdbacks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      WHERE pp.pact_id = quality_holdbacks.pact_id
        AND pp.user_id = (
          SELECT u.id FROM public.users u
          WHERE u.auth_provider_id = auth.uid()::text
          LIMIT 1
        )
    )
  );

GRANT SELECT ON public.quality_holdbacks TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Columna en milestones para tracking de retención
-- ---------------------------------------------------------------------------
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS quality_holdback_cents bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_paid_cents bigint;

COMMENT ON COLUMN public.milestones.quality_holdback_cents IS
  'Importe retenido por baja calidad documental (IA score < umbral)';

COMMENT ON COLUMN public.milestones.net_paid_cents IS
  'Importe efectivamente pagado al constructor (amount_cents - quality_holdback_cents)';

-- ---------------------------------------------------------------------------
-- 4. Columnas en pacts para tracking de retención total
-- ---------------------------------------------------------------------------
ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS total_quality_holdback_cents bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quality_settlement_state text
    CHECK (quality_settlement_state IN (
      NULL, 'pending', 'released', 'partial_release', 'forfeited', 'under_review'
    ));

-- ---------------------------------------------------------------------------
-- 5. RPC: sf_check_quality_holdback
--    Llamada internamente al aprobar un hito. Determina si se retiene.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_check_quality_holdback(
  p_milestone_id uuid,
  p_pact_id uuid,
  p_amount_cents bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold    smallint;
  v_holdback_pct smallint;
  v_ai_score     smallint;
  v_holdback_amt bigint;
BEGIN
  -- Leer configuración
  SELECT (value)::smallint INTO v_threshold
  FROM public.app_settings WHERE key = 'quality_holdback_threshold';
  v_threshold := coalesce(v_threshold, 75);

  SELECT (value)::smallint INTO v_holdback_pct
  FROM public.app_settings WHERE key = 'quality_holdback_pct';
  v_holdback_pct := coalesce(v_holdback_pct, 15);

  -- Obtener último score IA del hito
  SELECT (ar.metadata->>'score_numeric')::smallint
  INTO v_ai_score
  FROM public.ai_runs ar
  WHERE ar.pact_id = p_pact_id
    AND ar.run_type = 'vision'
    AND ar.success = true
    AND ar.metadata->>'score_numeric' IS NOT NULL
    AND (ar.metadata->>'milestone_id') = p_milestone_id::text
  ORDER BY ar.created_at DESC
  LIMIT 1;

  -- Si no hay verificación IA, buscar en milestone_ai_verifications
  IF v_ai_score IS NULL THEN
    SELECT score INTO v_ai_score
    FROM public.milestone_ai_verifications
    WHERE milestone_id = p_milestone_id
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  -- Sin score IA → no retener (dar el beneficio de la duda)
  IF v_ai_score IS NULL THEN
    RETURN jsonb_build_object(
      'holdback', false,
      'reason', 'no_ai_score',
      'ai_score', NULL
    );
  END IF;

  -- Score >= umbral → pago completo
  IF v_ai_score >= v_threshold THEN
    RETURN jsonb_build_object(
      'holdback', false,
      'ai_score', v_ai_score,
      'threshold', v_threshold
    );
  END IF;

  -- Score < umbral → retener
  v_holdback_amt := (p_amount_cents * v_holdback_pct / 100);

  -- Registrar retención
  INSERT INTO public.quality_holdbacks (
    pact_id, milestone_id, amount_cents, ai_score,
    threshold_used, holdback_pct_used, state
  ) VALUES (
    p_pact_id, p_milestone_id, v_holdback_amt, v_ai_score,
    v_threshold, v_holdback_pct, 'held'
  )
  ON CONFLICT (milestone_id) DO UPDATE
    SET amount_cents = EXCLUDED.amount_cents,
        ai_score = EXCLUDED.ai_score,
        state = 'held';

  -- Actualizar hito
  UPDATE public.milestones
  SET quality_holdback_cents = v_holdback_amt,
      net_paid_cents = p_amount_cents - v_holdback_amt
  WHERE id = p_milestone_id;

  -- Acumular en pacto
  UPDATE public.pacts
  SET total_quality_holdback_cents = total_quality_holdback_cents + v_holdback_amt
  WHERE id = p_pact_id;

  RETURN jsonb_build_object(
    'holdback', true,
    'ai_score', v_ai_score,
    'threshold', v_threshold,
    'holdback_pct', v_holdback_pct,
    'holdback_cents', v_holdback_amt,
    'net_paid_cents', p_amount_cents - v_holdback_amt
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_check_quality_holdback TO service_role;

-- ---------------------------------------------------------------------------
-- 6. RPC: sf_pact_finalize_settlement
--    Liquidación final: libera o retiene la reserva según calidad global.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_pact_finalize_settlement(
  p_pact_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid         uuid;
  v_user_id          uuid;
  v_user_role        pact_party_role;
  v_pact_state       text;
  v_release_threshold smallint;
  v_avg_quality      numeric;
  v_total_holdback   bigint;
  v_reserve_cents    bigint;
  v_settlement       text;
  v_holdback_row     record;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- Solo promotor puede iniciar liquidación
  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;

  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede iniciar la liquidación final';
  END IF;

  -- Solo pactos completados
  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state != 'completed' THEN
    RAISE EXCEPTION 'El pacto debe estar completado para liquidar (estado actual: %)', v_pact_state;
  END IF;

  -- Leer umbral de liberación
  SELECT (value)::smallint INTO v_release_threshold
  FROM public.app_settings WHERE key = 'quality_release_threshold';
  v_release_threshold := coalesce(v_release_threshold, 70);

  -- Calcular calidad media ponderada del pacto
  SELECT
    CASE WHEN sum(m.amount_cents) > 0 THEN
      sum(
        coalesce(
          (SELECT score FROM public.milestone_ai_verifications
           WHERE milestone_id = m.id
           ORDER BY created_at DESC LIMIT 1),
          75  -- neutral si no hay verificación
        )::numeric * m.amount_cents
      ) / sum(m.amount_cents)
    ELSE 75
    END
  INTO v_avg_quality
  FROM public.milestones m
  WHERE m.pact_id = p_pact_id
    AND m.deleted_at IS NULL
    AND m.state = 'paid';

  -- Total retenido
  SELECT coalesce(sum(amount_cents), 0)
  INTO v_total_holdback
  FROM public.quality_holdbacks
  WHERE pact_id = p_pact_id AND state = 'held';

  -- Reserva del pacto
  SELECT coalesce(
    (total_amount_cents * advance_reserve_pct / 100)::bigint,
    0
  )
  INTO v_reserve_cents
  FROM public.pacts WHERE id = p_pact_id;

  -- Decisión
  IF v_avg_quality >= v_release_threshold THEN
    -- Calidad OK → liberar todo
    v_settlement := 'released';

    -- Liberar holdbacks individuales
    FOR v_holdback_row IN
      SELECT id, milestone_id, amount_cents
      FROM public.quality_holdbacks
      WHERE pact_id = p_pact_id AND state = 'held'
    LOOP
      UPDATE public.quality_holdbacks
      SET state = 'released', released_at = now(), released_by = v_user_id
      WHERE id = v_holdback_row.id;

      UPDATE public.milestones
      SET quality_holdback_cents = 0,
          net_paid_cents = amount_cents
      WHERE id = v_holdback_row.milestone_id;
    END LOOP;

    -- Marcar pacto
    UPDATE public.pacts
    SET quality_settlement_state = 'released',
        total_quality_holdback_cents = 0,
        state = 'closed'
    WHERE id = p_pact_id;

  ELSE
    -- Calidad insuficiente → retener reserva, holdbacks quedan retenidos
    v_settlement := 'under_review';

    UPDATE public.quality_holdbacks
    SET state = 'under_review'
    WHERE pact_id = p_pact_id AND state = 'held';

    UPDATE public.pacts
    SET quality_settlement_state = 'under_review'
    WHERE id = p_pact_id;
  END IF;

  -- Evento
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'quality_settlement',
    jsonb_build_object(
      'settlement', v_settlement,
      'avg_quality_score', round(v_avg_quality, 1),
      'release_threshold', v_release_threshold,
      'total_holdback_cents', v_total_holdback,
      'reserve_cents', v_reserve_cents,
      'holdbacks_count', (SELECT count(*) FROM public.quality_holdbacks WHERE pact_id = p_pact_id)
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'quality_settlement', 'pact', p_pact_id,
    jsonb_build_object('settlement', v_settlement, 'avg_quality', round(v_avg_quality, 1)));

  RETURN jsonb_build_object(
    'settlement', v_settlement,
    'avg_quality_score', round(v_avg_quality, 1),
    'release_threshold', v_release_threshold,
    'total_holdback_released_cents', CASE WHEN v_settlement = 'released' THEN v_total_holdback ELSE 0 END,
    'reserve_cents', v_reserve_cents
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_pact_finalize_settlement TO authenticated;

-- ---------------------------------------------------------------------------
-- 7. Modificar trigger de milestone_paid para incluir quality check
-- ---------------------------------------------------------------------------
-- Creamos una función wrapper que se ejecuta DESPUÉS de que un hito pase a
-- 'paid'. No modifica el trigger existente, se añade como trigger adicional.

CREATE OR REPLACE FUNCTION public.fn_milestone_quality_check()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NEW.state = 'paid' AND (OLD.state IS DISTINCT FROM 'paid') THEN
    SELECT public.sf_check_quality_holdback(NEW.id, NEW.pact_id, NEW.amount_cents)
    INTO v_result;

    -- Si hay retención, registrar evento
    IF (v_result->>'holdback')::boolean THEN
      INSERT INTO public.pact_events (pact_id, event_type, payload)
      VALUES (NEW.pact_id, 'quality_holdback_applied',
        jsonb_build_object(
          'milestone_id', NEW.id,
          'ai_score', v_result->>'ai_score',
          'holdback_cents', v_result->>'holdback_cents',
          'net_paid_cents', v_result->>'net_paid_cents'
        ));

      -- Recalcular salud del pacto
      PERFORM public.sf_recalc_pact_health(NEW.pact_id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_milestone_quality_check
  AFTER UPDATE ON public.milestones
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_milestone_quality_check();
