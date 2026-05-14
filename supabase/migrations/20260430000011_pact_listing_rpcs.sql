-- =====================================================================
-- Sprint 2 chunk 2 · Migration 0013
-- RPCs para listar pactos del usuario y leer detalle completo.
-- =====================================================================
-- Funciones:
--   sf_list_my_pacts()        → resumen de todos los pactos del user
--   sf_get_pact_detail(p_id)  → detalle completo + partes + hitos
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_list_my_pacts
-- ---------------------------------------------------------------------
-- Devuelve los pactos donde el usuario es parte (creador o invitado),
-- con resumen para mostrar en lista. Ordenado por fecha de actualización
-- desc para mostrar primero los más activos.
DROP FUNCTION IF EXISTS public.sf_list_my_pacts;
CREATE OR REPLACE FUNCTION public.sf_list_my_pacts()
RETURNS TABLE(
  pact_id            uuid,
  display_id         text,
  title              text,
  pact_type          text,
  state              text,
  state_updated_at   timestamptz,
  obra_city          text,
  obra_province      text,
  total_amount_cents bigint,
  my_role            text,
  parties_total      int,
  parties_accepted   int,
  milestones_total   int,
  milestones_paid    int,
  next_milestone_name text,
  next_milestone_amount_cents bigint,
  next_milestone_target_date date,
  created_at         timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  RETURN QUERY
  WITH my_pacts AS (
    SELECT DISTINCT pp.pact_id, pp.role::text AS my_role
    FROM public.pact_parties pp
    WHERE pp.user_id = v_user_id
  ),
  party_stats AS (
    SELECT
      pp.pact_id,
      count(*)::int AS total,
      count(*) FILTER (WHERE pp.accepted_at IS NOT NULL)::int AS accepted
    FROM public.pact_parties pp
    GROUP BY pp.pact_id
  ),
  milestone_stats AS (
    SELECT
      m.pact_id,
      count(*)::int AS total,
      count(*) FILTER (WHERE m.state = 'paid')::int AS paid
    FROM public.milestones m
    GROUP BY m.pact_id
  ),
  next_milestones AS (
    -- Primer hito que NO está pagado, en orden ascendente de ordinal.
    SELECT DISTINCT ON (m.pact_id)
      m.pact_id,
      m.name,
      m.amount_cents,
      m.target_date
    FROM public.milestones m
    WHERE m.state != 'paid'
    ORDER BY m.pact_id, m.ordinal
  )
  SELECT
    p.id,
    p.display_id,
    p.title,
    p.pact_type::text,
    p.state::text,
    p.state_updated_at,
    p.obra_city,
    p.obra_province,
    p.total_amount_cents,
    mp.my_role,
    coalesce(ps.total, 0),
    coalesce(ps.accepted, 0),
    coalesce(ms.total, 0),
    coalesce(ms.paid, 0),
    nm.name,
    nm.amount_cents,
    nm.target_date,
    p.created_at
  FROM public.pacts p
  JOIN my_pacts mp ON mp.pact_id = p.id
  LEFT JOIN party_stats ps ON ps.pact_id = p.id
  LEFT JOIN milestone_stats ms ON ms.pact_id = p.id
  LEFT JOIN next_milestones nm ON nm.pact_id = p.id
  ORDER BY p.state_updated_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_list_my_pacts TO authenticated;

COMMENT ON FUNCTION public.sf_list_my_pacts IS
  'Lista resumen de pactos donde el usuario es parte. Incluye conteos de partes, hitos y siguiente hito pendiente.';


-- ---------------------------------------------------------------------
-- sf_get_pact_detail
-- ---------------------------------------------------------------------
-- Devuelve el pacto completo + partes + hitos en JSON.
-- Validamos que el caller sea parte del pacto.
DROP FUNCTION IF EXISTS public.sf_get_pact_detail;
CREATE OR REPLACE FUNCTION public.sf_get_pact_detail(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_is_party boolean;
  v_result   jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- Validar que el caller forma parte del pacto
  SELECT EXISTS(
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id
  ) INTO v_is_party;

  IF NOT v_is_party THEN
    RAISE EXCEPTION 'No tienes acceso a este pacto';
  END IF;

  -- Construir el JSON de respuesta
  SELECT jsonb_build_object(
    'pact', jsonb_build_object(
      'id', p.id,
      'display_id', p.display_id,
      'title', p.title,
      'description', p.description,
      'pact_type', p.pact_type::text,
      'state', p.state::text,
      'state_updated_at', p.state_updated_at,
      'obra_address_line', p.obra_address_line,
      'obra_postal_code', p.obra_postal_code,
      'obra_city', p.obra_city,
      'obra_province', p.obra_province,
      'obra_type', p.obra_type,
      'total_amount_cents', p.total_amount_cents,
      'iva_rate_pct', p.iva_rate_pct,
      'iva_included', p.iva_included,
      'platform_fee_pct', p.platform_fee_pct,
      'estimated_start_date', p.estimated_start_date,
      'estimated_end_date', p.estimated_end_date,
      'created_by_user_id', p.created_by_user_id,
      'created_at', p.created_at,
      'is_creator', (p.created_by_user_id = v_user_id),
      'my_user_id', v_user_id
    ),
    'parties', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', pp.id,
        'role', pp.role::text,
        'user_id', pp.user_id,
        'is_me', (pp.user_id = v_user_id),
        'snapshot_full_name', pp.snapshot_full_name,
        'snapshot_email', pp.snapshot_email,
        'invited_at', pp.invited_at,
        'accepted_at', pp.accepted_at,
        'signed_at', pp.signed_at,
        'signature_state', pp.signature_state::text
      ) ORDER BY
        CASE pp.role::text
          WHEN 'promotor' THEN 1
          WHEN 'constructor' THEN 2
          WHEN 'tecnico' THEN 3
          ELSE 4
        END
      )
      FROM public.pact_parties pp WHERE pp.pact_id = p.id
    ), '[]'::jsonb),
    'milestones', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', m.id,
        'display_id', m.display_id,
        'ordinal', m.ordinal,
        'name', m.name,
        'description', m.description,
        'amount_cents', m.amount_cents,
        'target_date', m.target_date,
        'state', m.state::text,
        'state_updated_at', m.state_updated_at,
        'started_at', m.started_at,
        'submitted_at', m.submitted_at,
        'validated_at', m.validated_at,
        'approved_by_promotor_at', m.approved_by_promotor_at,
        'rejected_at', m.rejected_at,
        'paid_at', m.paid_at
      ) ORDER BY m.ordinal)
      FROM public.milestones m WHERE m.pact_id = p.id
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.pacts p
  WHERE p.id = p_pact_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_pact_detail TO authenticated;

COMMENT ON FUNCTION public.sf_get_pact_detail IS
  'Detalle completo del pacto + partes + hitos. Solo accesible para las partes del pacto.';
