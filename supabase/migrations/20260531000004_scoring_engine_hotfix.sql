-- =====================================================================
-- Sprint 8 · Hotfix: Scoring engine column mismatches + VOLATILE
-- =====================================================================
-- Fixes 6 bugs in scoring engine functions:
--
--   1. milestones.deleted_at does not exist → removed all references
--   2. disputes.raised_by_user_id / against_user_id do not exist
--      → count disputes via pact_parties join instead
--   3. milestone_state_transitions.created_at → occurred_at
--   4. milestone state 'approved' → 'approved_by_tech'
--   5. milestone state 'cancelled' does not exist → removed
--   6. get_pact_health / get_user_reputation marked STABLE but do
--      INSERT internally → changed to VOLATILE (PostgREST runs
--      STABLE functions in read-only transactions)
-- =====================================================================


-- =====================================================================
-- 1 · Fix sf_recalc_pact_health
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
  WHERE pact_id = p_pact_id;

  IF v_total_milestones = 0 THEN
    RETURN jsonb_build_object('score', 0, 'error', 'no_milestones');
  END IF;

  -- Hitos con al menos 1 evidencia (estados revisables)
  SELECT count(DISTINCT m.id)
  INTO v_with_evidences
  FROM public.milestones m
  WHERE m.pact_id = p_pact_id
    AND m.state IN ('ready_for_review', 'approved_by_tech', 'paid', 'disputed')
    AND EXISTS (
      SELECT 1 FROM public.milestone_evidences me
      WHERE me.milestone_id = m.id
    );

  -- Hitos revisables
  SELECT count(*)
  INTO v_reviewable
  FROM public.milestones
  WHERE pact_id = p_pact_id
    AND state IN ('ready_for_review', 'approved_by_tech', 'paid', 'disputed');

  -- Hitos validados rápido (< 7 días desde ready_for_review → paid)
  SELECT count(*)
  INTO v_fast_validations
  FROM public.milestones m
  JOIN public.milestone_state_transitions mst ON mst.milestone_id = m.id
    AND mst.to_state = 'paid'
  JOIN public.milestone_state_transitions mst2 ON mst2.milestone_id = m.id
    AND mst2.to_state = 'ready_for_review'
  WHERE m.pact_id = p_pact_id
    AND m.state = 'paid'
    AND (mst.occurred_at - mst2.occurred_at) < interval '7 days';

  -- Disputas activas en el pacto
  SELECT count(*)
  INTO v_disputes
  FROM public.disputes
  WHERE pact_id = p_pact_id
    AND state NOT IN ('resolved', 'withdrawn');

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

  v_compliance_pct := round((v_paid_milestones::numeric / v_total_milestones) * 100, 2);

  v_evidence_pct := CASE
    WHEN v_reviewable = 0 THEN 100
    ELSE round((v_with_evidences::numeric / v_reviewable) * 100, 2)
  END;

  v_speed_pct := CASE
    WHEN v_paid_milestones = 0 THEN 100
    ELSE round((v_fast_validations::numeric / v_paid_milestones) * 100, 2)
  END;

  v_no_disputes_pct := greatest(0, 100 - (v_disputes * 20));

  v_ia_score := coalesce(v_avg_ia_score, 75);

  v_final_score := round(
    v_compliance_pct  * 0.30 +
    v_evidence_pct    * 0.25 +
    v_speed_pct       * 0.20 +
    v_no_disputes_pct * 0.15 +
    v_ia_score        * 0.10
  )::smallint;

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


-- =====================================================================
-- 2 · Fix sf_recalc_user_reputation
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

  -- Estadísticas base de participación en pactos.
  -- Disputas se cuentan por pacto (no por usuario directo, ya que
  -- disputes no tiene raised_by_user_id).
  SELECT
    count(DISTINCT pp.pact_id),
    count(DISTINCT pp.pact_id) FILTER (
      WHERE NOT EXISTS (
        SELECT 1 FROM public.milestones m
        WHERE m.pact_id = pp.pact_id
          AND m.state != 'paid'
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
    AND d.state NOT IN ('resolved', 'withdrawn')
  WHERE pp.user_id = p_user_id;

  -- ---------------------------------------------------------------
  -- Score por rol
  -- ---------------------------------------------------------------

  IF v_user_role = 'promotor' THEN
    SELECT
      CASE WHEN count(*) = 0 THEN 100
      ELSE round(
        count(*) FILTER (WHERE m.state = 'paid')::numeric / count(*) * 100, 2
      ) END
    INTO v_payment_speed_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id
    WHERE pp.user_id = p_user_id AND pp.role = 'promotor';

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
    SELECT
      CASE WHEN count(*) = 0 THEN 75
      ELSE round(
        count(*) FILTER (
          WHERE (ar.metadata->>'score_numeric')::numeric >= 75
        )::numeric / count(*) * 100, 2
      ) END
    INTO v_evidence_quality_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id
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
    SELECT
      CASE WHEN count(*) = 0 THEN 100
      ELSE round(
        count(*) FILTER (
          WHERE (mst_paid.occurred_at - mst_rfr.occurred_at) < interval '3 days'
        )::numeric / count(*) * 100, 2
      ) END
    INTO v_val_speed_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id
      AND m.state = 'paid'
    JOIN public.milestone_state_transitions mst_rfr ON mst_rfr.milestone_id = m.id
      AND mst_rfr.to_state = 'ready_for_review'
    JOIN public.milestone_state_transitions mst_paid ON mst_paid.milestone_id = m.id
      AND mst_paid.to_state = 'paid'
    WHERE pp.user_id = p_user_id AND pp.role = 'tecnico';

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


-- =====================================================================
-- 3 · Fix get_pact_health: STABLE → VOLATILE
-- =====================================================================
-- PostgREST runs STABLE functions in read-only transactions, but
-- get_pact_health calls sf_recalc_pact_health (which does INSERT)
-- when no snapshot exists yet.

CREATE OR REPLACE FUNCTION public.get_pact_health(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
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
-- 4 · Fix get_user_reputation: STABLE → VOLATILE
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_user_reputation(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
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
-- 5 · Schema cache reload
-- =====================================================================
NOTIFY pgrst, 'reload schema';
