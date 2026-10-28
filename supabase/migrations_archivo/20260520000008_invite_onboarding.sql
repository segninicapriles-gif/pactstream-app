-- =====================================================================
-- Polish #26 · Onboarding simplificado para miembros invitados
-- =====================================================================
--   * sf_get_invite_preview · RPC pública (anon) que devuelve datos
--     mínimos de una invitación pendiente para que el wizard pueda
--     pre-rellenar+bloquear email y mostrar contexto de la org.
--   * users.primary_role pasa a NULLable para soportar miembros de
--     equipo sin rol propio en PactStream.
--   * handle_new_auth_user reconoce `invitation_token` en metadata y
--     crea public.users sin role/org. La aceptación real la sigue
--     haciendo sf_accept_org_invite tras la verificación de email.
-- =====================================================================


DROP FUNCTION IF EXISTS public.sf_get_invite_preview;
CREATE OR REPLACE FUNCTION public.sf_get_invite_preview(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member public.organization_members%ROWTYPE;
  v_org    public.organizations%ROWTYPE;
  v_inviter_name text;
BEGIN
  SELECT * INTO v_member FROM public.organization_members
  WHERE invitation_token = p_token AND state = 'invited';

  IF v_member.id IS NULL THEN
    RETURN jsonb_build_object('valid', false);
  END IF;

  SELECT * INTO v_org FROM public.organizations
  WHERE id = v_member.organization_id;

  SELECT full_name INTO v_inviter_name FROM public.users
  WHERE id = v_member.invited_by_user_id;

  RETURN jsonb_build_object(
    'valid', true,
    'member_id', v_member.id,
    'invited_email', v_member.invited_email,
    'full_name', v_member.full_name,
    'can_view_economics', v_member.can_view_economics,
    'org_name', coalesce(v_org.trade_name, v_org.legal_name),
    'org_type', v_org.org_type,
    'inviter_name', v_inviter_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_invite_preview TO anon, authenticated;


ALTER TABLE public.users
  ALTER COLUMN primary_role DROP NOT NULL;

COMMENT ON COLUMN public.users.primary_role IS
  'Rol primario. NULL para usuarios creados vía invitación a una '
  'organización (no son protagonistas de pactos, sólo miembros).';


CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_meta             jsonb;
  v_user_id          uuid;
  v_org_id           uuid;
  v_role             text;
  v_invitation_token uuid;
BEGIN
  v_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  v_role := v_meta->>'primary_role';

  BEGIN
    v_invitation_token := (v_meta->>'invitation_token')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_invitation_token := NULL;
  END;

  IF v_invitation_token IS NOT NULL THEN
    INSERT INTO public.users (
      auth_provider_id,
      full_name,
      email,
      phone_e164,
      primary_role,
      organization_id,
      kyc_status
    ) VALUES (
      NEW.id::text,
      COALESCE(v_meta->>'full_name', NEW.email),
      NEW.email,
      v_meta->>'phone_e164',
      NULL,
      NULL,
      'not_started'
    )
    RETURNING id INTO v_user_id;

    INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
    VALUES
      (v_user_id, 'terms_of_service',
       COALESCE(v_meta->>'terms_version', '1.0'),
       'sha256_placeholder_terms'),
      (v_user_id, 'privacy_policy',
       COALESCE(v_meta->>'privacy_version', '1.0'),
       'sha256_placeholder_privacy');

    INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
    VALUES (v_user_id, 'user_registered_via_invite', 'user', v_user_id,
      jsonb_build_object('invitation_token', v_invitation_token));

    RETURN NEW;
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RETURN NEW;
  END IF;

  IF v_role = 'constructor' AND COALESCE(v_meta->>'organization_name', '') <> '' THEN
    INSERT INTO public.organizations (legal_name, cif, province)
    VALUES (
      v_meta->>'organization_name',
      v_meta->>'cif_or_nif',
      v_meta->>'province'
    )
    RETURNING id INTO v_org_id;
  END IF;

  INSERT INTO public.users (
    auth_provider_id,
    full_name,
    email,
    phone_e164,
    national_id,
    province,
    primary_role,
    profession,
    colegio,
    num_colegiacion,
    organization_id,
    kyc_status
  ) VALUES (
    NEW.id::text,
    COALESCE(v_meta->>'full_name', NEW.email),
    NEW.email,
    v_meta->>'phone_e164',
    CASE WHEN v_role IN ('promotor', 'tecnico') THEN v_meta->>'cif_or_nif' END,
    v_meta->>'province',
    v_role::user_role,
    v_meta->>'profession',
    v_meta->>'colegio',
    v_meta->>'num_colegiacion',
    v_org_id,
    'not_started'
  )
  RETURNING id INTO v_user_id;

  INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
  VALUES
    (v_user_id, 'terms_of_service',
     COALESCE(v_meta->>'terms_version', '1.0'),
     'sha256_placeholder_terms'),
    (v_user_id, 'privacy_policy',
     COALESCE(v_meta->>'privacy_version', '1.0'),
     'sha256_placeholder_privacy');

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_user_id, 'user_registered', 'user', v_user_id);

  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
