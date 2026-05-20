-- =====================================================================
-- Sprint 6 chunk 2 · Migration 0033
-- RPCs de gestión de organizaciones
-- =====================================================================
-- 7 RPCs para el ciclo de vida completo de organizaciones y miembros:
--
--   1. sf_create_organization     · Crear org (caller queda como owner)
--   2. sf_invite_org_member       · Owner invita por email
--   3. sf_accept_org_invite       · Miembro acepta con token
--   4. sf_revoke_org_member       · Owner revoca a un miembro
--   5. sf_update_member_permissions · Owner cambia can_view_economics
--   6. sf_list_my_orgs            · Lista mis organizaciones (owner y member)
--   7. sf_get_org_members         · Lista miembros de una org
--
-- El envío del email con el invitation_token vive en una Edge Function
-- (chunk 4 del Sprint 6). Estas RPCs solo crean el registro y devuelven
-- el token para que el frontend dispare el correo.
-- =====================================================================


-- =====================================================================
-- 1 · sf_create_organization
-- =====================================================================
-- Crear una nueva organización. El caller queda como owner automático
-- vía el trigger trg_create_owner_member (migración 0032).
DROP FUNCTION IF EXISTS public.sf_create_organization;
CREATE OR REPLACE FUNCTION public.sf_create_organization(
  p_name text,
  p_vat_id text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_org_type text DEFAULT 'constructor'
)
RETURNS TABLE(out_org_id uuid, out_org_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_org_id uuid;
  v_user_role user_role;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.primary_role INTO v_user_id, v_user_role
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF p_org_type NOT IN ('constructor', 'tecnico', 'promotor', 'mixed') THEN
    RAISE EXCEPTION 'Tipo de organización inválido: %', p_org_type;
  END IF;

  -- Solo constructores y técnicos pueden crear orgs en MVP
  IF p_org_type = 'promotor' THEN
    RAISE EXCEPTION 'Las organizaciones de promotor estarán disponibles en una versión posterior';
  END IF;

  IF length(trim(p_name)) < 2 THEN
    RAISE EXCEPTION 'El nombre de la organización es obligatorio';
  END IF;

  -- Validar que el user no tenga ya una organización (constraint UNIQUE
  -- también lo cubre pero damos error legible)
  IF EXISTS (
    SELECT 1 FROM public.organizations WHERE owner_user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Ya tienes una organización creada. En MVP solo se permite una por usuario.';
  END IF;

  INSERT INTO public.organizations (
    name, vat_id, description, org_type, owner_user_id
  ) VALUES (
    trim(p_name),
    nullif(trim(coalesce(p_vat_id, '')), ''),
    nullif(trim(coalesce(p_description, '')), ''),
    p_org_type::org_type,
    v_user_id
  )
  RETURNING id INTO v_org_id;

  -- El trigger trg_create_owner_member ya creó al owner como miembro activo.

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_created', 'organization', v_org_id,
    jsonb_build_object('name', trim(p_name), 'org_type', p_org_type));

  out_org_id := v_org_id;
  out_org_name := trim(p_name);
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_create_organization TO authenticated;


-- =====================================================================
-- 2 · sf_invite_org_member
-- =====================================================================
-- Owner invita a un miembro por email. Devuelve el invitation_token
-- (UUID) que el frontend usa para construir el link enviado por email.
DROP FUNCTION IF EXISTS public.sf_invite_org_member;
CREATE OR REPLACE FUNCTION public.sf_invite_org_member(
  p_org_id uuid,
  p_invited_email text,
  p_full_name text,
  p_can_view_economics boolean DEFAULT false
)
RETURNS TABLE(out_member_id uuid, out_invitation_token uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_member_id uuid;
  v_token uuid;
  v_normalized_email text;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  -- Solo el owner puede invitar
  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_org_id
      AND user_id = v_user_id
      AND role = 'owner'
      AND state = 'active'
  ) THEN
    RAISE EXCEPTION 'Solo el owner de la organización puede invitar miembros';
  END IF;

  -- Normalizar email
  v_normalized_email := lower(trim(p_invited_email));
  IF v_normalized_email = '' OR position('@' IN v_normalized_email) < 2 THEN
    RAISE EXCEPTION 'Email inválido';
  END IF;

  IF length(trim(p_full_name)) < 2 THEN
    RAISE EXCEPTION 'El nombre completo del miembro es obligatorio';
  END IF;

  -- No se puede invitar al propio owner
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = v_user_id AND lower(email) = v_normalized_email
  ) THEN
    RAISE EXCEPTION 'No puedes invitarte a ti mismo';
  END IF;

  -- Si ya existe una invitación para ese email (cualquier estado), error
  IF EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_org_id
      AND lower(invited_email) = v_normalized_email
  ) THEN
    RAISE EXCEPTION 'Ya existe una invitación o membresía para %', v_normalized_email;
  END IF;

  v_token := gen_random_uuid();

  INSERT INTO public.organization_members (
    organization_id, invited_email, full_name,
    role, can_view_economics, state,
    invitation_token, invited_by_user_id
  ) VALUES (
    p_org_id, v_normalized_email, trim(p_full_name),
    'member', p_can_view_economics, 'invited',
    v_token, v_user_id
  )
  RETURNING id INTO v_member_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_invited', 'organization_member', v_member_id,
    jsonb_build_object(
      'org_id', p_org_id,
      'email', v_normalized_email,
      'can_view_economics', p_can_view_economics
    ));

  out_member_id := v_member_id;
  out_invitation_token := v_token;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_invite_org_member TO authenticated;


-- =====================================================================
-- 3 · sf_accept_org_invite
-- =====================================================================
-- Miembro invitado acepta la invitación con el token recibido por email.
-- Valida que el email del user autenticado coincida con el invitado
-- (evita que cualquiera con el link acepte la invitación de otro).
DROP FUNCTION IF EXISTS public.sf_accept_org_invite;
CREATE OR REPLACE FUNCTION public.sf_accept_org_invite(
  p_invitation_token uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_email text;
  v_member public.organization_members%ROWTYPE;
  v_org public.organizations%ROWTYPE;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id, lower(u.email) INTO v_user_id, v_user_email
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_member FROM public.organization_members
  WHERE invitation_token = p_invitation_token;
  IF v_member.id IS NULL THEN
    RAISE EXCEPTION 'Token de invitación no encontrado o ya consumido';
  END IF;

  IF v_member.state != 'invited' THEN
    RAISE EXCEPTION 'La invitación ya fue procesada (estado: %)', v_member.state;
  END IF;

  -- Email del invitado debe coincidir con el del user autenticado
  IF lower(v_member.invited_email) != v_user_email THEN
    RAISE EXCEPTION 'Esta invitación fue enviada a otro email. Inicia sesión con la cuenta correcta.';
  END IF;

  SELECT * INTO v_org FROM public.organizations WHERE id = v_member.organization_id;
  IF v_org.id IS NULL THEN
    RAISE EXCEPTION 'La organización ya no existe';
  END IF;

  -- Activar al miembro
  UPDATE public.organization_members
  SET state = 'active',
      user_id = v_user_id,
      accepted_at = now(),
      invitation_token = gen_random_uuid()  -- invalida el token para reuse
  WHERE id = v_member.id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_accepted', 'organization_member', v_member.id,
    jsonb_build_object('org_id', v_org.id, 'org_name', v_org.name));

  RETURN jsonb_build_object(
    'success', true,
    'organization', jsonb_build_object(
      'id', v_org.id,
      'name', v_org.name,
      'org_type', v_org.org_type::text
    ),
    'member', jsonb_build_object(
      'id', v_member.id,
      'role', v_member.role::text,
      'can_view_economics', v_member.can_view_economics
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_accept_org_invite TO authenticated;


-- =====================================================================
-- 4 · sf_revoke_org_member
-- =====================================================================
-- Owner revoca a un miembro activo o cancela una invitación pendiente.
DROP FUNCTION IF EXISTS public.sf_revoke_org_member;
CREATE OR REPLACE FUNCTION public.sf_revoke_org_member(
  p_member_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_member public.organization_members%ROWTYPE;
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

  -- Solo el owner puede revocar
  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = v_member.organization_id
      AND user_id = v_user_id
      AND role = 'owner'
      AND state = 'active'
  ) THEN
    RAISE EXCEPTION 'Solo el owner puede revocar miembros';
  END IF;

  -- No se puede revocar al propio owner
  IF v_member.role = 'owner' THEN
    RAISE EXCEPTION 'No se puede revocar al owner de la organización';
  END IF;

  IF v_member.state = 'revoked' THEN
    RAISE EXCEPTION 'El miembro ya está revocado';
  END IF;

  UPDATE public.organization_members
  SET state = 'revoked',
      revoked_at = now(),
      revoked_reason = nullif(trim(coalesce(p_reason, '')), '')
  WHERE id = p_member_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_revoked', 'organization_member', p_member_id,
    jsonb_build_object('reason', p_reason));

  RETURN jsonb_build_object('success', true, 'revoked_at', now());
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_revoke_org_member TO authenticated;


-- =====================================================================
-- 5 · sf_update_member_permissions
-- =====================================================================
-- Owner cambia `can_view_economics` de un miembro activo.
DROP FUNCTION IF EXISTS public.sf_update_member_permissions;
CREATE OR REPLACE FUNCTION public.sf_update_member_permissions(
  p_member_id uuid,
  p_can_view_economics boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_member public.organization_members%ROWTYPE;
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

  -- Solo el owner puede cambiar permisos
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
  SET can_view_economics = p_can_view_economics
  WHERE id = p_member_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_perms_updated', 'organization_member', p_member_id,
    jsonb_build_object('can_view_economics', p_can_view_economics));

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_update_member_permissions TO authenticated;


-- =====================================================================
-- 6 · sf_list_my_orgs
-- =====================================================================
-- Devuelve mis organizaciones: la que tengo como owner (si existe) y
-- todas las que soy miembro activo.
DROP FUNCTION IF EXISTS public.sf_list_my_orgs;
CREATE OR REPLACE FUNCTION public.sf_list_my_orgs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_orgs jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', o.id,
    'name', o.name,
    'vat_id', o.vat_id,
    'description', o.description,
    'org_type', o.org_type::text,
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


-- =====================================================================
-- 7 · sf_get_org_members
-- =====================================================================
-- Lista los miembros de una organización. Cualquier miembro activo puede
-- consultar (la lista incluye también pending y revoked para que el owner
-- los gestione, pero solo el owner los ve completos).
DROP FUNCTION IF EXISTS public.sf_get_org_members;
CREATE OR REPLACE FUNCTION public.sf_get_org_members(p_org_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_is_owner boolean;
  v_members jsonb;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  -- Debe ser miembro activo de la org
  IF NOT public.fn_is_org_active_member(p_org_id) THEN
    RAISE EXCEPTION 'No tienes acceso a esta organización';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_org_id
      AND user_id = v_user_id
      AND role = 'owner'
      AND state = 'active'
  ) INTO v_is_owner;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', om.id,
    'user_id', om.user_id,
    'email', om.invited_email,
    'full_name', om.full_name,
    'role', om.role::text,
    'state', om.state::text,
    'can_view_economics', om.can_view_economics,
    'invited_at', om.invited_at,
    'accepted_at', om.accepted_at,
    'revoked_at', om.revoked_at,
    'is_me', (om.user_id = v_user_id)
  ) ORDER BY
    CASE om.state::text WHEN 'active' THEN 1 WHEN 'invited' THEN 2 ELSE 3 END,
    CASE om.role::text  WHEN 'owner' THEN 1 ELSE 2 END,
    om.invited_at ASC
  ), '[]'::jsonb)
  INTO v_members
  FROM public.organization_members om
  WHERE om.organization_id = p_org_id
    AND (
      v_is_owner               -- el owner ve todos (incluido revoked)
      OR om.state = 'active'   -- los miembros solo ven activos
    );

  RETURN jsonb_build_object(
    'organization_id', p_org_id,
    'is_owner_view', v_is_owner,
    'members', v_members
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_org_members TO authenticated;


-- =====================================================================
-- Comentarios y reload
-- =====================================================================
COMMENT ON FUNCTION public.sf_create_organization IS
  'Sprint 6 · Crea una organización. El caller queda como owner activo.';
COMMENT ON FUNCTION public.sf_invite_org_member IS
  'Sprint 6 · Owner invita por email. Devuelve invitation_token para el link.';
COMMENT ON FUNCTION public.sf_accept_org_invite IS
  'Sprint 6 · Miembro acepta con token. Valida que el email coincida con el user autenticado.';
COMMENT ON FUNCTION public.sf_revoke_org_member IS
  'Sprint 6 · Owner revoca miembro activo o cancela invitación pendiente.';
COMMENT ON FUNCTION public.sf_update_member_permissions IS
  'Sprint 6 · Owner cambia can_view_economics.';
COMMENT ON FUNCTION public.sf_list_my_orgs IS
  'Sprint 6 · Lista mis organizaciones (owner + miembro). Incluye counts.';
COMMENT ON FUNCTION public.sf_get_org_members IS
  'Sprint 6 · Lista miembros de una org. Owner ve todos, miembros solo ven activos.';

NOTIFY pgrst, 'reload schema';
