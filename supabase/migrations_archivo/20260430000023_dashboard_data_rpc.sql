-- =====================================================================
-- Sprint 4 extra · Migration 0027
-- sf_get_dashboard_data — alimenta la home con datos reales del usuario
-- =====================================================================
-- Devuelve un jsonb con:
--   role                  · primary_role del usuario actual
--   in_custody_cents      · suma deposit_current_cents (v2) o derivado (v1)
--                           de los pacts donde soy parte y están activos
--   active_works          · cuenta de pacts activos donde soy parte
--   new_works_this_month  · cuenta de pacts creados este mes donde soy parte
--   next_release          · próxima certificación / hito por liberar (si hay)
--                           { amount_cents, date, pact_id, pact_title }
--   urgent_tasks[]        · tareas pendientes de mi acción
--                           ( anexos pendientes de firma, contratos a firmar )
--   active_pacts[]        · hasta 5 pacts activos con título, ubicación,
--                           % progreso, importe y estado
-- =====================================================================

DROP FUNCTION IF EXISTS public.sf_get_dashboard_data;
CREATE OR REPLACE FUNCTION public.sf_get_dashboard_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_user_role text;
  v_in_custody bigint;
  v_active_works int;
  v_new_this_month int;
  v_next_release jsonb;
  v_urgent_tasks jsonb;
  v_active_pacts jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.primary_role::text INTO v_user_id, v_user_role
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- ===================================================================
  -- KPI 1 · En custodia
  -- ===================================================================
  -- v2: suma deposit_current_cents de pacts donde soy parte y están en
  --     estados con depósito activo.
  -- v1: usamos coalesce(deposit_current_cents, 0) para que no rompa con
  --     pacts antiguos. Los pacts v1 antiguos no tienen este balance, pero
  --     si en el futuro lo migramos podrán aparecer aquí.
  SELECT coalesce(sum(p.deposit_current_cents), 0)
  INTO v_in_custody
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.state IN ('funded','in_execution','paused_pending_tech','disputed');

  -- ===================================================================
  -- KPI 2 · Obras activas (cuenta)
  -- ===================================================================
  SELECT count(*) INTO v_active_works
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.state IN (
      'inviting','signing','signed','funded',
      'in_execution','paused_pending_tech','disputed'
    );

  -- ===================================================================
  -- KPI 3 · Nuevas este mes
  -- ===================================================================
  SELECT count(*) INTO v_new_this_month
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.created_at >= date_trunc('month', now());

  -- ===================================================================
  -- KPI 4 · Próxima liberación
  -- ===================================================================
  -- La certificación/hito validado o aprobado más cercana a la fecha objetivo
  -- (o al state_updated_at si no hay fecha) que aún no esté pagada.
  SELECT jsonb_build_object(
    'amount_cents', m.amount_cents,
    'target_date', m.target_date,
    'pact_id', m.pact_id,
    'pact_title', p.title,
    'milestone_name', m.name,
    'ordinal', m.ordinal
  )
  INTO v_next_release
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  JOIN public.pact_parties pp ON pp.pact_id = m.pact_id
  WHERE pp.user_id = v_user_id
    AND m.state IN ('validated_by_tech','approved_by_promotor')
  ORDER BY
    coalesce(m.target_date, m.state_updated_at::date) ASC,
    m.ordinal ASC
  LIMIT 1;

  -- ===================================================================
  -- TAREAS URGENTES
  -- ===================================================================
  -- Tres tipos:
  --   a) addendum_sign     · anexos pendientes de mi firma
  --   b) contract_sign     · contrato pendiente de mi firma (pact signing)
  --   c) accept_invite     · invitación pendiente de aceptar (pact inviting)
  WITH urgents AS (
    -- Anexos pendientes de mi firma
    SELECT
      'addendum_sign'::text     AS kind,
      ('Firmar anexo · ' || a.title) AS title,
      p.title                    AS subtitle,
      p.id                       AS pact_id,
      'URGENTE'::text            AS badge_label,
      a.created_at               AS sort_at
    FROM public.pact_addendums a
    JOIN public.pacts p ON p.id = a.pact_id
    JOIN public.pact_parties pp ON pp.pact_id = a.pact_id AND pp.user_id = v_user_id
    WHERE a.state IN ('proposed','signing')
      AND CASE pp.role::text
        WHEN 'promotor'    THEN a.signed_at_promotor IS NULL
        WHEN 'constructor' THEN a.signed_at_constructor IS NULL
        WHEN 'tecnico'     THEN a.signed_at_tecnico IS NULL
        ELSE false
      END

    UNION ALL

    -- Contratos pendientes de mi firma
    SELECT
      'contract_sign'::text     AS kind,
      'Firmar contrato'::text    AS title,
      p.title                    AS subtitle,
      p.id                       AS pact_id,
      'URGENTE'::text            AS badge_label,
      pp.accepted_at             AS sort_at
    FROM public.pacts p
    JOIN public.pact_parties pp ON pp.pact_id = p.id AND pp.user_id = v_user_id
    WHERE p.state = 'signing'
      AND pp.accepted_at IS NOT NULL
      AND pp.signed_at IS NULL

    UNION ALL

    -- Invitaciones pendientes de aceptar
    SELECT
      'accept_invite'::text     AS kind,
      'Aceptar invitación'::text AS title,
      p.title                    AS subtitle,
      p.id                       AS pact_id,
      'NUEVO'::text              AS badge_label,
      pp.invited_at              AS sort_at
    FROM public.pacts p
    JOIN public.pact_parties pp ON pp.pact_id = p.id AND pp.user_id = v_user_id
    WHERE p.state = 'inviting'
      AND pp.accepted_at IS NULL
  )
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'kind', u.kind,
      'title', u.title,
      'subtitle', u.subtitle,
      'pact_id', u.pact_id,
      'badge_label', u.badge_label
    )
    ORDER BY u.sort_at DESC
  ), '[]'::jsonb)
  INTO v_urgent_tasks
  FROM (
    SELECT * FROM urgents ORDER BY sort_at DESC LIMIT 5
  ) u;

  -- ===================================================================
  -- OBRAS ACTIVAS (hasta 5)
  -- ===================================================================
  WITH active AS (
    SELECT
      p.id, p.display_id, p.title, p.state::text AS state,
      coalesce(p.obra_city, p.obra_address_line) AS city,
      p.total_amount_cents, p.budget_consumed_cents,
      p.deposit_required_pct, p.deposit_current_cents,
      coalesce(p.model_version, 'v1') AS model_version,
      p.state_updated_at
    FROM public.pacts p
    JOIN public.pact_parties pp ON pp.pact_id = p.id AND pp.user_id = v_user_id
    WHERE p.state IN (
      'inviting','signing','signed','funded',
      'in_execution','paused_pending_tech','disputed'
    )
    ORDER BY p.state_updated_at DESC
    LIMIT 5
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'display_id', a.display_id,
    'title', a.title,
    'state', a.state,
    'city', a.city,
    'total_amount_cents', a.total_amount_cents,
    'budget_consumed_cents', a.budget_consumed_cents,
    'deposit_current_cents', a.deposit_current_cents,
    'progress_pct', CASE
      WHEN a.total_amount_cents > 0
        THEN round((a.budget_consumed_cents::numeric / a.total_amount_cents) * 100)::int
      ELSE 0
    END,
    'model_version', a.model_version
  )), '[]'::jsonb)
  INTO v_active_pacts
  FROM active a;

  -- ===================================================================
  -- RESULTADO
  -- ===================================================================
  RETURN jsonb_build_object(
    'role', v_user_role,
    'in_custody_cents', v_in_custody,
    'active_works', v_active_works,
    'new_works_this_month', v_new_this_month,
    'next_release', v_next_release,
    'urgent_tasks', v_urgent_tasks,
    'active_pacts', v_active_pacts
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_dashboard_data TO authenticated;

COMMENT ON FUNCTION public.sf_get_dashboard_data IS
  'Sprint 4 extra · Datos agregados para la home según el rol del usuario. '
  'Reemplaza los mocks que había en dashboard_promotor/constructor/tecnico.';

NOTIFY pgrst, 'reload schema';
