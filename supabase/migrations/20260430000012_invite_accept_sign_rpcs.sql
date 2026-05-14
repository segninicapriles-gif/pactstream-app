-- =====================================================================
-- Sprint 2 chunk 3 · Migration 0014
-- Aceptar invitación, firmar contrato, vincular usuarios invitados.
-- =====================================================================
-- Funciones:
--   sf_accept_invitation(p_pact_id)
--     Marca pact_parties.accepted_at = now() para el caller.
--     Si todas las partes aceptaron, pact pasa de inviting → signing.
--
--   sf_sign_contract(p_pact_id, p_consent_text_hash, p_user_agent)
--     Marca pact_parties.signed_at + signature_state = signed.
--     Guarda evidencia legal (timestamp, IP no la tenemos en RPC, pero
--     guardamos user_agent y un hash del texto consentido).
--     Si todos firmaron, pact pasa de signing → signed.
--
--   handle_link_pending_invitations()
--     Trigger AFTER INSERT en users que vincula pact_parties con
--     snapshot_email == new.email y user_id IS NULL al usuario recién
--     registrado. Resuelve el caso: invitación enviada antes de que el
--     usuario tuviera cuenta.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_accept_invitation
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_accept_invitation;
CREATE OR REPLACE FUNCTION public.sf_accept_invitation(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_party    public.pact_parties%ROWTYPE;
  v_pact_state pact_state;
  v_total_parties int;
  v_accepted_parties int;
  v_new_state pact_state;
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

  -- Encontrar mi parte en el pacto
  SELECT * INTO v_party
  FROM public.pact_parties pp
  WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id;

  IF v_party.id IS NULL THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  IF v_party.accepted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Ya aceptaste esta invitación';
  END IF;

  -- Validar estado del pacto
  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state NOT IN ('inviting', 'signing') THEN
    RAISE EXCEPTION 'No se puede aceptar invitación en estado: %', v_pact_state;
  END IF;

  -- Marcar aceptación
  UPDATE public.pact_parties
  SET accepted_at = now()
  WHERE id = v_party.id;

  -- Si todas las partes aceptaron y estamos en inviting, pasar a signing
  SELECT count(*), count(*) FILTER (WHERE accepted_at IS NOT NULL)
  INTO v_total_parties, v_accepted_parties
  FROM public.pact_parties WHERE pact_id = p_pact_id;

  v_new_state := v_pact_state;

  IF v_pact_state = 'inviting' AND v_accepted_parties = v_total_parties THEN
    UPDATE public.pacts SET state = 'signing' WHERE id = p_pact_id;
    v_new_state := 'signing';

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (p_pact_id, 'all_parties_accepted',
      jsonb_build_object('parties_count', v_total_parties),
      v_user_id);
  END IF;

  -- Audit
  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'invitation_accepted', 'pact', p_pact_id,
    jsonb_build_object('role', v_party.role::text));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', v_new_state::text,
    'all_accepted', v_accepted_parties = v_total_parties
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_accept_invitation TO authenticated;


-- ---------------------------------------------------------------------
-- sf_sign_contract
-- ---------------------------------------------------------------------
-- Firma "consentimiento explícito" (mock pre-Signaturit).
-- Guardamos:
--   - signed_at (timestamp legal)
--   - signature_state = 'signed'
--   - signaturit_signature_id (puede ser un hash compuesto que
--     identifique el evento en logs; cuando integremos Signaturit real,
--     lo sustituiremos por el id de la API).
DROP FUNCTION IF EXISTS public.sf_sign_contract;
CREATE OR REPLACE FUNCTION public.sf_sign_contract(
  p_pact_id uuid,
  p_consent_text_hash text,
  p_user_agent text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_party    public.pact_parties%ROWTYPE;
  v_pact_state pact_state;
  v_total_parties int;
  v_signed_parties int;
  v_new_state pact_state;
  v_signature_id text;
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

  SELECT * INTO v_party
  FROM public.pact_parties pp
  WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id;

  IF v_party.id IS NULL THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  IF v_party.accepted_at IS NULL THEN
    RAISE EXCEPTION 'Debes aceptar la invitación antes de firmar';
  END IF;

  IF v_party.signed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Ya firmaste este contrato';
  END IF;

  -- Validar estado del pacto: signing (preferido) o inviting (si todos
  -- aceptaron justo ahora; raro pero posible si race condition).
  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state NOT IN ('signing', 'inviting') THEN
    RAISE EXCEPTION 'No se puede firmar en estado: %', v_pact_state;
  END IF;

  -- Generar identificador de firma (mock). Formato:
  --   PS-SIG-{pact_id_short}-{user_id_short}-{epoch}
  v_signature_id := 'PS-SIG-' ||
    substring(p_pact_id::text, 1, 8) || '-' ||
    substring(v_user_id::text, 1, 8) || '-' ||
    extract(epoch from now())::bigint::text;

  -- Marcar firma
  UPDATE public.pact_parties
  SET
    signed_at = now(),
    signature_state = 'signed',
    signaturit_signature_id = v_signature_id,
    snapshot_role_data = coalesce(snapshot_role_data, '{}'::jsonb) ||
      jsonb_build_object(
        'signature_method', 'consent_explicit_v1',
        'consent_text_hash', p_consent_text_hash,
        'user_agent', p_user_agent,
        'signed_at_iso', now()::text
      )
  WHERE id = v_party.id;

  -- ¿Firmaron todos?
  SELECT count(*), count(*) FILTER (WHERE signed_at IS NOT NULL)
  INTO v_total_parties, v_signed_parties
  FROM public.pact_parties WHERE pact_id = p_pact_id;

  v_new_state := v_pact_state;

  IF v_signed_parties = v_total_parties THEN
    UPDATE public.pacts SET state = 'signed' WHERE id = p_pact_id;
    v_new_state := 'signed';

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (p_pact_id, 'contract_fully_signed',
      jsonb_build_object('parties_count', v_total_parties),
      v_user_id);
  END IF;

  -- Audit
  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'contract_signed', 'pact', p_pact_id,
    jsonb_build_object(
      'role', v_party.role::text,
      'signature_id', v_signature_id,
      'consent_text_hash', p_consent_text_hash
    ));

  RETURN jsonb_build_object(
    'success', true,
    'signature_id', v_signature_id,
    'pact_state', v_new_state::text,
    'all_signed', v_signed_parties = v_total_parties
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_sign_contract TO authenticated;


-- ---------------------------------------------------------------------
-- handle_link_pending_invitations()
-- ---------------------------------------------------------------------
-- Cuando un usuario se inserta en public.users (vía handle_new_auth_user),
-- buscamos invitaciones pendientes con su email y las vinculamos.
-- Esto resuelve: "invité a alguien que aún no tenía cuenta; cuando se
-- registre, ¿cómo sabe qué pactos le pertenecen?"
CREATE OR REPLACE FUNCTION public.handle_link_pending_invitations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email IS NULL THEN
    RETURN NEW;
  END IF;

  -- Vincular invitaciones huérfanas que coinciden por email
  UPDATE public.pact_parties
  SET user_id = NEW.id
  WHERE user_id IS NULL
    AND lower(snapshot_email) = lower(NEW.email::text);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_link_pending_invitations ON public.users;
CREATE TRIGGER trg_link_pending_invitations
  AFTER INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_link_pending_invitations();


-- ---------------------------------------------------------------------
-- Comentarios
-- ---------------------------------------------------------------------
COMMENT ON FUNCTION public.sf_accept_invitation IS
  'El caller acepta su parte del pacto. Cuando todos aceptan, pact pasa inviting → signing.';
COMMENT ON FUNCTION public.sf_sign_contract IS
  'Firma con consentimiento explícito (pre-Signaturit). Cuando todos firman, pact pasa signing → signed. Guarda evidencia legal en snapshot_role_data.';
COMMENT ON FUNCTION public.handle_link_pending_invitations IS
  'Trigger AFTER INSERT users: vincula pact_parties huérfanos con snapshot_email coincidente.';

NOTIFY pgrst, 'reload schema';
