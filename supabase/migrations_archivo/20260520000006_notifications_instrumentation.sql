-- =====================================================================
-- Sprint 6 chunk 6b · Instrumentación de notificaciones en RPCs core
-- =====================================================================
-- Reescribe 3 RPCs añadiendo INSERT a notifications justo antes del
-- RETURN:
--   1. sf_mock_fund_pact            → "Obra activada"
--   2. sf_record_milestone_evidence → "Nueva evidencia subida"
--   3. sf_submit_milestone_for_review → "Hito listo para revisar"
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
  v_pact_title        text;
  v_first_milestone_id uuid;
  v_recipients        uuid[];
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

  SELECT state, title INTO v_pact_state, v_pact_title
  FROM public.pacts WHERE id = p_pact_id;

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
    SET state = 'in_execution', started_at = now()
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

  SELECT array_agg(user_id) INTO v_recipients
  FROM public.fn_notification_recipients(p_pact_id, NULL, false, v_user_id);

  PERFORM public.fn_create_notifications(
    p_user_ids        := v_recipients,
    p_notification_type := 'pact_funded',
    p_title           := 'Obra activada · ' || coalesce(v_pact_title, 'Sin título'),
    p_body            := 'El promotor ha depositado el fondo de garantía. El primer hito ya está en ejecución.',
    p_pact_id         := p_pact_id,
    p_milestone_id    := v_first_milestone_id,
    p_cta_url         := '/pacts/' || p_pact_id::text,
    p_priority        := 'high'
  );

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', 'in_execution',
    'first_milestone_id', v_first_milestone_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_mock_fund_pact TO authenticated;


DROP FUNCTION IF EXISTS public.sf_record_milestone_evidence;
CREATE OR REPLACE FUNCTION public.sf_record_milestone_evidence(
  p_milestone_id      uuid,
  p_evidence_type     text,
  p_storage_path      text,
  p_sha256_hash       text,
  p_file_size_bytes   bigint  DEFAULT NULL,
  p_mime_type         text    DEFAULT NULL,
  p_gps_latitude      double precision DEFAULT NULL,
  p_gps_longitude     double precision DEFAULT NULL,
  p_gps_accuracy_meters double precision DEFAULT NULL,
  p_client_timestamp  timestamptz DEFAULT NULL,
  p_description       text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid        uuid;
  v_user_id         uuid;
  v_pact_id         uuid;
  v_pact_title      text;
  v_milestone_name  text;
  v_milestone_state milestone_state;
  v_evidence_id     uuid;
  v_can_act         boolean;
  v_actor_name      text;
  v_recipients      uuid[];
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.full_name INTO v_user_id, v_actor_name
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id, m.state, m.name, p.title
    INTO v_pact_id, v_milestone_state, v_milestone_name, v_pact_title
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  v_can_act := public.fn_user_acts_as_constructor_on_pact(v_pact_id, v_user_id);
  IF NOT v_can_act THEN
    RAISE EXCEPTION 'Solo el constructor (o su equipo) puede subir evidencias';
  END IF;

  IF v_milestone_state NOT IN ('in_execution', 'ready_for_review', 'info_requested') THEN
    RAISE EXCEPTION 'No se pueden subir evidencias en estado: %', v_milestone_state;
  END IF;

  IF p_evidence_type NOT IN ('photo', 'video', 'audio', 'document', 'note') THEN
    RAISE EXCEPTION 'Tipo de evidencia inválido: %', p_evidence_type;
  END IF;

  INSERT INTO public.milestone_evidences (
    milestone_id, uploaded_by_user_id, evidence_type,
    storage_path, file_size_bytes, mime_type, sha256_hash,
    gps_latitude, gps_longitude, gps_accuracy_meters,
    client_timestamp, description
  ) VALUES (
    p_milestone_id, v_user_id, p_evidence_type::evidence_type,
    p_storage_path, p_file_size_bytes, p_mime_type, p_sha256_hash,
    p_gps_latitude, p_gps_longitude, p_gps_accuracy_meters,
    coalesce(p_client_timestamp, now()), p_description
  )
  RETURNING id INTO v_evidence_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact_id, 'evidence_uploaded',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'evidence_id', v_evidence_id,
      'type', p_evidence_type
    ),
    v_user_id);

  SELECT array_agg(user_id) INTO v_recipients
  FROM public.fn_notification_recipients(v_pact_id, NULL, false, v_user_id);

  PERFORM public.fn_create_notifications(
    p_user_ids        := v_recipients,
    p_notification_type := 'evidence_uploaded',
    p_title           := 'Nueva evidencia · ' || coalesce(v_milestone_name, 'Hito'),
    p_body            := coalesce(v_actor_name, 'Un miembro del equipo') ||
                         ' subió una ' ||
                         CASE p_evidence_type
                           WHEN 'photo' THEN 'foto'
                           WHEN 'video' THEN 'vídeo'
                           WHEN 'audio' THEN 'nota de audio'
                           WHEN 'document' THEN 'documento'
                           ELSE 'evidencia'
                         END ||
                         ' al hito de "' || coalesce(v_pact_title, 'la obra') || '".',
    p_pact_id         := v_pact_id,
    p_milestone_id    := p_milestone_id,
    p_cta_url         := '/pacts/' || v_pact_id::text || '/milestones/' || p_milestone_id::text,
    p_priority        := 'normal',
    p_idempotency_root := 'evidence:' || v_evidence_id::text
  );

  RETURN v_evidence_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_record_milestone_evidence TO authenticated;


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
  v_pact_title      text;
  v_pact_type       text;
  v_milestone_state milestone_state;
  v_milestone_name  text;
  v_can_act         boolean;
  v_evidence_count  int;
  v_target_roles    text[];
  v_recipients      uuid[];
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id, m.state, m.name, p.title, p.pact_type::text
    INTO v_pact_id, v_milestone_state, v_milestone_name, v_pact_title, v_pact_type
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

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

  v_target_roles := CASE v_pact_type
                      WHEN 'obra_mayor' THEN ARRAY['tecnico']
                      ELSE ARRAY['promotor']
                    END;

  SELECT array_agg(user_id) INTO v_recipients
  FROM public.fn_notification_recipients(v_pact_id, v_target_roles, false, v_user_id);

  PERFORM public.fn_create_notifications(
    p_user_ids        := v_recipients,
    p_notification_type := 'milestone_submitted',
    p_title           := 'Hito listo para revisar · ' || coalesce(v_milestone_name, 'Sin nombre'),
    p_body            := 'El constructor ha enviado el hito de "' ||
                         coalesce(v_pact_title, 'la obra') || '" para tu validación con ' ||
                         v_evidence_count::text || ' evidencia' ||
                         CASE WHEN v_evidence_count = 1 THEN '' ELSE 's' END || '.',
    p_pact_id         := v_pact_id,
    p_milestone_id    := p_milestone_id,
    p_cta_url         := '/pacts/' || v_pact_id::text || '/milestones/' || p_milestone_id::text,
    p_priority        := 'high',
    p_idempotency_root := 'milestone_submitted:' || p_milestone_id::text
  );

  RETURN jsonb_build_object(
    'success', true,
    'milestone_state', 'ready_for_review',
    'evidence_count', v_evidence_count
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_submit_milestone_for_review TO authenticated;

NOTIFY pgrst, 'reload schema';
