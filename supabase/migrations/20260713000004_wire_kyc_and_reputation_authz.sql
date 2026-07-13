-- REVISAR Y EJECUTAR MANUALMENTE. NO APLICADO. Verificar impacto en usuarios existentes.
-- =====================================================================
-- AUDITORÍA 2026-07-13 · PactStream C1(c) + A3
-- Control de acceso en el motor de reputación + cableado KYC (documentado)
-- =====================================================================
-- RE-DERIVADO 2026-07-13 sobre la definición ACTUAL del remoto. Se
-- comprobó con pg_get_functiondef que el cuerpo vigente de
-- get_user_reputation y sf_recalc_user_reputation es la versión del
-- scoring engine (misma lógica de cálculo que antes de junio); las
-- migraciones de junio (quality_conditional_retention / quality_summary_rpc)
-- NO cambiaron la lógica de estas dos funciones. Este parche parte del
-- CUERPO REMOTO EXACTO y añade ÚNICAMENTE el control de seguridad. No se
-- altera ninguna fórmula de puntuación.
--
-- (a) get_user_reputation: era SECURITY DEFINER sin control de
--     pertenencia → cualquier autenticado podía leer el score de CUALQUIER
--     usuario por su UUID. Se añade el mismo patrón de get_pact_health:
--     permitido solo si el llamante es el propio usuario O comparte algún
--     pacto con él.
-- (b) sf_recalc_user_reputation: era ejecutable por cualquier autenticado
--     sobre cualquier UUID. Guard: un cliente directo solo puede recalcular
--     su propia reputación; service_role y llamadas internas SECURITY
--     DEFINER (current_user = owner) quedan exentos. IMPRESCINDIBLE que la
--     llamada interna PERFORM public.sf_recalc_user_reputation(p_user_id)
--     desde get_user_reputation siga funcionando: por eso el guard solo
--     aplica cuando current_user IN ('authenticated','anon').
-- (c) check_kyc_verified en las RPC de dinero: DOCUMENTADO (bloque
--     comentado). Cablearlo exige editar cada RPC larga preservando su
--     cuerpo — se hace en revisión dedicada.
--
-- IMPACTO: los usuarios siguen viendo su propia reputación y la de
-- contrapartes de sus pactos. Consultar la de un tercero sin pacto en común
-- ahora devuelve 'Forbidden'.
-- Se usa CREATE OR REPLACE (firma exacta (uuid) en ambas).
-- =====================================================================


-- =====================================================================
-- (a) get_user_reputation(uuid) — añade control de pertenencia
-- =====================================================================
CREATE OR REPLACE FUNCTION public.get_user_reputation(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_row user_reputations;
BEGIN
  -- ── Control de acceso (auditoría 2026-07-13 A3) ──────────────────
  -- Permitido solo si el llamante es el propio usuario consultado o si
  -- comparte al menos un pacto con él (mismo criterio que get_pact_health).
  IF NOT EXISTS (
    -- (i) el propio usuario
    SELECT 1 FROM public.users u
    WHERE u.id = p_user_id
      AND u.auth_provider_id = auth.uid()::text
      AND u.deleted_at IS NULL
    UNION
    -- (ii) contraparte en algún pacto compartido
    SELECT 1
    FROM public.pact_parties pp_self
    JOIN public.users u_self ON u_self.id = pp_self.user_id
    JOIN public.pact_parties pp_target ON pp_target.pact_id = pp_self.pact_id
    WHERE u_self.auth_provider_id = auth.uid()::text
      AND u_self.deleted_at IS NULL
      AND pp_target.user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_row FROM public.user_reputations
  WHERE user_id = p_user_id ORDER BY calculated_at DESC LIMIT 1;

  IF NOT FOUND THEN
    PERFORM public.sf_recalc_user_reputation(p_user_id);
    SELECT * INTO v_row FROM public.user_reputations
    WHERE user_id = p_user_id ORDER BY calculated_at DESC LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id, 'user_id', v_row.user_id, 'role', v_row.role,
    'score', v_row.score, 'tier', v_row.tier, 'components', v_row.components,
    'pacts_total', v_row.pacts_total, 'pacts_completed', v_row.pacts_completed,
    'pacts_disputed', v_row.pacts_disputed, 'calculated_at', v_row.calculated_at
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_user_reputation(uuid) TO authenticated;


-- =====================================================================
-- (b) sf_recalc_user_reputation(uuid) — añade guard de autorización
-- =====================================================================
CREATE OR REPLACE FUNCTION public.sf_recalc_user_reputation(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_role user_role; v_pacts_total int; v_pacts_completed int; v_pacts_disputed int;
  v_payment_speed_pct numeric; v_evidence_quality_pct numeric;
  v_sign_rate_pct numeric; v_val_speed_pct numeric;
  v_final_score smallint; v_tier text; v_components jsonb; v_snapshot_id uuid;
BEGIN
  -- ── Control de acceso (auditoría 2026-07-13 A3) ──────────────────
  -- Un cliente directo (authenticated/anon) solo puede recalcular su propia
  -- reputación. service_role y llamadas internas SECURITY DEFINER
  -- (current_user = owner, p.ej. desde get_user_reputation) quedan exentos.
  IF current_user IN ('authenticated', 'anon') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = p_user_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'Forbidden' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  SELECT primary_role INTO v_user_role FROM public.users
  WHERE id = p_user_id AND deleted_at IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'user_not_found'); END IF;

  SELECT
    count(DISTINCT pp.pact_id),
    count(DISTINCT pp.pact_id) FILTER (
      WHERE NOT EXISTS (SELECT 1 FROM public.milestones m WHERE m.pact_id = pp.pact_id AND m.state != 'paid')
        AND EXISTS (SELECT 1 FROM public.milestones m2 WHERE m2.pact_id = pp.pact_id AND m2.state = 'paid')
    ),
    count(DISTINCT d.pact_id)
  INTO v_pacts_total, v_pacts_completed, v_pacts_disputed
  FROM public.pact_parties pp
  LEFT JOIN public.disputes d ON d.pact_id = pp.pact_id AND d.state NOT IN ('resolved','withdrawn')
  WHERE pp.user_id = p_user_id;

  IF v_user_role = 'promotor' THEN
    SELECT CASE WHEN count(*) = 0 THEN 100
      ELSE round(count(*) FILTER (WHERE m.state = 'paid')::numeric / count(*) * 100, 2) END
    INTO v_payment_speed_pct
    FROM public.pact_parties pp JOIN public.milestones m ON m.pact_id = pp.pact_id
    WHERE pp.user_id = p_user_id AND pp.role = 'promotor';

    v_final_score := round(
      v_payment_speed_pct * 0.40 +
      greatest(0, 100 - (v_pacts_disputed * 25)) * 0.35 +
      (CASE WHEN v_pacts_total = 0 THEN 75 ELSE v_pacts_completed::numeric / v_pacts_total * 100 END) * 0.25
    )::smallint;
    v_components := jsonb_build_object('payment_speed_pct', v_payment_speed_pct,
      'no_disputes_pct', greatest(0, 100 - v_pacts_disputed * 25),
      'completion_pct', CASE WHEN v_pacts_total = 0 THEN 75 ELSE round(v_pacts_completed::numeric / v_pacts_total * 100, 2) END);

  ELSIF v_user_role = 'constructor' THEN
    SELECT CASE WHEN count(*) = 0 THEN 75
      ELSE round(count(*) FILTER (WHERE (ar.metadata->>'score_numeric')::numeric >= 75)::numeric / count(*) * 100, 2) END
    INTO v_evidence_quality_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id
    JOIN public.ai_runs ar ON ar.pact_id = pp.pact_id AND ar.run_type = 'vision' AND ar.success = true
      AND ar.metadata->>'score_numeric' IS NOT NULL
    WHERE pp.user_id = p_user_id AND pp.role = 'constructor';

    v_final_score := round(
      (CASE WHEN v_pacts_total = 0 THEN 75 ELSE v_pacts_completed::numeric / v_pacts_total * 100 END) * 0.40 +
      v_evidence_quality_pct * 0.35 + greatest(0, 100 - v_pacts_disputed * 25) * 0.25
    )::smallint;
    v_components := jsonb_build_object('completion_pct', CASE WHEN v_pacts_total = 0 THEN 75
      ELSE round(v_pacts_completed::numeric / v_pacts_total * 100, 2) END,
      'evidence_quality_pct', v_evidence_quality_pct, 'no_disputes_pct', greatest(0, 100 - v_pacts_disputed * 25));

  ELSE -- tecnico
    SELECT CASE WHEN count(*) = 0 THEN 100
      ELSE round(count(*) FILTER (WHERE (mst_paid.occurred_at - mst_rfr.occurred_at) < interval '3 days')::numeric / count(*) * 100, 2) END
    INTO v_val_speed_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id AND m.state = 'paid'
    JOIN public.milestone_state_transitions mst_rfr ON mst_rfr.milestone_id = m.id AND mst_rfr.to_state = 'ready_for_review'
    JOIN public.milestone_state_transitions mst_paid ON mst_paid.milestone_id = m.id AND mst_paid.to_state = 'paid'
    WHERE pp.user_id = p_user_id AND pp.role = 'tecnico';

    SELECT CASE WHEN count(*) = 0 THEN 100
      ELSE round(count(*) FILTER (WHERE pp2.signed_at IS NOT NULL)::numeric / count(*) * 100, 2) END
    INTO v_sign_rate_pct FROM public.pact_parties pp2
    WHERE pp2.user_id = p_user_id AND pp2.role = 'tecnico';

    v_final_score := round(coalesce(v_val_speed_pct, 100)*0.50 + coalesce(v_sign_rate_pct, 100)*0.30 + greatest(0, 100 - v_pacts_disputed*25)*0.20)::smallint;
    v_components := jsonb_build_object('validation_speed_pct', coalesce(v_val_speed_pct, 100),
      'sign_rate_pct', coalesce(v_sign_rate_pct, 100), 'no_disputes_pct', greatest(0, 100 - v_pacts_disputed * 25));
  END IF;

  v_final_score := greatest(0, least(100, v_final_score));
  v_tier := private.score_to_tier(v_final_score);

  INSERT INTO public.user_reputations (user_id, role, score, tier, components, pacts_total, pacts_completed, pacts_disputed, calculated_at)
  VALUES (p_user_id, v_user_role, v_final_score, v_tier, v_components, v_pacts_total, v_pacts_completed, v_pacts_disputed, now())
  RETURNING id INTO v_snapshot_id;

  RETURN jsonb_build_object('snapshot_id', v_snapshot_id, 'role', v_user_role, 'score', v_final_score,
    'tier', v_tier, 'components', v_components, 'pacts_total', v_pacts_total,
    'pacts_completed', v_pacts_completed, 'pacts_disputed', v_pacts_disputed);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.sf_recalc_user_reputation(uuid) TO authenticated, service_role;


-- =====================================================================
-- (c) CABLEADO KYC EN RPC DE DINERO — DOCUMENTADO, NO APLICADO AQUÍ
-- =====================================================================
-- El helper public.check_kyc_verified(p_user_id uuid) ya existe
-- (20260531000005_security_hardening.sql:100). Falta invocarlo al inicio de
-- las RPC críticas, DESPUÉS de resolver v_user_id (el id de public.users del
-- llamante) y ANTES de mutar estado:
--
--   PERFORM public.check_kyc_verified(v_user_id);
--
-- Funciones objetivo (editar preservando el resto del cuerpo, re-derivando
-- sobre la definición ACTUAL del remoto — junio pudo tocarlas):
--   · sf_create_pact_v2
--   · sf_create_pact_v21
--   · sf_sign_contract
--   · sf_pact_fund_initial / sf_pact_setup_advance
--   · sf_milestone_promotor_decide
--
-- TODO(seguridad): cablear una por una en revisión dedicada. NO se hace aquí
-- para no arriesgar la lógica de escrow/creación.
--
-- IMPACTO ESPERADO AL CABLEAR: los usuarios con kyc_status != 'verified' NO
-- podrán crear pactos, firmar, financiar ni liberar hitos. Verificar antes
-- cuántos usuarios/pactos activos tienen KYC incompleto para no bloquear
-- operaciones en curso.

NOTIFY pgrst, 'reload schema';
