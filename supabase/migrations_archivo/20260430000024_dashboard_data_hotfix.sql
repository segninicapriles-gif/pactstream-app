-- =====================================================================
-- Sprint 4 extra · Migration 0028 (HOTFIX)
-- Corrige nombres de estados de milestone en sf_get_dashboard_data
-- =====================================================================
-- El enum milestone_state real tiene:
--   pending · in_execution · ready_for_review · in_validation ·
--   info_requested · approved_by_tech · rejected_by_tech ·
--   awaiting_promotor · paid · disputed
--
-- En la 0027 asumí 'validated_by_tech' / 'approved_by_promotor' que no
-- existen. La RPC se cae al hacer cast del literal a milestone_state.
--
-- Sustituimos por los nombres reales:
--   'approved_by_tech'  → técnico ya aprobó, queda esperar al promotor
--   'awaiting_promotor' → esperando confirmación final del promotor
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

  -- En custodia
  SELECT coalesce(sum(p.deposit_current_cents), 0)
  INTO v_in_custody
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.state IN ('funded','in_execution','paused_pending_tech','disputed');

  -- Obras activas
  SELECT count(*) INTO v_active_works
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.state IN (
      'inviting','signing','signed','funded',
      'in_execution','paused_pending_tech','disputed'
    );

  -- Nuevas este mes
  SELECT count(*) INTO v_new_this_month
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.created_at >= date_trunc('month', now());

  -- Próxima liberación: certificación/hito en cualquier estado posterior
  -- a la validación pero aún no pagado.
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
    AND m.state IN ('approved_by_tech','awaiting_promotor')
  ORDER BY
    coalesce(m.target_date, m.state_updated_at::date) ASC,
    m.ordinal ASC
  LIMIT 1;

  -- Tareas urgentes
  WITH urgents AS (
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

  -- Obras activas
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
  'Sprint 4 extra hotfix · Estados de milestone corregidos a los reales '
  '(approved_by_tech, awaiting_promotor).';

NOTIFY pgrst, 'reload schema';
