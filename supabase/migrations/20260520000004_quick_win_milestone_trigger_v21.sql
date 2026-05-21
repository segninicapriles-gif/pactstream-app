-- =====================================================================
-- Quick Win 2 · validate_milestone_state_transition v2.1-aware
-- =====================================================================
-- El trigger original sólo conocía los estados v1; los estados v2.1
-- (pending_predeposit, paused_no_predeposit) caían en el ELSE y
-- bloqueaban cualquier transición, obligando a DISABLE TRIGGER manual.
--
-- Esta migración añade las transiciones v2.1 sin tocar las v1.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.validate_milestone_state_transition()
RETURNS TRIGGER AS $$
DECLARE
  valid_transitions text[];
BEGIN
  IF OLD.state = NEW.state THEN
    RETURN NEW;
  END IF;

  valid_transitions := CASE OLD.state
    -- v1
    WHEN 'pending'           THEN ARRAY['in_execution', 'pending_predeposit']
    WHEN 'in_execution'      THEN ARRAY['ready_for_review', 'paused_no_predeposit']
    WHEN 'ready_for_review'  THEN ARRAY['in_validation']
    WHEN 'in_validation'     THEN ARRAY['approved_by_tech', 'rejected_by_tech', 'info_requested']
    WHEN 'info_requested'    THEN ARRAY['ready_for_review']
    WHEN 'rejected_by_tech'  THEN ARRAY['in_execution', 'disputed']
    WHEN 'approved_by_tech'  THEN ARRAY['awaiting_promotor', 'disputed']
    WHEN 'awaiting_promotor' THEN ARRAY['paid', 'disputed']
    WHEN 'disputed'          THEN ARRAY['paid', 'awaiting_promotor', 'in_execution']
    -- v2.1
    WHEN 'pending_predeposit'   THEN ARRAY['in_execution', 'paused_no_predeposit']
    WHEN 'paused_no_predeposit' THEN ARRAY['in_execution', 'pending_predeposit']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (NEW.state::text = ANY(valid_transitions)) THEN
    RAISE EXCEPTION 'Transición de estado de hito inválida: % → %', OLD.state, NEW.state;
  END IF;

  INSERT INTO milestone_state_transitions(milestone_id, from_state, to_state, transitioned_by_user_id)
  VALUES (NEW.id, OLD.state, NEW.state, current_user_id());

  NEW.state_updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

NOTIFY pgrst, 'reload schema';
