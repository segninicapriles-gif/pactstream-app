-- =====================================================================
-- Quick Win 1 · Eliminar referencias residuales a 'in_progress'
-- =====================================================================
--   1) sf_mock_fund_pact: el primer hito tras activar la obra ahora
--      pasa a 'in_execution' (no 'in_progress' que es inválido).
--   2) sf_submit_milestone_for_review: chequea 'in_execution' o
--      'info_requested' como estados válidos. Acepta también a
--      miembros del equipo del constructor (Sprint 6).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.sf_mock_fund_pact(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid          uuid;
  v_user_id           uuid;
  v_pact_state        pact_state;
  v_first_milestone_id uuid;
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

  IF NOT EXISTS(
    SELECT 1 FROM public.pact_parties
    WHERE pact_id = p_pact_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact_state != 'signed' THEN
    RAISE EXCEPTION 'Solo se puede mockear el funding desde estado signed (actual: %)', v_pact_state;
  END IF;

  UPDATE public.pacts SET state = 'in_execution' WHERE id = p_pact_id;

  SELECT id INTO v_first_milestone_id
  FROM public.milestones
  WHERE pact_id = p_pact_id AND state = 'pending'
  ORDER BY ordinal LIMIT 1;

  IF v_first_milestone_id IS NOT NULL THEN
    UPDATE public.milestones
    SET state = 'in_execution',
        started_at = now()
    WHERE id = v_first_milestone_id;
  END IF;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'mock_funded',
    jsonb_build_object('first_milestone_id', v_first_milestone_id,
                       'note', 'DEV ONLY: mock del depósito Mangopay'),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_mock_funded', 'pact', p_pact_id,
    jsonb_build_object('first_milestone_id', v_first_milestone_id));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', 'in_execution',
    'first_milestone_id', v_first_milestone_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_mock_fund_pact TO authenticated;


DROP FUNCTION IF EXISTS public.sf_submit_milestone_for_review;
CREATE OR REPLACE FUNCTION public.sf_submit_milestone_for_review(
  p_milestone_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid        uuid;
  v_user_id         uuid;
  v_pact_id         uuid;
  v_milestone_state milestone_state;
  v_can_act         boolean;
  v_evidence_count  int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id, m.state INTO v_pact_id, v_milestone_state
  FROM public.milestones m WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  v_can_act := public.fn_user_acts_as_constructor_on_pact(v_pact_id, v_user_id);
  IF NOT v_can_act THEN
    RAISE EXCEPTION 'Solo el constructor (o su equipo) puede marcar el hito como listo';
  END IF;

  IF v_milestone_state NOT IN ('in_execution', 'info_requested') THEN
    RAISE EXCEPTION 'El hito no está en ejecución (estado actual: %)', v_milestone_state;
  END IF;

  SELECT count(*) INTO v_evidence_count
  FROM public.milestone_evidences
  WHERE milestone_id = p_milestone_id AND NOT is_superseded;

  IF v_evidence_count < 1 THEN
    RAISE EXCEPTION 'Debes subir al menos 1 evidencia antes de marcar el hito como listo';
  END IF;

  UPDATE public.milestones
  SET state = 'ready_for_review', submitted_at = now()
  WHERE id = p_milestone_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact_id, 'milestone_submitted_for_review',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'evidence_count', v_evidence_count
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'milestone_submitted', 'milestone', p_milestone_id,
    jsonb_build_object('evidence_count', v_evidence_count));

  RETURN jsonb_build_object(
    'success', true,
    'milestone_state', 'ready_for_review',
    'evidence_count', v_evidence_count
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_submit_milestone_for_review TO authenticated;

NOTIFY pgrst, 'reload schema';
