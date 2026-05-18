-- =====================================================================
-- Sprint 5 chunk 2 · Migration 0030
-- RPCs del modelo v2.1 (Adelanto + doble garantía)
-- =====================================================================
-- 6 RPCs nuevas/refactorizadas para el flujo "Adelanto + pre-depósito":
--
--   1. sf_create_pact_v21           crear pact v2.1 (advance 10-40)
--   2. sf_finalize_pact_v21         finalizar borrador y pasar a inviting
--   3. sf_pact_setup_advance        promotor deposita el adelanto total
--                                   (libera variable al constructor + custodia reserva)
--   4. sf_constructor_create_cert_v21
--                                   constructor crea cert (pending_predeposit + reloj 3 días)
--   5. sf_pact_predeposit_milestone promotor pre-deposita el neto de una cert
--                                   (la cert pasa de pending_predeposit a in_execution)
--   6. sf_milestone_force_advance   constructor activa "avanzar bajo responsabilidad"
--                                   (paused_no_predeposit → in_execution con flag forzado)
--
-- Las RPCs v2 del Sprint 4 siguen vigentes para los pacts antiguos.
-- Una vez que el milestone está en 'in_execution', el resto del flujo
-- (evidencias, validación técnica, objeción, paid) reutiliza las RPCs
-- existentes del Sprint 2/3 sin cambios.
-- =====================================================================


-- =====================================================================
-- 1 · sf_create_pact_v21
-- =====================================================================
DROP FUNCTION IF EXISTS public.sf_create_pact_v21;
CREATE OR REPLACE FUNCTION public.sf_create_pact_v21(
  p_title text,
  p_obra_address_line text,
  p_total_amount_cents bigint,
  p_description text DEFAULT NULL,
  p_pact_type text DEFAULT 'obra_mayor',
  p_obra_postal_code text DEFAULT NULL,
  p_obra_city text DEFAULT NULL,
  p_obra_province text DEFAULT NULL,
  p_obra_type text DEFAULT 'reforma_integral',
  p_iva_rate_pct numeric DEFAULT 10,
  p_iva_included boolean DEFAULT true,
  p_estimated_start_date date DEFAULT NULL,
  p_estimated_end_date date DEFAULT NULL,
  p_advance_pct numeric DEFAULT 30,             -- 10-40 (total, incluye reserva)
  p_advance_reserve_pct numeric DEFAULT 10,     -- fijo en MVP, parametrizable
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

  -- Validaciones del modelo v2.1
  IF p_pact_type NOT IN ('obra_mayor', 'obra_menor') THEN
    RAISE EXCEPTION 'Tipo de pacto inválido: %', p_pact_type;
  END IF;

  IF p_advance_pct < 10 OR p_advance_pct > 40 THEN
    RAISE EXCEPTION 'El adelanto debe estar entre 10%% y 40%% (recibido: %%%)', p_advance_pct;
  END IF;

  IF p_advance_reserve_pct < 0 OR p_advance_reserve_pct > 20 THEN
    RAISE EXCEPTION 'La reserva debe estar entre 0%% y 20%% (recibido: %%%)', p_advance_reserve_pct;
  END IF;

  IF p_advance_reserve_pct > p_advance_pct THEN
    RAISE EXCEPTION 'La reserva (%%%) no puede ser mayor que el adelanto total (%%%)',
      p_advance_reserve_pct, p_advance_pct;
  END IF;

  IF p_total_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El presupuesto mínimo del pacto es 500 €';
  END IF;

  IF p_pact_type = 'obra_menor' AND NOT p_obra_menor_declaration_accepted THEN
    RAISE EXCEPTION 'Para obra menor debes aceptar la declaración responsable';
  END IF;

  -- Generar display_id único
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
    -- Campos v2.1
    deposit_required_pct,         -- el adelanto total (10-40)
    advance_reserve_pct,          -- reserva (10 default)
    advance_released_cents,       -- 0 al crear, se setea en setup_advance
    advance_outstanding_cents,    -- 0 al crear, se setea en setup_advance
    certification_frequency_text,
    model_version
  ) VALUES (
    v_display_id, p_title, p_description, p_pact_type::pact_type,
    p_obra_address_line, p_obra_postal_code,
    coalesce(p_obra_city, p_obra_province), p_obra_province,
    p_obra_type, p_total_amount_cents, p_iva_rate_pct, p_iva_included,
    p_estimated_start_date, p_estimated_end_date,
    CASE WHEN p_pact_type = 'obra_menor' THEN now() ELSE NULL END,
    CASE WHEN p_pact_type = 'obra_menor' THEN 'sha256_obra_menor_v21' ELSE NULL END,
    'draft', 'fund_first',
    CASE WHEN p_pact_type = 'obra_menor' THEN 0.80 ELSE 1.00 END,
    v_user_id,
    p_advance_pct,
    p_advance_reserve_pct,
    0,
    0,
    p_certification_frequency,
    'v2.1'
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
  VALUES (v_user_id, 'pact_v21_created', 'pact', v_pact_id,
    jsonb_build_object(
      'display_id', v_display_id,
      'pact_type', p_pact_type,
      'advance_pct', p_advance_pct,
      'reserve_pct', p_advance_reserve_pct,
      'total_cents', p_total_amount_cents
    ));

  out_pact_id := v_pact_id;
  out_display_id := v_display_id;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_create_pact_v21 TO authenticated;


-- =====================================================================
-- 2 · sf_finalize_pact_v21
-- =====================================================================
DROP FUNCTION IF EXISTS public.sf_finalize_pact_v21;
CREATE OR REPLACE FUNCTION public.sf_finalize_pact_v21(p_pact_id uuid)
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
  IF v_pact.model_version != 'v2.1' THEN
    RAISE EXCEPTION 'sf_finalize_pact_v21 solo aplica a pacts v2.1';
  END IF;

  v_required_parties := CASE WHEN v_pact.pact_type = 'obra_mayor' THEN 3 ELSE 2 END;
  SELECT count(*) INTO v_party_count FROM public.pact_parties WHERE pact_id = p_pact_id;

  IF v_party_count != v_required_parties THEN
    RAISE EXCEPTION 'Se requieren % partes para % (actual: %)',
      v_required_parties, v_pact.pact_type, v_party_count;
  END IF;

  UPDATE public.pacts SET state = 'inviting' WHERE id = p_pact_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_caller_id, 'pact_v21_finalized', 'pact', p_pact_id);

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_finalized',
    jsonb_build_object(
      'model_version', 'v2.1',
      'total_amount_cents', v_pact.total_amount_cents,
      'advance_pct', v_pact.deposit_required_pct,
      'reserve_pct', v_pact.advance_reserve_pct
    ),
    v_caller_id);

  RETURN p_pact_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_finalize_pact_v21 TO authenticated;


-- =====================================================================
-- 3 · sf_pact_setup_advance
-- =====================================================================
-- Promotor confirma el depósito del Adelanto completo. PactStream:
--   1. Libera la parte variable (advance_pct - reserve_pct) al constructor
--   2. Custodia la parte fija (reserve_pct) hasta el finiquito
--   3. Crea la póliza de caución (estado 'draft', importe = released)
--
-- Pact: signed → funded → in_execution
DROP FUNCTION IF EXISTS public.sf_pact_setup_advance;
CREATE OR REPLACE FUNCTION public.sf_pact_setup_advance(p_pact_id uuid)
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
  v_total_advance_cents bigint;
  v_reserve_cents bigint;
  v_released_cents bigint;
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
    RAISE EXCEPTION 'Solo el promotor puede configurar el adelanto';
  END IF;

  IF v_pact.state != 'signed' THEN
    RAISE EXCEPTION 'El pacto no está en estado signed (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2.1' THEN
    RAISE EXCEPTION 'sf_pact_setup_advance solo aplica a pacts v2.1';
  END IF;

  -- Cálculos
  v_total_advance_cents := (v_pact.total_amount_cents * v_pact.deposit_required_pct / 100)::bigint;
  v_reserve_cents := (v_pact.total_amount_cents * v_pact.advance_reserve_pct / 100)::bigint;
  v_released_cents := v_total_advance_cents - v_reserve_cents;

  -- Transiciones del pacto: signed → funded → in_execution
  UPDATE public.pacts
  SET state = 'funded',
      deposit_current_cents = v_reserve_cents,         -- la reserva queda custodiada
      advance_released_cents = v_released_cents,       -- lo entregado al constructor
      advance_outstanding_cents = v_released_cents     -- saldo vivo inicial = lo entregado
  WHERE id = p_pact_id;

  UPDATE public.pacts SET state = 'in_execution' WHERE id = p_pact_id;

  -- Movimientos contables
  -- a) Reserva custodiada
  IF v_reserve_cents > 0 THEN
    INSERT INTO public.deposit_movements (
      pact_id, movement_type, amount_cents, triggered_by_user_id,
      balance_before_cents, balance_after_cents, notes
    ) VALUES (
      p_pact_id, 'reserve_deposit', v_reserve_cents, v_user_id,
      0, v_reserve_cents,
      'Reserva de finiquito · ' || v_pact.advance_reserve_pct || '% del presupuesto'
    );
  END IF;

  -- b) Anticipo entregado al constructor (variable)
  IF v_released_cents > 0 THEN
    INSERT INTO public.deposit_movements (
      pact_id, movement_type, amount_cents, triggered_by_user_id,
      balance_before_cents, balance_after_cents, notes
    ) VALUES (
      p_pact_id, 'initial_deposit', v_released_cents, v_user_id,
      v_reserve_cents, v_reserve_cents,
      'Anticipo entregado al constructor · ' ||
        (v_pact.deposit_required_pct - v_pact.advance_reserve_pct) ||
        '% del presupuesto'
    );
  END IF;

  -- c) Crear póliza de caución (estado draft, admin la confirma)
  INSERT INTO public.surety_policies (
    pact_id, insurer_name, initial_coverage_cents, current_coverage_cents,
    status, created_by_user_id, admin_notes
  ) VALUES (
    p_pact_id, 'PENDIENTE_ADMIN', v_released_cents, v_released_cents,
    'draft', v_user_id,
    'Auto-creada por sf_pact_setup_advance. Pendiente de confirmar aseguradora real desde panel admin.'
  );

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'advance_setup',
    jsonb_build_object(
      'advance_pct', v_pact.deposit_required_pct,
      'reserve_pct', v_pact.advance_reserve_pct,
      'total_advance_cents', v_total_advance_cents,
      'released_cents', v_released_cents,
      'reserve_cents', v_reserve_cents
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_setup_advance', 'pact', p_pact_id,
    jsonb_build_object(
      'released_cents', v_released_cents,
      'reserve_cents', v_reserve_cents
    ));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', 'in_execution',
    'total_deposited_cents', v_total_advance_cents,
    'released_to_constructor_cents', v_released_cents,
    'reserve_custody_cents', v_reserve_cents,
    'surety_policy_pending_admin', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_pact_setup_advance TO authenticated;


-- =====================================================================
-- 4 · sf_constructor_create_cert_v21
-- =====================================================================
-- Constructor crea borrador de certificación.
--   - Calcula amortización del adelanto (bruto × advance_pct / 100)
--   - Estado inicial: pending_predeposit
--   - predeposit_deadline_at = now() + 3 días
DROP FUNCTION IF EXISTS public.sf_constructor_create_cert_v21;
CREATE OR REPLACE FUNCTION public.sf_constructor_create_cert_v21(
  p_pact_id uuid,
  p_name text,
  p_amount_cents bigint,         -- el bruto certificado
  p_description text DEFAULT NULL
)
RETURNS TABLE(
  out_cert_id uuid,
  out_display_id text,
  out_ordinal smallint,
  out_amortization_cents bigint,
  out_net_amount_cents bigint,
  out_predeposit_deadline_at timestamptz
)
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
  v_amortization bigint;
  v_net bigint;
  v_deadline timestamptz;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;
  IF v_pact.model_version != 'v2.1' THEN
    RAISE EXCEPTION 'Esta RPC solo aplica a pacts v2.1';
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

  -- Techo de presupuesto: total - ya pagado - en curso
  SELECT v_pact.total_amount_cents - v_pact.budget_consumed_cents -
    coalesce((SELECT sum(amount_cents) FROM public.milestones
              WHERE pact_id = p_pact_id AND state NOT IN ('paid')), 0)
  INTO v_remaining_cents;

  IF p_amount_cents > v_remaining_cents THEN
    RAISE EXCEPTION 'La certificación excede el presupuesto disponible (% €)',
      v_remaining_cents / 100;
  END IF;

  -- Cálculos v2.1
  v_amortization := (p_amount_cents * v_pact.deposit_required_pct / 100)::bigint;
  v_net := p_amount_cents - v_amortization;
  v_deadline := now() + interval '3 days';

  -- Ordinal y display_id
  SELECT coalesce(max(ordinal), 0) + 1 INTO v_next_ordinal
  FROM public.milestones WHERE pact_id = p_pact_id;

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
    amount_cents, advance_amortization_cents,
    predeposit_deadline_at,
    state, version
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal, p_name, p_description,
    p_amount_cents, v_amortization,
    v_deadline,
    'pending_predeposit', 1
  )
  RETURNING id INTO v_cert_id;

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'cert_v21_created',
    jsonb_build_object(
      'cert_id', v_cert_id,
      'ordinal', v_next_ordinal,
      'gross_cents', p_amount_cents,
      'amortization_cents', v_amortization,
      'net_cents', v_net,
      'predeposit_deadline_at', v_deadline
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'cert_v21_created', 'milestone', v_cert_id,
    jsonb_build_object('ordinal', v_next_ordinal, 'gross_cents', p_amount_cents));

  out_cert_id := v_cert_id;
  out_display_id := v_display_id;
  out_ordinal := v_next_ordinal;
  out_amortization_cents := v_amortization;
  out_net_amount_cents := v_net;
  out_predeposit_deadline_at := v_deadline;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_constructor_create_cert_v21 TO authenticated;


-- =====================================================================
-- 5 · sf_pact_predeposit_milestone
-- =====================================================================
-- Promotor pre-deposita el neto de una cert pending_predeposit.
-- Para el finiquito (última cert), se considera disponible la reserva
-- custodiada y solo se exige el diferencial.
DROP FUNCTION IF EXISTS public.sf_pact_predeposit_milestone;
CREATE OR REPLACE FUNCTION public.sf_pact_predeposit_milestone(
  p_milestone_id uuid,
  p_amount_cents bigint                  -- el promotor declara qué ingresa
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
  v_milestone public.milestones%ROWTYPE;
  v_user_role pact_party_role;
  v_required_cents bigint;
  v_balance_before bigint;
  v_balance_after bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_milestone FROM public.milestones WHERE id = p_milestone_id;
  IF v_milestone.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = v_milestone.pact_id;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact.id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede pre-depositar';
  END IF;

  IF v_milestone.state NOT IN ('pending_predeposit', 'paused_no_predeposit') THEN
    RAISE EXCEPTION 'La certificación no está pendiente de pre-depósito (estado: %)',
      v_milestone.state;
  END IF;

  -- Cuánto falta por pre-depositar
  v_required_cents := v_milestone.net_amount_cents - v_milestone.predeposit_received_cents;

  IF p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'El importe debe ser positivo';
  END IF;
  IF p_amount_cents > v_required_cents THEN
    RAISE EXCEPTION 'El importe excede lo pendiente (% €)', v_required_cents / 100;
  END IF;

  -- Actualizar pre-depósito de la cert
  UPDATE public.milestones
  SET predeposit_received_cents = predeposit_received_cents + p_amount_cents
  WHERE id = p_milestone_id;

  -- Actualizar custodia del pacto
  v_balance_before := v_pact.deposit_current_cents;
  v_balance_after := v_balance_before + p_amount_cents;

  UPDATE public.pacts
  SET deposit_current_cents = v_balance_after
  WHERE id = v_pact.id;

  -- Movimiento contable
  INSERT INTO public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    related_milestone_id, balance_before_cents, balance_after_cents, notes
  ) VALUES (
    v_pact.id, 'predeposit_for_cert', p_amount_cents, v_user_id,
    p_milestone_id, v_balance_before, v_balance_after,
    'Pre-depósito de Cert #' || v_milestone.ordinal
  );

  -- Si el pre-depósito está completo, mover cert a in_execution
  IF (v_milestone.predeposit_received_cents + p_amount_cents) >= v_milestone.net_amount_cents THEN
    UPDATE public.milestones
    SET state = 'in_execution',
        started_at = coalesce(started_at, now())
    WHERE id = p_milestone_id;

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact.id, 'cert_predeposit_completed',
      jsonb_build_object('cert_id', p_milestone_id),
      v_user_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'predeposit_received_cents', v_milestone.predeposit_received_cents + p_amount_cents,
    'predeposit_required_cents', v_milestone.net_amount_cents,
    'completed', (v_milestone.predeposit_received_cents + p_amount_cents) >= v_milestone.net_amount_cents
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_pact_predeposit_milestone TO authenticated;


-- =====================================================================
-- 6 · sf_milestone_force_advance
-- =====================================================================
-- Constructor activa "avanzar bajo mi responsabilidad" si el pre-depósito
-- no llegó a tiempo (cert en paused_no_predeposit).
--
-- Efecto: la cert pasa a in_execution con forced_under_responsibility=true.
-- PactStream y aseguradora quedan liberados de responsabilidad sobre lo
-- ejecutado mientras el pre-depósito no esté completo.
DROP FUNCTION IF EXISTS public.sf_milestone_force_advance;
CREATE OR REPLACE FUNCTION public.sf_milestone_force_advance(
  p_milestone_id uuid,
  p_disclaimer_accepted boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_milestone public.milestones%ROWTYPE;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
BEGIN
  IF NOT p_disclaimer_accepted THEN
    RAISE EXCEPTION 'Debes aceptar el disclaimer para avanzar bajo tu responsabilidad';
  END IF;

  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_milestone FROM public.milestones WHERE id = p_milestone_id;
  IF v_milestone.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = v_milestone.pact_id;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact.id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede activar este toggle';
  END IF;

  IF v_milestone.state NOT IN ('pending_predeposit', 'paused_no_predeposit') THEN
    RAISE EXCEPTION 'Solo aplica a certificaciones pendientes o paralizadas (estado: %)',
      v_milestone.state;
  END IF;

  UPDATE public.milestones
  SET state = 'in_execution',
      forced_under_responsibility = true,
      forced_under_responsibility_at = now(),
      started_at = coalesce(started_at, now())
  WHERE id = p_milestone_id;

  -- Event log con peso jurídico
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact.id, 'cert_forced_under_responsibility',
    jsonb_build_object(
      'cert_id', p_milestone_id,
      'cert_ordinal', v_milestone.ordinal,
      'predeposit_received_cents', v_milestone.predeposit_received_cents,
      'predeposit_required_cents', v_milestone.net_amount_cents,
      'disclaimer_accepted_at', now()
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'cert_force_advance', 'milestone', p_milestone_id,
    jsonb_build_object(
      'predeposit_gap_cents',
      v_milestone.net_amount_cents - v_milestone.predeposit_received_cents
    ));

  RETURN jsonb_build_object(
    'success', true,
    'new_state', 'in_execution',
    'forced_under_responsibility', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_milestone_force_advance TO authenticated;


-- =====================================================================
-- 7 · Comentarios
-- =====================================================================
COMMENT ON FUNCTION public.sf_create_pact_v21 IS
  'v2.1 · Crea pact con Adelanto (10-40) + reserva fija. model_version=v2.1.';
COMMENT ON FUNCTION public.sf_finalize_pact_v21 IS
  'v2.1 · Pasa de draft a inviting. Valida partes según pact_type.';
COMMENT ON FUNCTION public.sf_pact_setup_advance IS
  'v2.1 · Promotor deposita el adelanto. Libera la parte variable al constructor y custodia la reserva. Crea póliza draft.';
COMMENT ON FUNCTION public.sf_constructor_create_cert_v21 IS
  'v2.1 · Crea cert en pending_predeposit con reloj de 3 días. Calcula amortización del adelanto.';
COMMENT ON FUNCTION public.sf_pact_predeposit_milestone IS
  'v2.1 · Promotor pre-deposita el neto. Cuando se completa, la cert pasa a in_execution.';
COMMENT ON FUNCTION public.sf_milestone_force_advance IS
  'v2.1 · Constructor avanza sin pre-depósito completo asumiendo responsabilidad.';

NOTIFY pgrst, 'reload schema';
