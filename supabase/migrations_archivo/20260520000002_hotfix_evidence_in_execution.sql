-- =====================================================================
-- HOTFIX · sf_record_milestone_evidence
-- =====================================================================
-- Bug histórico Sprint 4: la RPC chequeaba 'in_progress' que no existe
-- en el enum milestone_state (el valor real es 'in_execution'). Esto
-- hacía que cualquier intento de subir evidencia fallase con
--   ERROR 22P02: invalid input value for enum milestone_state
--
-- Esta migración:
--   * Corrige el chequeo a 'in_execution', 'ready_for_review',
--     'info_requested' (último para re-submission tras petición de info).
--   * Mantiene la lógica de Sprint 6 chunk 5b: acepta uploads de party
--     directo O miembros activos de la org constructora; preserva el
--     uploaded_by_user_id real para la cadena de custodia forense.
-- =====================================================================

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
  v_milestone_state milestone_state;
  v_evidence_id     uuid;
  v_can_act         boolean;
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

  SELECT m.pact_id, m.state INTO v_pact_id, v_milestone_state
  FROM public.milestones m WHERE m.id = p_milestone_id;

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

  RETURN v_evidence_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_record_milestone_evidence TO authenticated;

NOTIFY pgrst, 'reload schema';
