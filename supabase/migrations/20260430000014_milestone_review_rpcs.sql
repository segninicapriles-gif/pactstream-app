-- =====================================================================
-- Sprint 2 chunk 5 · Migration 0017
-- Validación técnica + decisión promotor + auto-progreso de hitos.
-- =====================================================================
-- Funciones:
--   sf_milestone_tech_review(milestone_id, decision, rationale)
--     Técnico decide: approve | reject | request_info.
--     Transiciones desde ready_for_review (in_validation intermedio).
--
--   sf_milestone_promotor_decide(milestone_id, decision, rationale)
--     Promotor decide: approve | dispute.
--     En obra mayor: desde awaiting_promotor.
--     En obra menor: desde ready_for_review (hace los 2 pasos).
--
-- Triggers:
--   trg_milestone_paid_progress
--     Cuando un hito pasa a 'paid':
--       - arranca el siguiente hito (pending → in_execution)
--       - si era el último, marca el pact como completed (vía completed primero)
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_milestone_tech_review
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_milestone_tech_review;
CREATE OR REPLACE FUNCTION public.sf_milestone_tech_review(
  p_milestone_id uuid,
  p_decision text,
  p_rationale text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_id  uuid;
  v_pact_type pact_type;
  v_milestone_state milestone_state;
  v_user_role pact_party_role;
  v_validation_id uuid;
  v_final_state milestone_state;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- Cargar hito + pact
  SELECT m.pact_id, m.state, p.pact_type
  INTO v_pact_id, v_milestone_state, v_pact_type
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  -- Validar rol del caller
  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  -- En obra mayor solo el técnico valida; en obra menor el promotor
  -- usa esta misma RPC porque hace el rol técnico (ver sf_milestone_promotor_decide
  -- que es la vía recomendada en obra menor).
  IF v_pact_type = 'obra_mayor' AND v_user_role != 'tecnico' THEN
    RAISE EXCEPTION 'Solo el arquitecto técnico puede validar técnicamente este hito';
  END IF;

  -- Validar estado de partida
  IF v_milestone_state != 'ready_for_review' THEN
    RAISE EXCEPTION 'El hito no está listo para revisión (estado actual: %)', v_milestone_state;
  END IF;

  -- Validar decisión
  IF p_decision NOT IN ('approve', 'reject', 'request_info') THEN
    RAISE EXCEPTION 'Decisión inválida: %. Usar approve | reject | request_info', p_decision;
  END IF;

  -- Transición intermedia obligatoria: ready_for_review → in_validation
  UPDATE public.milestones
  SET state = 'in_validation'
  WHERE id = p_milestone_id;

  -- Aplicar la decisión
  IF p_decision = 'approve' THEN
    -- in_validation → approved_by_tech → awaiting_promotor
    UPDATE public.milestones
    SET state = 'approved_by_tech', validated_at = now()
    WHERE id = p_milestone_id;
    UPDATE public.milestones
    SET state = 'awaiting_promotor'
    WHERE id = p_milestone_id;
    v_final_state := 'awaiting_promotor';
  ELSIF p_decision = 'reject' THEN
    -- in_validation → rejected_by_tech (constructor puede resubir)
    UPDATE public.milestones
    SET state = 'rejected_by_tech', rejected_at = now()
    WHERE id = p_milestone_id;
    v_final_state := 'rejected_by_tech';
  ELSE
    -- in_validation → info_requested
    UPDATE public.milestones
    SET state = 'info_requested'
    WHERE id = p_milestone_id;
    v_final_state := 'info_requested';
  END IF;

  -- Registrar la validación (audit trail)
  INSERT INTO public.milestone_validations (
    milestone_id, validator_user_id, decision, rationale
  ) VALUES (
    p_milestone_id,
    v_user_id,
    CASE p_decision
      WHEN 'approve' THEN 'approved'::validation_decision
      WHEN 'reject' THEN 'rejected'::validation_decision
      ELSE 'info_requested'::validation_decision
    END,
    p_rationale
  )
  RETURNING id INTO v_validation_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact_id, 'milestone_tech_reviewed',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'decision', p_decision,
      'final_state', v_final_state::text
    ),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'milestone_state', v_final_state::text,
    'validation_id', v_validation_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_milestone_tech_review TO authenticated;


-- ---------------------------------------------------------------------
-- sf_milestone_promotor_decide
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_milestone_promotor_decide;
CREATE OR REPLACE FUNCTION public.sf_milestone_promotor_decide(
  p_milestone_id uuid,
  p_decision text,
  p_rationale text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_id  uuid;
  v_pact_type pact_type;
  v_milestone_state milestone_state;
  v_user_role pact_party_role;
  v_final_state milestone_state;
  v_amount_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id, m.state, m.amount_cents, p.pact_type
  INTO v_pact_id, v_milestone_state, v_amount_cents, v_pact_type
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;

  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede decidir sobre el hito';
  END IF;

  IF p_decision NOT IN ('approve', 'dispute') THEN
    RAISE EXCEPTION 'Decisión inválida: %. Usar approve | dispute', p_decision;
  END IF;

  -- Estados de partida válidos:
  --   obra_mayor: awaiting_promotor (tras técnico)
  --   obra_menor: ready_for_review (no hay técnico, promotor hace todo)
  IF v_pact_type = 'obra_menor' AND v_milestone_state = 'ready_for_review' THEN
    -- Cascada de transiciones: ready_for_review → in_validation
    --   → approved_by_tech → awaiting_promotor
    -- Registrar también la "validación" automática a nombre del promotor.
    UPDATE public.milestones SET state = 'in_validation' WHERE id = p_milestone_id;
    UPDATE public.milestones
    SET state = 'approved_by_tech', validated_at = now()
    WHERE id = p_milestone_id;
    UPDATE public.milestones
    SET state = 'awaiting_promotor'
    WHERE id = p_milestone_id;

    -- Insertar registro de validación implícita (rol técnico = promotor en obra menor)
    INSERT INTO public.milestone_validations (
      milestone_id, validator_user_id, decision, rationale
    ) VALUES (
      p_milestone_id, v_user_id,
      'approved'::validation_decision,
      coalesce('[obra menor: validación automática por promotor] ' || p_rationale, '[obra menor: validación automática por promotor]')
    );
  ELSIF v_milestone_state != 'awaiting_promotor' THEN
    RAISE EXCEPTION 'El hito no está esperando decisión del promotor (estado actual: %)', v_milestone_state;
  END IF;

  -- Aplicar la decisión final
  IF p_decision = 'approve' THEN
    -- awaiting_promotor → paid (mock del release; en chunk 6 con Mangopay)
    UPDATE public.milestones
    SET state = 'paid',
        approved_by_promotor_at = now(),
        paid_at = now()
    WHERE id = p_milestone_id;
    v_final_state := 'paid';

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact_id, 'milestone_paid',
      jsonb_build_object(
        'milestone_id', p_milestone_id,
        'amount_cents', v_amount_cents,
        'note', 'MOCK release · Mangopay pendiente'
      ),
      v_user_id);
  ELSE
    -- awaiting_promotor → disputed
    UPDATE public.milestones
    SET state = 'disputed'
    WHERE id = p_milestone_id;
    v_final_state := 'disputed';

    -- Registrar objeción
    INSERT INTO public.milestone_objections (
      milestone_id, raised_by_user_id, reason_categories, reason_detail
    ) VALUES (
      p_milestone_id, v_user_id,
      ARRAY['other']::text[],
      coalesce(p_rationale, 'Objeción del promotor')
    );

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact_id, 'milestone_disputed',
      jsonb_build_object(
        'milestone_id', p_milestone_id,
        'rationale', p_rationale
      ),
      v_user_id);
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'milestone_promotor_decided', 'milestone', p_milestone_id,
    jsonb_build_object('decision', p_decision, 'final_state', v_final_state::text));

  RETURN jsonb_build_object(
    'success', true,
    'milestone_state', v_final_state::text
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_milestone_promotor_decide TO authenticated;


-- ---------------------------------------------------------------------
-- Trigger: auto-progreso al pagar un hito
-- ---------------------------------------------------------------------
-- Cuando un hito pasa a 'paid':
--   - Si hay siguiente hito en orden, lo arranca (pending → in_execution)
--   - Si era el último, el pact pasa de in_execution → completed
CREATE OR REPLACE FUNCTION public.handle_milestone_paid_progress()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_milestone_id uuid;
  v_remaining_unpaid int;
BEGIN
  IF OLD.state = NEW.state OR NEW.state != 'paid' THEN
    RETURN NEW;
  END IF;

  -- Buscar siguiente hito pendiente
  SELECT id INTO v_next_milestone_id
  FROM public.milestones
  WHERE pact_id = NEW.pact_id
    AND state = 'pending'
    AND ordinal > NEW.ordinal
  ORDER BY ordinal LIMIT 1;

  IF v_next_milestone_id IS NOT NULL THEN
    -- Arrancar el siguiente
    UPDATE public.milestones
    SET state = 'in_execution', started_at = now()
    WHERE id = v_next_milestone_id;

    INSERT INTO public.pact_events (pact_id, event_type, payload)
    VALUES (NEW.pact_id, 'next_milestone_started',
      jsonb_build_object(
        'previous_milestone_id', NEW.id,
        'next_milestone_id', v_next_milestone_id
      ));
  ELSE
    -- No hay siguiente. Verificar si todos los hitos están pagados.
    SELECT count(*) INTO v_remaining_unpaid
    FROM public.milestones
    WHERE pact_id = NEW.pact_id AND state != 'paid';

    IF v_remaining_unpaid = 0 THEN
      -- Todos pagados → pact completado
      -- Transición permitida: in_execution → completed
      UPDATE public.pacts
      SET state = 'completed', closed_at = now()
      WHERE id = NEW.pact_id AND state = 'in_execution';

      INSERT INTO public.pact_events (pact_id, event_type, payload)
      VALUES (NEW.pact_id, 'pact_completed',
        jsonb_build_object('total_milestones_paid', NEW.ordinal));
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_milestone_paid_progress ON public.milestones;
CREATE TRIGGER trg_milestone_paid_progress
  AFTER UPDATE OF state ON public.milestones
  FOR EACH ROW
  WHEN (NEW.state = 'paid' AND OLD.state != 'paid')
  EXECUTE FUNCTION public.handle_milestone_paid_progress();


-- ---------------------------------------------------------------------
-- Comentarios + reload
-- ---------------------------------------------------------------------
COMMENT ON FUNCTION public.sf_milestone_tech_review IS
  'El técnico (obra mayor) decide approve|reject|request_info. Cascada de transiciones según decisión. Registro en milestone_validations.';
COMMENT ON FUNCTION public.sf_milestone_promotor_decide IS
  'El promotor decide approve|dispute. Obra mayor: desde awaiting_promotor. Obra menor: desde ready_for_review (hace ambos pasos en cascada).';
COMMENT ON FUNCTION public.handle_milestone_paid_progress IS
  'Trigger: cuando un hito paga, arranca el siguiente o completa el pact si es el último.';

-- ---------------------------------------------------------------------
-- Validar transiciones de pact: in_execution → completed
-- ---------------------------------------------------------------------
-- El state machine base no tenía 'in_execution → completed'. Verifico
-- y corrijo si hace falta.
-- (Esto se ejecuta solo si no estaba ya: idempotente.)
CREATE OR REPLACE FUNCTION public.validate_pact_state_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  valid_transitions text[];
BEGIN
  IF OLD.state = NEW.state THEN
    RETURN NEW;
  END IF;

  valid_transitions := CASE OLD.state
    WHEN 'draft' THEN ARRAY['inviting', 'cancelled']
    WHEN 'inviting' THEN ARRAY['signing', 'cancelled']
    WHEN 'signing' THEN ARRAY['signed', 'cancelled']
    WHEN 'signed' THEN ARRAY['funded', 'cancelled']
    WHEN 'funded' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'in_execution' THEN ARRAY['disputed', 'completed', 'suspended']
    WHEN 'disputed' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'suspended' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'completed' THEN ARRAY['closed']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (NEW.state::text = ANY(valid_transitions)) THEN
    RAISE EXCEPTION 'Transición de estado de pacto inválida: % → %', OLD.state, NEW.state;
  END IF;

  INSERT INTO pact_state_transitions(pact_id, from_state, to_state, transitioned_by_user_id)
  VALUES (NEW.id, OLD.state, NEW.state, current_user_id());

  NEW.state_updated_at := now();
  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
