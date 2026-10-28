-- =====================================================================
-- Sprint 6 chunk 6c · Backend para toggles de notificaciones
-- =====================================================================
--   * sf_update_member_permissions ahora acepta los 3 toggles. Si NULL,
--     conserva el valor actual.
--   * sf_get_org_members devuelve los 3 toggles en el payload.
--   * sf_list_my_orgs corregido para devolver legal_name/trade_name/cif/
--     kyb_status alineados con el schema real (no name/vat_id que no
--     existen).
-- =====================================================================


DROP FUNCTION IF EXISTS public.sf_update_member_permissions;
CREATE OR REPLACE FUNCTION public.sf_update_member_permissions(
  p_member_id                       uuid,
  p_can_view_economics              boolean DEFAULT NULL,
  p_receive_notifications           boolean DEFAULT NULL,
  p_receive_economic_notifications  boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_member   public.organization_members%ROWTYPE;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_member FROM public.organization_members
  WHERE id = p_member_id;
  IF v_member.id IS NULL THEN
    RAISE EXCEPTION 'Miembro no encontrado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = v_member.organization_id
      AND user_id = v_user_id
      AND role = 'owner'
      AND state = 'active'
  ) THEN
    RAISE EXCEPTION 'Solo el owner puede modificar permisos';
  END IF;

  IF v_member.role = 'owner' THEN
    RAISE EXCEPTION 'Los permisos del owner no se pueden modificar';
  END IF;

  UPDATE public.organization_members
  SET can_view_economics             = coalesce(p_can_view_economics, can_view_economics),
      receive_notifications          = coalesce(p_receive_notifications, receive_notifications),
      receive_economic_notifications = coalesce(p_receive_economic_notifications, receive_economic_notifications)
  WHERE id = p_member_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_perms_updated', 'organization_member', p_member_id,
    jsonb_build_object(
      'can_view_economics', p_can_view_economics,
      'receive_notifications', p_receive_notifications,
      'receive_economic_notifications', p_receive_economic_notifications
    ));

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_update_member_permissions TO authenticated;


DROP FUNCTION IF EXISTS public.sf_get_org_members;
CREATE OR REPLACE FUNCTION public.sf_get_org_members(p_org_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid  uuid;
  v_user_id   uuid;
  v_is_member boolean;
  v_result    jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_org_id AND user_id = v_user_id AND state = 'active'
  ) INTO v_is_member;
  IF NOT v_is_member THEN
    RAISE EXCEPTION 'No tienes acceso a esta organización';
  END IF;

  SELECT jsonb_build_object(
    'members', coalesce(jsonb_agg(jsonb_build_object(
      'id', om.id,
      'user_id', om.user_id,
      'role', om.role,
      'state', om.state,
      'invited_email', om.invited_email,
      'full_name', coalesce(u.full_name, om.full_name),
      'email', coalesce(u.email, om.invited_email),
      'can_view_economics', om.can_view_economics,
      'receive_notifications', om.receive_notifications,
      'receive_economic_notifications', om.receive_economic_notifications,
      'invited_at', om.invited_at,
      'accepted_at', om.accepted_at,
      'is_me', (om.user_id = v_user_id)
    ) ORDER BY
      CASE om.role WHEN 'owner' THEN 1 ELSE 2 END,
      om.accepted_at NULLS LAST,
      om.invited_at
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.organization_members om
  LEFT JOIN public.users u ON u.id = om.user_id
  WHERE om.organization_id = p_org_id
    AND om.state IN ('invited', 'active');

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_get_org_members TO authenticated;


DROP FUNCTION IF EXISTS public.sf_list_my_orgs;
CREATE OR REPLACE FUNCTION public.sf_list_my_orgs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_orgs     jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', o.id,
    'legal_name', o.legal_name,
    'trade_name', o.trade_name,
    'cif', o.cif,
    'description', o.description,
    'org_type', coalesce(o.org_type::text, 'constructor'),
    'kyb_status', o.kyb_status::text,
    'is_owner', (om.role = 'owner'),
    'can_view_economics', om.can_view_economics,
    'member_id', om.id,
    'joined_at', om.accepted_at,
    'members_count', (
      SELECT count(*) FROM public.organization_members
      WHERE organization_id = o.id AND state = 'active'
    ),
    'pending_invites_count', (
      SELECT count(*) FROM public.organization_members
      WHERE organization_id = o.id AND state = 'invited'
    )
  ) ORDER BY (om.role = 'owner') DESC, o.created_at DESC), '[]'::jsonb)
  INTO v_orgs
  FROM public.organizations o
  JOIN public.organization_members om
    ON om.organization_id = o.id
    AND om.user_id = v_user_id
    AND om.state = 'active'
  WHERE o.deleted_at IS NULL;

  RETURN jsonb_build_object(
    'user_id', v_user_id,
    'organizations', v_orgs
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_list_my_orgs TO authenticated;

NOTIFY pgrst, 'reload schema';
