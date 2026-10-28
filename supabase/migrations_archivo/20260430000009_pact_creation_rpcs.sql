-- =====================================================================
-- Sprint 2 chunk 1 · Migration 0011
-- RPCs para creación atómica del pacto desde el wizard.
-- =====================================================================
-- Funciones:
--   sf_create_pact_draft       crea pact en estado 'draft' + parte del creador
--   sf_invite_party            añade promotor/constructor/técnico al pacto
--   sf_add_milestone           añade un hito al plan
--   sf_finalize_pact_draft     valida y pasa el pacto de draft a inviting
-- =====================================================================
-- Notas de diseño:
--   - display_id usa 6 dígitos aleatorios + retry para evitar colisiones
--   - Cast user_role → text → pact_party_role: Postgres no permite cast
--     directo entre dos enums, hay que pasar por text
--   - OUT params prefijados out_* para evitar colisión con columnas `id`
--     o `display_id` de tablas referenciadas dentro de la función
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_create_pact_draft
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_create_pact_draft;
CREATE OR REPLACE FUNCTION public.sf_create_pact_draft(
  p_title text,
  p_obra_address_line text,
  p_total_amount_cents bigint,
  p_description text DEFAULT NULL,
  p_pact_type text DEFAULT 'obra_mayor',
  p_obra_postal_code text DEFAULT NULL,
  p_obra_city text DEFAULT NULL,
  p_obra_province text DEFAULT NULL,
  p_obra_type text DEFAULT 'reforma_integral',
  p_iva_rate_pct numeric DEFAULT 21,
  p_iva_included boolean DEFAULT false,
  p_estimated_start_date date DEFAULT NULL,
  p_estimated_end_date date DEFAULT NULL,
  p_obra_menor_declaration_accepted boolean DEFAULT false
)
RETURNS TABLE(out_pact_id uuid, out_display_id text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_user_role user_role;
  v_pact_id  uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
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

  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o el promotor pueden crear un pacto';
  END IF;

  IF p_pact_type NOT IN ('obra_mayor', 'obra_menor') THEN
    RAISE EXCEPTION 'Tipo de pacto inválido: %', p_pact_type;
  END IF;

  IF p_pact_type = 'obra_menor' AND NOT p_obra_menor_declaration_accepted THEN
    RAISE EXCEPTION 'Para obra menor debes aceptar la declaración responsable';
  END IF;

  -- Generar display_id único con reintentos
  LOOP
    v_display_id := 'PS-PCT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');

    SELECT EXISTS(
      SELECT 1 FROM public.pacts WHERE display_id = v_display_id
    ) INTO v_exists;

    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar un display_id único tras 10 intentos';
    END IF;
  END LOOP;

  INSERT INTO public.pacts (
    display_id, title, description, pact_type,
    obra_address_line, obra_postal_code, obra_city, obra_province,
    obra_type, total_amount_cents, iva_rate_pct, iva_included,
    estimated_start_date, estimated_end_date,
    obra_menor_declaration_accepted_at, obra_menor_declaration_text_hash,
    state, funding_mode, platform_fee_pct, created_by_user_id
  ) VALUES (
    v_display_id, p_title, p_description, p_pact_type::pact_type,
    p_obra_address_line, p_obra_postal_code,
    coalesce(p_obra_city, p_obra_province), p_obra_province,
    p_obra_type, p_total_amount_cents, p_iva_rate_pct, p_iva_included,
    p_estimated_start_date, p_estimated_end_date,
    CASE WHEN p_pact_type = 'obra_menor' THEN now() ELSE NULL END,
    CASE WHEN p_pact_type = 'obra_menor' THEN 'sha256_obra_menor_v1' ELSE NULL END,
    'draft', 'fund_first',
    CASE WHEN p_pact_type = 'obra_menor' THEN 0.80 ELSE 1.00 END,
    v_user_id
  )
  RETURNING pacts.id INTO v_pact_id;

  -- El creador se añade automáticamente como parte (con su rol).
  -- Cast user_role → text → pact_party_role.
  INSERT INTO public.pact_parties (
    pact_id, user_id, role, invited_by_user_id, accepted_at,
    snapshot_full_name, snapshot_email
  )
  SELECT
    v_pact_id, v_user_id,
    (v_user_role::text)::pact_party_role,
    v_user_id, now(),
    u.full_name, u.email
  FROM public.users u WHERE u.id = v_user_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_draft_created', 'pact', v_pact_id,
    jsonb_build_object('display_id', v_display_id, 'pact_type', p_pact_type));

  out_pact_id := v_pact_id;
  out_display_id := v_display_id;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_create_pact_draft TO authenticated;


-- ---------------------------------------------------------------------
-- sf_invite_party
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_invite_party;
CREATE OR REPLACE FUNCTION public.sf_invite_party(
  p_pact_id uuid,
  p_role text,
  p_email text,
  p_full_name text,
  p_phone text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_party_id uuid;
  v_existing_user_id uuid;
  v_pact_state pact_state;
  v_pact_type pact_type;
  v_creator_id uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT state, pact_type, created_by_user_id
  INTO v_pact_state, v_pact_type, v_creator_id
  FROM public.pacts WHERE id = p_pact_id;

  IF v_pact_state IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact_state NOT IN ('draft') THEN
    RAISE EXCEPTION 'Solo puedes invitar partes en estado draft (estado actual: %)', v_pact_state;
  END IF;
  IF v_creator_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador del pacto puede invitar partes';
  END IF;

  IF p_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RAISE EXCEPTION 'Rol inválido: %', p_role;
  END IF;
  IF v_pact_type = 'obra_menor' AND p_role = 'tecnico' THEN
    RAISE EXCEPTION 'Obra menor no requiere técnico';
  END IF;

  SELECT id INTO v_existing_user_id
  FROM public.users
  WHERE lower(email) = lower(p_email) AND deleted_at IS NULL
  LIMIT 1;

  INSERT INTO public.pact_parties (
    pact_id, user_id, role, invited_by_user_id,
    snapshot_full_name, snapshot_email
  ) VALUES (
    p_pact_id, v_existing_user_id, p_role::pact_party_role,
    v_caller_id, p_full_name, lower(p_email)
  )
  RETURNING id INTO v_party_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_caller_id, 'pact_party_invited', 'pact', p_pact_id,
    jsonb_build_object('role', p_role, 'email', p_email,
      'existing_user', v_existing_user_id IS NOT NULL));

  RETURN v_party_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_invite_party TO authenticated;


-- ---------------------------------------------------------------------
-- sf_add_milestone
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_add_milestone;
CREATE OR REPLACE FUNCTION public.sf_add_milestone(
  p_pact_id uuid,
  p_ordinal smallint,
  p_name text,
  p_amount_cents bigint,
  p_description text DEFAULT NULL,
  p_target_date date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_milestone_id uuid;
  v_pact_state pact_state;
  v_creator_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
BEGIN
  v_auth_uid := auth.uid();
  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT state, created_by_user_id INTO v_pact_state, v_creator_id
  FROM public.pacts WHERE id = p_pact_id;

  IF v_pact_state IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact_state != 'draft' THEN
    RAISE EXCEPTION 'Solo puedes añadir hitos en estado draft';
  END IF;
  IF v_creator_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede añadir hitos';
  END IF;

  IF p_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El importe mínimo por hito es 500 €';
  END IF;

  LOOP
    v_display_id := 'PS-HIT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');

    SELECT EXISTS(
      SELECT 1 FROM public.milestones WHERE display_id = v_display_id
    ) INTO v_exists;

    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único para hito';
    END IF;
  END LOOP;

  INSERT INTO public.milestones (
    pact_id, display_id, ordinal, name, description,
    amount_cents, target_date, state
  ) VALUES (
    p_pact_id, v_display_id, p_ordinal, p_name, p_description,
    p_amount_cents, p_target_date, 'pending'
  )
  RETURNING id INTO v_milestone_id;

  RETURN v_milestone_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_add_milestone TO authenticated;


-- ---------------------------------------------------------------------
-- sf_finalize_pact_draft
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_finalize_pact_draft;
CREATE OR REPLACE FUNCTION public.sf_finalize_pact_draft(
  p_pact_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_total_milestones bigint;
  v_total_milestones_amount bigint;
  v_party_count int;
  v_required_parties int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;

  IF v_pact.id IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact.created_by_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede finalizar el pacto';
  END IF;
  IF v_pact.state != 'draft' THEN
    RAISE EXCEPTION 'El pacto no está en estado draft';
  END IF;

  SELECT count(*), coalesce(sum(amount_cents), 0)
  INTO v_total_milestones, v_total_milestones_amount
  FROM public.milestones WHERE pact_id = p_pact_id;

  IF v_total_milestones < 1 THEN
    RAISE EXCEPTION 'El pacto debe tener al menos 1 hito';
  END IF;

  IF v_total_milestones_amount != v_pact.total_amount_cents THEN
    RAISE EXCEPTION 'La suma de hitos (%) no coincide con el total del pacto (%)',
      v_total_milestones_amount, v_pact.total_amount_cents;
  END IF;

  v_required_parties := CASE WHEN v_pact.pact_type = 'obra_mayor' THEN 3 ELSE 2 END;
  SELECT count(*) INTO v_party_count FROM public.pact_parties WHERE pact_id = p_pact_id;

  IF v_party_count != v_required_parties THEN
    RAISE EXCEPTION 'Se requieren % partes para % (actual: %)',
      v_required_parties, v_pact.pact_type, v_party_count;
  END IF;

  UPDATE public.pacts SET state = 'inviting' WHERE id = p_pact_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_caller_id, 'pact_finalized', 'pact', p_pact_id);

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_finalized',
    jsonb_build_object(
      'total_amount_cents', v_pact.total_amount_cents,
      'milestones', v_total_milestones,
      'parties', v_party_count
    ),
    v_caller_id);

  RETURN p_pact_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_finalize_pact_draft TO authenticated;


COMMENT ON FUNCTION public.sf_create_pact_draft IS
  'Sprint 2 chunk 1: crea pact draft con creador como primera parte. display_id con 6 dígitos + retry.';
COMMENT ON FUNCTION public.sf_invite_party IS
  'Añade una parte al pacto. Si el email tiene cuenta PactStream, vincula. Si no, queda pendiente.';
COMMENT ON FUNCTION public.sf_finalize_pact_draft IS
  'Valida draft (hitos suman total, partes correctas) y transiciona a inviting.';
