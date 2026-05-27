-- =====================================================================
-- Sprint 8 · Migration 0032
-- Motor de Scoring: pact_health_scores + user_reputations
-- =====================================================================
-- Dos RPCs principales:
--   sf_recalc_pact_health(pact_id)  → snapshot en pact_health_scores
--   sf_recalc_user_reputation(user_id) → snapshot en user_reputations
--
-- Trigger automático en milestones: recalcula el health del pacto
-- cuando un hito cambia de estado.
--
-- Fórmulas:
--   Pact Health (0-100):
--     milestone_compliance_pct (30%)  = % hitos paid / total hitos
--     evidence_validity_pct    (25%)  = % hitos con evidencias subidas
--     validation_speed_pct     (20%)  = % hitos validados en < 7 días desde ready_for_review
--     no_disputes_pct          (15%)  = 100 si 0 disputas, -20 por cada disputa
--     ia_evidence_score        (10%)  = media de scores de ai_runs tipo vision
--
--   User Reputation (0-100) — varía por rol:
--     Promotor:  payment_speed (40%) + no_disputes (35%) + completion (25%)
--     Constructor: completion (40%) + evidence_quality (35%) + no_disputes (25%)
--     Técnico:   validation_speed (50%) + sign_rate (30%) + no_disputes (20%)
--
--   Tier:
--     0-39  → bronce
--     40-59 → plata
--     60-74 → oro
--     75-89 → platino
--     90+   → elite
-- =====================================================================


-- =====================================================================
-- 0 · Schema privado (no existe por defecto en Supabase)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS private;

-- =====================================================================
-- 1 · Helper privado: tier desde score
-- =====================================================================

CREATE OR REPLACE FUNCTION private.score_to_tier(p_score smallint)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_score >= 90 THEN 'elite'
    WHEN p_score >= 75 THEN 'platino'
    WHEN p_score >= 60 THEN 'oro'
    WHEN p_score >= 40 THEN 'plata'
    ELSE 'bronce'
  END;
$$;


-- =====================================================================
-- 2 · sf_recalc_pact_health
-- =====================================================================

CREATE OR REPLACE FUNCTION public.sf_recalc_pact_health(
  p_pact_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_milestones    int;
  v_paid_milestones     int;
  v_with_evidences      int;
  v_fast_validations    int;
  v_reviewable          int;
  v_disputes            int;
  v_avg_ia_score        numeric;

  v_compliance_pct      numeric;
  v_evidence_pct        numeric;
  v_speed_pct           numeric;
  v_no_disputes_pct     numeric;
  v_ia_score            numeric;

  v_final_score         smallint;
  v_snapshot_id         uuid;
BEGIN
  -- Totales de hitos
  SELECT
    count(*),
    count(*) FILTER (WHERE state = 'paid')
  INTO v_total_milestones, v_paid_milestones
  FROM public.milestones
  WHERE pact_id = p_pact_id
    AND deleted_at IS NULL;

  IF v_total_milestones = 0 THEN
    RETURN jsonb_build_object('score', 0, 'error', 'no_milestones');
  END IF;

  -- Hitos con al menos 1 evidencia
  SELECT count(DISTINCT m.id)
  INTO v_with_evidences
  FROM public.milestones m
  WHERE m.pact_id = p_pact_id
    AND m.deleted_at IS NULL
    AND m.state IN ('ready_for_review', 'approved', 'paid', 'disputed')
    AND EXISTS (
      SELECT 1 FROM public.milestone_evidences me
      WHERE me.milestone_id = m.id
    );

  -- Hitos revisables (los que tienen sentido medir evidencias)
  SELECT count(*)
  INTO v_reviewable
  FROM public.milestones
  WHERE pact_id = p_pact_id
    AND deleted_at IS NULL
    AND state IN ('ready_for_review', 'approved', 'paid', 'disputed');

  -- Hitos validados rápido (< 7 días desde ready_for_review → paid)
  -- Aproximamos con la transición de estado más reciente
  SELECT count(*)
  INTO v_fast_validations
  FROM public.milestones m
  JOIN public.milestone_state_transitions mst ON mst.milestone_id = m.id
    AND mst.to_state = 'paid'
  JOIN public.milestone_state_transitions mst2 ON mst2.milestone_id = m.id
    AND mst2.to_state = 'ready_for_review'
  WHERE m.pact_id = p_pact_id
    AND m.state = 'paid'
    AND m.deleted_at IS NULL
    AND (mst.created_at - mst2.created_at) < interval '7 days';

  -- Disputas abiertas en el pacto
  SELECT count(*)
  INTO v_disputes
  FROM public.disputes
  WHERE pact_id = p_pact_id
    AND state NOT IN ('resolved', 'closed');

  -- Media de scores IA (vision runs con éxito)
  SELECT avg((ar.metadata->>'score_numeric')::numeric)
  INTO v_avg_ia_score
  FROM public.ai_runs ar
  WHERE ar.pact_id = p_pact_id
    AND ar.run_type = 'vision'
    AND ar.success = true
    AND ar.metadata->>'score_numeric' IS NOT NULL;

  -- ---------------------------------------------------------------
  -- Calcular componentes
  -- ---------------------------------------------------------------

  -- Compliance: % hitos paid vs total
  v_compliance_pct := round((v_paid_milestones::numeric / v_total_milestones) * 100, 2);

  -- Evidencia: % hitos revisables con evidencias (si no hay revisables → 100)
  v_evidence_pct := CASE
    WHEN v_reviewable = 0 THEN 100
    ELSE round((v_with_evidences::numeric / v_reviewable) * 100, 2)
  END;

  -- Velocidad: % hitos paid validados rápido (si no hay paid → 100)
  v_speed_pct := CASE
    WHEN v_paid_milestones = 0 THEN 100
    ELSE round((v_fast_validations::numeric / v_paid_milestones) * 100, 2)
  END;

  -- Sin disputas: empieza en 100, -20 por cada disputa activa (mínimo 0)
  v_no_disputes_pct := greatest(0, 100 - (v_disputes * 20));

  -- Score IA: si no hay runs usar 75 como neutral
  v_ia_score := coalesce(v_avg_ia_score, 75);

  -- Score final ponderado
  v_final_score := round(
    v_compliance_pct  * 0.30 +
    v_evidence_pct    * 0.25 +
    v_speed_pct       * 0.20 +
    v_no_disputes_pct * 0.15 +
    v_ia_score        * 0.10
  )::smallint;

  -- Clamp 0-100
  v_final_score := greatest(0, least(100, v_final_score));

  -- Insertar snapshot
  INSERT INTO public.pact_health_scores (
    pact_id,
    score,
    milestone_compliance_pct,
    evidence_validity_pct,
    validation_speed_pct,
    no_disputes_pct,
    ia_evidence_score,
    calculated_at
  ) VALUES (
    p_pact_id,
    v_final_score,
    v_compliance_pct,
    v_evidence_pct,
    v_speed_pct,
    v_no_disputes_pct,
    v_ia_score,
    now()
  )
  ON CONFLICT (pact_id, calculated_at) DO UPDATE
    SET score                   = EXCLUDED.score,
        milestone_compliance_pct = EXCLUDED.milestone_compliance_pct,
        evidence_validity_pct    = EXCLUDED.evidence_validity_pct,
        validation_speed_pct     = EXCLUDED.validation_speed_pct,
        no_disputes_pct          = EXCLUDED.no_disputes_pct,
        ia_evidence_score        = EXCLUDED.ia_evidence_score
  RETURNING id INTO v_snapshot_id;

  RETURN jsonb_build_object(
    'snapshot_id',           v_snapshot_id,
    'score',                 v_final_score,
    'milestone_compliance',  v_compliance_pct,
    'evidence_validity',     v_evidence_pct,
    'validation_speed',      v_speed_pct,
    'no_disputes',           v_no_disputes_pct,
    'ia_score',              v_ia_score
  );
END;
$$;

COMMENT ON FUNCTION public.sf_recalc_pact_health IS
  'Sprint 8 · Genera un snapshot de salud del pacto en pact_health_scores. '
  'Llámalo tras cualquier cambio de estado de un hito. Coste: O(n hitos).';

GRANT EXECUTE ON FUNCTION public.sf_recalc_pact_health TO authenticated, service_role;


-- =====================================================================
-- 3 · sf_recalc_user_reputation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.sf_recalc_user_reputation(
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_role           user_role;
  v_pacts_total         int;
  v_pacts_completed     int;
  v_pacts_disputed      int;

  -- Promotor
  v_payment_speed_pct   numeric;
  -- Constructor
  v_evidence_quality_pct numeric;
  -- Técnico
  v_sign_rate_pct       numeric;
  v_val_speed_pct       numeric;

  v_final_score         smallint;
  v_tier                text;
  v_components          jsonb;
  v_snapshot_id         uuid;
BEGIN
  -- Rol principal del usuario
  SELECT primary_role INTO v_user_role
  FROM public.users
  WHERE id = p_user_id AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'user_not_found');
  END IF;

  -- Estadísticas base de participación en pactos
  SELECT
    count(DISTINCT pp.pact_id),
    count(DISTINCT pp.pact_id) FILTER (
      WHERE NOT EXISTS (
        SELECT 1 FROM public.milestones m
        WHERE m.pact_id = pp.pact_id
          AND m.state NOT IN ('paid', 'cancelled')
          AND m.deleted_at IS NULL
      )
      AND EXISTS (
        SELECT 1 FROM public.milestones m2
        WHERE m2.pact_id = pp.pact_id AND m2.state = 'paid'
      )
    ),
    count(DISTINCT d.pact_id)
  INTO v_pacts_total, v_pacts_completed, v_pacts_disputed
  FROM public.pact_parties pp
  LEFT JOIN public.disputes d ON d.pact_id = pp.pact_id
    AND (d.raised_by_user_id = p_user_id OR d.against_user_id = p_user_id)
  WHERE pp.user_id = p_user_id;

  -- ---------------------------------------------------------------
  -- Score por rol
  -- ---------------------------------------------------------------

  IF v_user_role = 'promotor' THEN
    -- Velocidad de pago: % hitos en which the promotor no retrasó > 3 días
    -- Aproximamos con % hitos paid sobre total hitos en pactos del promotor
    SELECT
      CASE WHEN count(*) = 0 THEN 100
      ELSE round(
        count(*) FILTER (WHERE m.state = 'paid')::numeric / count(*) * 100, 2
      ) END
    INTO v_payment_speed_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id AND m.deleted_at IS NULL
    WHERE pp.user_id = p_user_id AND pp.role = 'promotor';

    -- Tasa sin disputas
    v_final_score := round(
      v_payment_speed_pct                                           * 0.40 +
      greatest(0, 100 - (v_pacts_disputed * 25))                   * 0.35 +
      (CASE WHEN v_pacts_total = 0 THEN 75
       ELSE v_pacts_completed::numeric / v_pacts_total * 100 END)  * 0.25
    )::smallint;

    v_components := jsonb_build_object(
      'payment_speed_pct',    v_payment_speed_pct,
      'no_disputes_pct',      greatest(0, 100 - v_pacts_disputed * 25),
      'completion_pct',       CASE WHEN v_pacts_total = 0 THEN 75
                              ELSE round(v_pacts_completed::numeric / v_pacts_total * 100, 2) END
    );

  ELSIF v_user_role = 'constructor' THEN
    -- Calidad de evidencias: % runs vision con score >= 75
    SELECT
      CASE WHEN count(*) = 0 THEN 75
      ELSE round(
        count(*) FILTER (
          WHERE (ar.metadata->>'score_numeric')::numeric >= 75
        )::numeric / count(*) * 100, 2
      ) END
    INTO v_evidence_quality_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id AND m.deleted_at IS NULL
    JOIN public.ai_runs ar ON ar.pact_id = pp.pact_id
      AND ar.run_type = 'vision' AND ar.success = true
      AND ar.metadata->>'score_numeric' IS NOT NULL
    WHERE pp.user_id = p_user_id AND pp.role = 'constructor';

    v_final_score := round(
      (CASE WHEN v_pacts_total = 0 THEN 75
       ELSE v_pacts_completed::numeric / v_pacts_total * 100 END)  * 0.40 +
      v_evidence_quality_pct                                        * 0.35 +
      greatest(0, 100 - v_pacts_disputed * 25)                     * 0.25
    )::smallint;

    v_components := jsonb_build_object(
      'completion_pct',         CASE WHEN v_pacts_total = 0 THEN 75
                                ELSE round(v_pacts_completed::numeric / v_pacts_total * 100, 2) END,
      'evidence_quality_pct',   v_evidence_quality_pct,
      'no_disputes_pct',        greatest(0, 100 - v_pacts_disputed * 25)
    );

  ELSE -- tecnico
    -- Velocidad de validación: % hitos donde validó en < 3 días
    SELECT
      CASE WHEN count(*) = 0 THEN 100
      ELSE round(
        count(*) FILTER (
          WHERE (mst_paid.created_at - mst_rfr.created_at) < interval '3 days'
        )::numeric / count(*) * 100, 2
      ) END
    INTO v_val_speed_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id
      AND m.state = 'paid' AND m.deleted_at IS NULL
    JOIN public.milestone_state_transitions mst_rfr ON mst_rfr.milestone_id = m.id
      AND mst_rfr.to_state = 'ready_for_review'
    JOIN public.milestone_state_transitions mst_paid ON mst_paid.milestone_id = m.id
      AND mst_paid.to_state = 'paid'
    WHERE pp.user_id = p_user_id AND pp.role = 'tecnico';

    -- Tasa de firma: % pactos donde firmó (accepted_at no nulo)
    SELECT
      CASE WHEN count(*) = 0 THEN 100
      ELSE round(
        count(*) FILTER (WHERE pp2.signed_at IS NOT NULL)::numeric / count(*) * 100, 2
      ) END
    INTO v_sign_rate_pct
    FROM public.pact_parties pp2
    WHERE pp2.user_id = p_user_id AND pp2.role = 'tecnico';

    v_final_score := round(
      coalesce(v_val_speed_pct, 100)                                * 0.50 +
      coalesce(v_sign_rate_pct, 100)                                * 0.30 +
      greatest(0, 100 - v_pacts_disputed * 25)                     * 0.20
    )::smallint;

    v_components := jsonb_build_object(
      'validation_speed_pct',   coalesce(v_val_speed_pct, 100),
      'sign_rate_pct',          coalesce(v_sign_rate_pct, 100),
      'no_disputes_pct',        greatest(0, 100 - v_pacts_disputed * 25)
    );
  END IF;

  -- Clamp y tier
  v_final_score := greatest(0, least(100, v_final_score));
  v_tier        := private.score_to_tier(v_final_score);

  -- Insertar snapshot
  INSERT INTO public.user_reputations (
    user_id, role, score, tier, components,
    pacts_total, pacts_completed, pacts_disputed,
    calculated_at
  ) VALUES (
    p_user_id, v_user_role, v_final_score, v_tier, v_components,
    v_pacts_total, v_pacts_completed, v_pacts_disputed,
    now()
  )
  RETURNING id INTO v_snapshot_id;

  RETURN jsonb_build_object(
    'snapshot_id',    v_snapshot_id,
    'role',           v_user_role,
    'score',          v_final_score,
    'tier',           v_tier,
    'components',     v_components,
    'pacts_total',    v_pacts_total,
    'pacts_completed', v_pacts_completed,
    'pacts_disputed', v_pacts_disputed
  );
END;
$$;

COMMENT ON FUNCTION public.sf_recalc_user_reputation IS
  'Sprint 8 · Genera un snapshot de reputación del usuario en user_reputations. '
  'Llámalo tras completar un pacto o resolver una disputa.';

GRANT EXECUTE ON FUNCTION public.sf_recalc_user_reputation TO authenticated, service_role;


-- =====================================================================
-- 4 · RPC de lectura: get_pact_health (último snapshot)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_pact_health(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row pact_health_scores;
BEGIN
  -- Verificar pertenencia al pacto
  IF NOT EXISTS (
    SELECT 1 FROM public.pact_parties pp
    JOIN public.users u ON u.id = pp.user_id
    WHERE pp.pact_id = p_pact_id
      AND u.auth_provider_id = auth.uid()::text
      AND u.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_row
  FROM public.pact_health_scores
  WHERE pact_id = p_pact_id
  ORDER BY calculated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- Si no hay snapshot, calcular uno en tiempo real
    PERFORM public.sf_recalc_pact_health(p_pact_id);
    SELECT * INTO v_row
    FROM public.pact_health_scores
    WHERE pact_id = p_pact_id
    ORDER BY calculated_at DESC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'id',                      v_row.id,
    'pact_id',                 v_row.pact_id,
    'score',                   v_row.score,
    'milestone_compliance_pct', v_row.milestone_compliance_pct,
    'evidence_validity_pct',   v_row.evidence_validity_pct,
    'validation_speed_pct',    v_row.validation_speed_pct,
    'no_disputes_pct',         v_row.no_disputes_pct,
    'ia_evidence_score',       v_row.ia_evidence_score,
    'calculated_at',           v_row.calculated_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pact_health TO authenticated;


-- =====================================================================
-- 5 · RPC de lectura: get_user_reputation (último snapshot)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_user_reputation(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row user_reputations;
BEGIN
  SELECT * INTO v_row
  FROM public.user_reputations
  WHERE user_id = p_user_id
  ORDER BY calculated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    PERFORM public.sf_recalc_user_reputation(p_user_id);
    SELECT * INTO v_row
    FROM public.user_reputations
    WHERE user_id = p_user_id
    ORDER BY calculated_at DESC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'id',             v_row.id,
    'user_id',        v_row.user_id,
    'role',           v_row.role,
    'score',          v_row.score,
    'tier',           v_row.tier,
    'components',     v_row.components,
    'pacts_total',    v_row.pacts_total,
    'pacts_completed', v_row.pacts_completed,
    'pacts_disputed', v_row.pacts_disputed,
    'calculated_at',  v_row.calculated_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_reputation TO authenticated;


-- =====================================================================
-- 6 · Trigger: recalcular health del pacto al cambiar estado de hito
-- =====================================================================

CREATE OR REPLACE FUNCTION public.handle_milestone_state_recalc_health()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Solo en cambios de estado real
  IF NEW.state IS DISTINCT FROM OLD.state THEN
    PERFORM public.sf_recalc_pact_health(NEW.pact_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_milestone_state_recalc_health ON public.milestones;
CREATE TRIGGER trg_milestone_state_recalc_health
  AFTER UPDATE OF state ON public.milestones
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_milestone_state_recalc_health();


-- =====================================================================
-- 7 · RLS: get_pact_health y get_user_reputation son SECURITY DEFINER
--     (la autorización está dentro de la función).
--     Las tablas base ya tienen RLS desde initial_schema.
-- =====================================================================

-- Política de lectura para user_reputations: el propio usuario y
-- las partes de un pacto común pueden ver la reputación.
DROP POLICY IF EXISTS user_rep_select ON public.user_reputations;
CREATE POLICY user_rep_select ON public.user_reputations
  FOR SELECT TO authenticated
  USING (
    -- Propio usuario
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = user_reputations.user_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
    OR
    -- Comparte pacto con el usuario autenticado
    EXISTS (
      SELECT 1 FROM public.pact_parties pp1
      JOIN public.pact_parties pp2 ON pp2.pact_id = pp1.pact_id
      JOIN public.users u ON u.id = pp1.user_id
      WHERE pp2.user_id = user_reputations.user_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
  );

DROP POLICY IF EXISTS pact_health_select ON public.pact_health_scores;
CREATE POLICY pact_health_select ON public.pact_health_scores
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = pact_health_scores.pact_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
  );


-- =====================================================================
-- 8 · Seed de reputaciones para usuarios demo
-- =====================================================================

DO $demo$
DECLARE
  v_marta_id  constant uuid := '00000000-0000-0000-0000-00000000aa01';
  v_jorge_id  constant uuid := '00000000-0000-0000-0000-00000000bb02';
  v_perez_id  constant uuid := '00000000-0000-0000-0000-00000000cc03';
  v_pact_id   constant uuid := '00000000-0000-0000-0000-00000000dd01';
BEGIN
  -- Health score del pacto demo (refleja 2 hitos paid, 1 en review, 3 pending)
  INSERT INTO public.pact_health_scores (
    pact_id, score,
    milestone_compliance_pct, evidence_validity_pct,
    validation_speed_pct, no_disputes_pct, ia_evidence_score,
    calculated_at
  ) VALUES (
    v_pact_id, 83,
    33.33,   -- 2/6 hitos pagados
    100.00,  -- evidencias subidas en los hitos revisados
    100.00,  -- validados en plazo
    100.00,  -- sin disputas
    88.00,   -- ia score medio (fixtures)
    now()
  )
  ON CONFLICT (pact_id, calculated_at) DO NOTHING;

  -- Reputación Marta (promotor) — pagos puntuales, sin disputas
  INSERT INTO public.user_reputations (
    user_id, role, score, tier,
    components, pacts_total, pacts_completed, pacts_disputed,
    calculated_at
  ) VALUES (
    v_marta_id, 'promotor', 88, 'platino',
    '{"payment_speed_pct": 92, "no_disputes_pct": 100, "completion_pct": 75}'::jsonb,
    3, 2, 0, now()
  )
  ON CONFLICT DO NOTHING;

  -- Reputación Jorge (técnico) — validaciones rápidas, firma 100%
  INSERT INTO public.user_reputations (
    user_id, role, score, tier,
    components, pacts_total, pacts_completed, pacts_disputed,
    calculated_at
  ) VALUES (
    v_jorge_id, 'tecnico', 94, 'elite',
    '{"validation_speed_pct": 96, "sign_rate_pct": 100, "no_disputes_pct": 100}'::jsonb,
    8, 7, 0, now()
  )
  ON CONFLICT DO NOTHING;

  -- Reputación Construcciones Pérez (constructor) — buen histórico
  INSERT INTO public.user_reputations (
    user_id, role, score, tier,
    components, pacts_total, pacts_completed, pacts_disputed,
    calculated_at
  ) VALUES (
    v_perez_id, 'constructor', 79, 'platino',
    '{"completion_pct": 85, "evidence_quality_pct": 82, "no_disputes_pct": 75}'::jsonb,
    12, 10, 1, now()
  )
  ON CONFLICT DO NOTHING;

END $demo$;


-- =====================================================================
-- 9 · Schema cache
-- =====================================================================
NOTIFY pgrst, 'reload schema';
