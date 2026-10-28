-- =====================================================================
-- Sprint 4 chunk 2 · Migration 0023
-- RPCs del modelo v2.0
-- =====================================================================
-- 10 RPCs nuevas para el modelo de certificaciones por demanda:
--   1. sf_create_pact_v2            crear pact (sin hitos predefinidos)
--   2. sf_finalize_pact_v2          finalizar borrador y pasar a inviting
--   3. sf_pact_fund_initial         promotor deposita el % inicial
--   4. sf_constructor_create_cert   constructor crea certificación
--   5. sf_constructor_edit_cert     edita certificación rechazada (versionado)
--   6. sf_attach_cert_invoice       adjunta factura obligatoria
--   7. sf_attach_cert_doc           adjunta documento detallado
--   8. sf_pact_replenish_deposit    promotor repone el depósito
--   9. sf_addendum_create           propone anexo al pacto
--  10. sf_addendum_sign             firma anexo (cada parte)
--
-- Las RPCs v1 se mantienen para los pacts existentes.
-- =====================================================================


-- =====================================================================
-- 1 · sf_create_pact_v2
-- =====================================================================
-- Crea un pacto v2 sin hitos predefinidos. Acepta deposit_required_pct (15-40)
-- y certification_frequency_text. El creador (técnico o promotor) se añade
-- como primera parte automáticamente.
DROP FUNCTION IF EXISTS public.sf_create_pact_v2;
CREATE OR REPLACE FUNCTION public.sf_create_pact_v2(
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
  p_deposit_required_pct numeric DEFAULT 30,
  p_certification_frequency text DEFAULT NULL,
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

  IF p_deposit_required_pct NOT BETWEEN 15 AND 40 THEN
    RAISE EXCEPTION 'El depósito debe estar entre el 15%% y el 40%% (recibido: %%%)', p_deposit_required_pct;
  END IF;

  IF p_total_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El presupuesto mínimo del pacto es 500 €';
  END IF;

  IF p_pact_type = 'obra_menor' AND NOT p_obra_menor_declaration_accepted THEN
    RAISE EXCEPTION 'Para obra menor debes aceptar la declaración responsable';
  END IF;

  -- Generar display_id único con reintentos
  LOOP
    v_display_id := 'PS-PCT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.pacts WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.pacts (
    display_id, title, description, pact_type,
    obra_address_line, obra_postal_code, obra_city, obra_province,
    obra_type, total_amount_cents, iva_rate_pct, iva_included,
    estimated_start_date, estimated_end_date,
    obra_menor_declaration_accepted_at, obra_menor_declaration_text_hash,
    state, funding_mode, platform_fee_pct, created_by_user_id,
    -- Campos v2.0
    deposit_required_pct,
    certification_frequency_text,
    model_version
  ) VALUES (
    v_display_id, p_title, p_description, p_pact_type::pact_type,
    p_obra_address_line, p_obra_postal_code,
    coalesce(p_obra_city, p_obra_province), p_obra_province,
    p_obra_type, p_total_amount_cents, p_iva_rate_pct, p_iva_included,
    p_estimated_start_date, p_estimated_end_date,
    CASE WHEN p_pact_type = 'obra_menor' THEN now() ELSE NULL END,
    CASE WHEN p_pact_type = 'obra_menor' THEN 'sha256_obra_menor_v2' ELSE NULL END,
    'draft', 'fund_first',
    CASE WHEN p_pact_type = 'obra_menor' THEN 0.80 ELSE 1.00 END,
    v_user_id,
    p_deposit_required_pct,
    p_certification_frequency,
    'v2'
  )
  RETURNING pacts.id INTO v_pact_id;

  -- Creador como primera parte
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
  VALUES (v_user_id, 'pact_v2_created', 'pact', v_pact_id,
    jsonb_build_object(
      'display_id', v_display_id,
      'pact_type', p_pact_type,
      'deposit_pct', p_deposit_required_pct,
      'total_cents', p_total_amount_cents
    ));

  out_pact_id := v_pact_id;
  out_display_id := v_display_id;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_create_pact_v2 TO authenticated;


-- =====================================================================
-- 2 · sf_finalize_pact_v2
-- =====================================================================
-- Valida draft v2 y lo transiciona a 'inviting'.
-- A diferencia del v1, NO valida sum(milestones)==total (en v2 no hay hitos
-- al inicio). Solo valida partes correctas según pact_type.
DROP FUNCTION IF EXISTS public.sf_finalize_pact_v2;
CREATE OR REPLACE FUNCTION public.sf_finalize_pact_v2(p_pact_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_pact public.pacts%ROWTYPE;
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
    RAISE EXCEPTION 'El pacto no está en estado draft (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'sf_finalize_pact_v2 solo aplica a pacts v2. Usa sf_finalize_pact_draft para v1.';
  END IF;

  v_required_parties := CASE WHEN v_pact.pact_type = 'obra_mayor' THEN 3 ELSE 2 END;
  SELECT count(*) INTO v_party_count FROM public.pact_parties WHERE pact_id = p_pact_id;

  IF v_party_count != v_required_parties THEN
    RAISE EXCEPTION 'Se requieren % partes para % (actual: %)',
      v_required_parties, v_pact.pact_type, v_party_count;
  END IF;

  UPDATE public.pacts SET state = 'inviting' WHERE id = p_pact_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_caller_id, 'pact_v2_finalized', 'pact', p_pact_id);

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_finalized',
    jsonb_build_object(
      'model_version', 'v2',
      'total_amount_cents', v_pact.total_amount_cents,
      'deposit_required_pct', v_pact.deposit_required_pct,
      'parties', v_party_count
    ),
    v_caller_id);

  RETURN p_pact_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_finalize_pact_v2 TO authenticated;


-- =====================================================================
-- 3 · sf_pact_fund_initial
-- =====================================================================
-- Promotor confirma el depósito inicial (% pactado del presupuesto).
-- Hito 0 del modelo v2. Pact: signed → funded → in_execution.
DROP FUNCTION IF EXISTS public.sf_pact_fund_initial;
CREATE OR REPLACE FUNCTION public.sf_pact_fund_initial(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_deposit_required_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede depositar el adelanto inicial';
  END IF;

  IF v_pact.state != 'signed' THEN
    RAISE EXCEPTION 'El pacto no está en estado signed (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'sf_pact_fund_initial solo aplica a pacts v2';
  END IF;

  v_deposit_required_cents := (v_pact.total_amount_cents * v_pact.deposit_required_pct / 100)::bigint;

  -- Transiciones state machine: signed → funded → in_execution
  UPDATE public.pacts
  SET state = 'funded',
      deposit_current_cents = v_deposit_required_cents
  WHERE id = p_pact_id;

  UPDATE public.pacts
  SET state = 'in_execution'
  WHERE id = p_pact_id;

  -- Registrar movimiento de depósito
  INSERT INTO public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    balance_before_cents, balance_after_cents, notes
  ) VALUES (
    p_pact_id, 'initial_deposit', v_deposit_required_cents, v_user_id,
    0, v_deposit_required_cents,
    'Depósito inicial · ' || v_pact.deposit_required_pct || '% del presupuesto'
  );

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_funded',
    jsonb_build_object(
      'deposit_pct', v_pact.deposit_required_pct,
      'deposit_cents', v_deposit_required_cents
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_fund_initial', 'pact', p_pact_id,
    jsonb_build_object('deposit_cents', v_deposit_required_cents));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', 'in_execution',
    'deposit_cents', v_deposit_required_cents,
    'deposit_pct', v_pact.deposit_required_pct
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_pact_fund_initial TO authenticated;


-- =====================================================================
-- 4 · sf_constructor_create_cert
-- =====================================================================
-- Constructor crea una certificación. Solo en pact v2 in_execution.
-- Asigna ordinal correlativo automáticamente. Estado inicial: in_execution.
DROP FUNCTION IF EXISTS public.sf_constructor_create_cert;
CREATE OR REPLACE FUNCTION public.sf_constructor_create_cert(
  p_pact_id uuid,
  p_name text,
  p_amount_cents bigint,
  p_description text DEFAULT NULL
)
RETURNS TABLE(out_cert_id uuid, out_display_id text, out_ordinal smallint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_cert_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
  v_next_ordinal smallint;
  v_remaining_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'Esta RPC solo aplica a pacts v2';
  END IF;
  IF v_pact.state != 'in_execution' THEN
    RAISE EXCEPTION 'El pacto no está en ejecución (estado: %)', v_pact.state;
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede crear certificaciones';
  END IF;

  IF p_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El importe mínimo de una certificación es 500 €';
  END IF;

  -- Validar techo de presupuesto: lo certificable es total - ya pagado - ya en curso
  SELECT v_pact.total_amount_cents - v_pact.budget_consumed_cents -
    coalesce((SELECT sum(amount_cents) FROM public.milestones
              WHERE pact_id = p_pact_id AND state NOT IN ('paid')), 0)
  INTO v_remaining_cents;

  IF p_amount_cents > v_remaining_cents THEN
    RAISE EXCEPTION 'La certificación excede el presupuesto disponible (% €)', v_remaining_cents / 100;
  END IF;

  -- Calcular próximo ordinal
  SELECT coalesce(max(ordinal), 0) + 1 INTO v_next_ordinal
  FROM public.milestones WHERE pact_id = p_pact_id;

  -- Generar display_id único
  LOOP
    v_display_id := 'PS-CERT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.milestones WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.milestones (
    pact_id, display_id, ordinal, name, description,
    amount_cents, state, version, started_at
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal, p_name, p_description,
    p_amount_cents, 'in_execution', 1, now()
  )
  RETURNING id INTO v_cert_id;

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'certification_created',
    jsonb_build_object(
      'cert_id', v_cert_id,
      'ordinal', v_next_ordinal,
      'amount_cents', p_amount_cents,
      'name', p_name
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'certification_created', 'milestone', v_cert_id,
    jsonb_build_object('ordinal', v_next_ordinal, 'amount_cents', p_amount_cents));

  out_cert_id := v_cert_id;
  out_display_id := v_display_id;
  out_ordinal := v_next_ordinal;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_constructor_create_cert TO authenticated;


-- =====================================================================
-- 5 · sf_constructor_edit_cert
-- =====================================================================
-- Constructor edita una certificación tras rechazo. Incrementa version.
-- Guarda snapshot completo de la versión anterior en pact_events.
DROP FUNCTION IF EXISTS public.sf_constructor_edit_cert;
CREATE OR REPLACE FUNCTION public.sf_constructor_edit_cert(
  p_cert_id uuid,
  p_name text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_amount_cents bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_cert public.milestones%ROWTYPE;
  v_user_role pact_party_role;
  v_snapshot jsonb;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_cert FROM public.milestones WHERE id = p_cert_id;
  IF v_cert.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_cert.pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede editar la certificación';
  END IF;

  IF v_cert.state NOT IN ('rejected_by_tech', 'info_requested', 'in_execution') THEN
    RAISE EXCEPTION 'No se puede editar una certificación en estado %', v_cert.state;
  END IF;

  -- Snapshot de la versión actual en pact_events ANTES de modificar
  v_snapshot := jsonb_build_object(
    'cert_id', v_cert.id,
    'version_before', v_cert.version,
    'name_before', v_cert.name,
    'description_before', v_cert.description,
    'amount_cents_before', v_cert.amount_cents
  );

  -- Aplicar cambios
  UPDATE public.milestones
  SET
    name = coalesce(p_name, name),
    description = coalesce(p_description, description),
    amount_cents = coalesce(p_amount_cents, amount_cents),
    version = version + 1,
    state = CASE WHEN state IN ('rejected_by_tech', 'info_requested')
                 THEN 'in_execution'::milestone_state
                 ELSE state END
  WHERE id = p_cert_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_cert.pact_id, 'certification_edited', v_snapshot, v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'new_version', v_cert.version + 1,
    'new_state', 'in_execution'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_constructor_edit_cert TO authenticated;


-- =====================================================================
-- 6 · sf_attach_cert_invoice
-- =====================================================================
-- Constructor adjunta la factura. OBLIGATORIA para enviar a revisión.
DROP FUNCTION IF EXISTS public.sf_attach_cert_invoice;
CREATE OR REPLACE FUNCTION public.sf_attach_cert_invoice(
  p_cert_id uuid,
  p_storage_path text,
  p_sha256 text,
  p_invoice_number text,
  p_size_bytes bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_cert public.milestones%ROWTYPE;
  v_user_role pact_party_role;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_cert FROM public.milestones WHERE id = p_cert_id;
  IF v_cert.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_cert.pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede adjuntar la factura';
  END IF;

  IF v_cert.state NOT IN ('in_execution', 'ready_for_review', 'rejected_by_tech', 'info_requested') THEN
    RAISE EXCEPTION 'No se puede adjuntar factura en estado %', v_cert.state;
  END IF;

  UPDATE public.milestones
  SET invoice_storage_path = p_storage_path,
      invoice_sha256 = p_sha256,
      invoice_number = p_invoice_number,
      invoice_size_bytes = p_size_bytes
  WHERE id = p_cert_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_cert.pact_id, 'invoice_attached',
    jsonb_build_object(
      'cert_id', p_cert_id,
      'invoice_number', p_invoice_number,
      'sha256', p_sha256
    ),
    v_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_attach_cert_invoice TO authenticated;


-- =====================================================================
-- 7 · sf_attach_cert_doc
-- =====================================================================
-- Constructor adjunta documento detallado (opcional; obligatorio obra mayor > 50K€)
DROP FUNCTION IF EXISTS public.sf_attach_cert_doc;
CREATE OR REPLACE FUNCTION public.sf_attach_cert_doc(
  p_cert_id uuid,
  p_storage_path text,
  p_sha256 text,
  p_mime_type text,
  p_size_bytes bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_cert public.milestones%ROWTYPE;
  v_user_role pact_party_role;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_cert FROM public.milestones WHERE id = p_cert_id;
  IF v_cert.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_cert.pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede adjuntar documento';
  END IF;

  IF v_cert.state NOT IN ('in_execution', 'ready_for_review', 'rejected_by_tech', 'info_requested') THEN
    RAISE EXCEPTION 'No se puede adjuntar documento en estado %', v_cert.state;
  END IF;

  UPDATE public.milestones
  SET detailed_doc_storage_path = p_storage_path,
      detailed_doc_sha256 = p_sha256,
      detailed_doc_mime_type = p_mime_type,
      detailed_doc_size_bytes = p_size_bytes
  WHERE id = p_cert_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_attach_cert_doc TO authenticated;


-- =====================================================================
-- 8 · sf_pact_replenish_deposit
-- =====================================================================
-- Promotor repone el depósito tras una certificación aprobada.
-- En MVP: el promotor declara haber transferido el dinero (en producción
-- con Mangopay esto se haría tras confirmar el ingreso vía webhook).
DROP FUNCTION IF EXISTS public.sf_pact_replenish_deposit;
CREATE OR REPLACE FUNCTION public.sf_pact_replenish_deposit(
  p_pact_id uuid,
  p_amount_cents bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_balance_before bigint;
  v_balance_after bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede reponer el depósito';
  END IF;

  IF p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'El importe a reponer debe ser positivo';
  END IF;

  v_balance_before := v_pact.deposit_current_cents;
  v_balance_after := v_balance_before + p_amount_cents;

  UPDATE public.pacts
  SET deposit_current_cents = v_balance_after
  WHERE id = p_pact_id;

  INSERT INTO public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    balance_before_cents, balance_after_cents, notes
  ) VALUES (
    p_pact_id, 'replenishment', p_amount_cents, v_user_id,
    v_balance_before, v_balance_after,
    'Reposición voluntaria del promotor'
  );

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'deposit_replenished',
    jsonb_build_object('amount_cents', p_amount_cents,
                       'new_balance', v_balance_after),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'new_balance_cents', v_balance_after
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_pact_replenish_deposit TO authenticated;


-- =====================================================================
-- 9 · sf_addendum_create
-- =====================================================================
-- Propone un anexo al pacto. Lo puede crear cualquier parte (con su rol).
-- Estado inicial: 'proposed' · Pendiente firma de las partes.
DROP FUNCTION IF EXISTS public.sf_addendum_create;
CREATE OR REPLACE FUNCTION public.sf_addendum_create(
  p_pact_id uuid,
  p_title text,
  p_extra_amount_cents bigint,
  p_description text DEFAULT NULL,
  p_extra_days smallint DEFAULT 0,
  p_justification text DEFAULT NULL,
  p_detailed_doc_storage_path text DEFAULT NULL,
  p_detailed_doc_sha256 text DEFAULT NULL,
  p_detailed_doc_mime_type text DEFAULT NULL,
  p_detailed_doc_size_bytes bigint DEFAULT NULL
)
RETURNS TABLE(out_addendum_id uuid, out_display_id text, out_ordinal smallint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_addendum_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
  v_next_ordinal smallint;
  v_new_total bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'Los anexos solo aplican a pacts v2';
  END IF;
  IF v_pact.state NOT IN ('in_execution', 'paused_pending_tech') THEN
    RAISE EXCEPTION 'Solo se pueden crear anexos con el pacto en ejecución';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No formas parte del pacto';
  END IF;

  -- Validar que el nuevo presupuesto no sea negativo
  v_new_total := v_pact.total_amount_cents + p_extra_amount_cents;
  IF v_new_total < 0 THEN
    RAISE EXCEPTION 'El anexo dejaría el presupuesto en negativo';
  END IF;

  -- Documento detallado obligatorio si extra > 10.000€
  IF abs(p_extra_amount_cents) > 1000000 AND p_detailed_doc_storage_path IS NULL THEN
    RAISE EXCEPTION 'Para anexos > 10.000 € es obligatorio adjuntar documento detallado';
  END IF;

  -- Calcular ordinal
  SELECT coalesce(max(ordinal), 0) + 1 INTO v_next_ordinal
  FROM public.pact_addendums WHERE pact_id = p_pact_id;

  -- Generar display_id
  LOOP
    v_display_id := 'PS-ANX-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.pact_addendums WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.pact_addendums (
    pact_id, display_id, ordinal,
    title, description, extra_amount_cents, extra_days, justification,
    detailed_doc_storage_path, detailed_doc_sha256, detailed_doc_mime_type, detailed_doc_size_bytes,
    proposed_by_user_id, proposed_by_role, state
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal,
    p_title, p_description, p_extra_amount_cents, p_extra_days, p_justification,
    p_detailed_doc_storage_path, p_detailed_doc_sha256, p_detailed_doc_mime_type, p_detailed_doc_size_bytes,
    v_user_id, v_user_role, 'proposed'
  )
  RETURNING id INTO v_addendum_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'addendum_proposed',
    jsonb_build_object(
      'addendum_id', v_addendum_id,
      'ordinal', v_next_ordinal,
      'extra_amount_cents', p_extra_amount_cents,
      'proposed_by_role', v_user_role::text
    ),
    v_user_id);

  out_addendum_id := v_addendum_id;
  out_display_id := v_display_id;
  out_ordinal := v_next_ordinal;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_addendum_create TO authenticated;


-- =====================================================================
-- 10 · sf_addendum_sign
-- =====================================================================
-- Cada parte firma el anexo. Cuando todas firman, el anexo pasa a 'active'
-- y el trigger handle_addendum_active actualiza el total_amount_cents.
DROP FUNCTION IF EXISTS public.sf_addendum_sign;
CREATE OR REPLACE FUNCTION public.sf_addendum_sign(p_addendum_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_addendum public.pact_addendums%ROWTYPE;
  v_pact_type pact_type;
  v_required_sigs int;
  v_actual_sigs int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_addendum FROM public.pact_addendums WHERE id = p_addendum_id;
  IF v_addendum.id IS NULL THEN RAISE EXCEPTION 'Anexo no encontrado'; END IF;
  IF v_addendum.state = 'active' THEN
    RAISE EXCEPTION 'El anexo ya está activo';
  END IF;
  IF v_addendum.state = 'cancelled' THEN
    RAISE EXCEPTION 'El anexo está cancelado';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_addendum.pact_id AND user_id = v_user_id;
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No formas parte del pacto';
  END IF;

  -- Marcar firma según rol del caller
  IF v_user_role = 'promotor' THEN
    IF v_addendum.signed_at_promotor IS NOT NULL THEN
      RAISE EXCEPTION 'Ya firmaste este anexo';
    END IF;
    UPDATE public.pact_addendums SET signed_at_promotor = now(), state = 'signing'
    WHERE id = p_addendum_id;
  ELSIF v_user_role = 'constructor' THEN
    IF v_addendum.signed_at_constructor IS NOT NULL THEN
      RAISE EXCEPTION 'Ya firmaste este anexo';
    END IF;
    UPDATE public.pact_addendums SET signed_at_constructor = now(), state = 'signing'
    WHERE id = p_addendum_id;
  ELSIF v_user_role = 'tecnico' THEN
    IF v_addendum.signed_at_tecnico IS NOT NULL THEN
      RAISE EXCEPTION 'Ya firmaste este anexo';
    END IF;
    UPDATE public.pact_addendums SET signed_at_tecnico = now(), state = 'signing'
    WHERE id = p_addendum_id;
  END IF;

  -- Comprobar si todas las partes han firmado
  SELECT pact_type INTO v_pact_type FROM public.pacts WHERE id = v_addendum.pact_id;
  v_required_sigs := CASE WHEN v_pact_type = 'obra_mayor' THEN 3 ELSE 2 END;

  SELECT
    (CASE WHEN signed_at_promotor IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN signed_at_constructor IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN signed_at_tecnico IS NOT NULL THEN 1 ELSE 0 END)
  INTO v_actual_sigs
  FROM public.pact_addendums WHERE id = p_addendum_id;

  IF v_actual_sigs >= v_required_sigs THEN
    -- Todos firmaron → activar (el trigger handle_addendum_active actualiza el total)
    UPDATE public.pact_addendums SET state = 'active' WHERE id = p_addendum_id;
  END IF;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_addendum.pact_id, 'addendum_signed',
    jsonb_build_object(
      'addendum_id', p_addendum_id,
      'signed_by_role', v_user_role::text,
      'sigs', v_actual_sigs,
      'required', v_required_sigs
    ),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'sigs', v_actual_sigs,
    'required', v_required_sigs,
    'active', v_actual_sigs >= v_required_sigs
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_addendum_sign TO authenticated;


-- =====================================================================
-- COMENTARIOS
-- =====================================================================
COMMENT ON FUNCTION public.sf_create_pact_v2 IS
  'Sprint 4 · Crea pact v2 sin hitos predefinidos. Acepta deposit_required_pct y certification_frequency. Marca model_version=v2.';
COMMENT ON FUNCTION public.sf_pact_fund_initial IS
  'Sprint 4 · Promotor deposita el % inicial. Pact: signed → funded → in_execution. Registra deposit_movement initial_deposit.';
COMMENT ON FUNCTION public.sf_constructor_create_cert IS
  'Sprint 4 · Constructor crea certificación con ordinal correlativo. Valida techo de presupuesto disponible.';
COMMENT ON FUNCTION public.sf_constructor_edit_cert IS
  'Sprint 4 · Constructor edita cert rechazada o pidiendo info. Incrementa version. Snapshot anterior en pact_events.';
COMMENT ON FUNCTION public.sf_attach_cert_invoice IS
  'Sprint 4 · Adjunta factura del constructor (obligatoria desde v2.0).';
COMMENT ON FUNCTION public.sf_addendum_create IS
  'Sprint 4 · Propone anexo al pacto. Doc detallado obligatorio si extra > 10.000€.';
COMMENT ON FUNCTION public.sf_addendum_sign IS
  'Sprint 4 · Firma anexo por parte del caller. Cuando todas firman, anexo → active (trigger actualiza total).';

NOTIFY pgrst, 'reload schema';
