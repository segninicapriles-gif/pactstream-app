-- =====================================================================
-- Sprint 2 chunk 4 · Migration 0015
-- Mock fund + RPCs de evidencias + bucket Storage + policies.
-- =====================================================================
-- Funciones:
--   sf_mock_fund_pact(p_pact_id)
--     Solo dev. Mueve pact de 'signed' a 'in_execution' y arranca el
--     primer hito. Sustituye al flujo Mangopay del chunk 5.
--
--   sf_record_milestone_evidence(...)
--     Registra una evidencia ya subida a Storage. Append-only.
--
--   sf_submit_milestone_for_review(p_milestone_id)
--     El constructor declara que el hito está listo para revisión técnica.
--     Hito pasa de in_progress → ready_for_review.
--
--   sf_get_milestone_detail(p_milestone_id)
--     JSON con hito + evidencias. Solo accesible para partes del pacto.
--
-- Storage:
--   bucket 'milestone-evidences' privado, con policies RLS para que
--   solo las partes del pacto puedan subir y leer.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_mock_fund_pact (DEV ONLY)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_mock_fund_pact;
CREATE OR REPLACE FUNCTION public.sf_mock_fund_pact(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_state pact_state;
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

  -- Validar que el caller es parte del pacto
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

  -- Pact pasa a in_execution
  UPDATE public.pacts
  SET state = 'in_execution'
  WHERE id = p_pact_id;

  -- Arrancar el primer hito (ordinal 1)
  SELECT id INTO v_first_milestone_id
  FROM public.milestones
  WHERE pact_id = p_pact_id AND state = 'pending'
  ORDER BY ordinal LIMIT 1;

  IF v_first_milestone_id IS NOT NULL THEN
    UPDATE public.milestones
    SET state = 'in_progress', started_at = now()
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


-- ---------------------------------------------------------------------
-- sf_record_milestone_evidence
-- ---------------------------------------------------------------------
-- Registra una evidencia tras subirla a Storage. La subida del fichero
-- se hace desde el cliente directamente al bucket; este RPC solo crea
-- la fila en milestone_evidences. Append-only.
DROP FUNCTION IF EXISTS public.sf_record_milestone_evidence;
CREATE OR REPLACE FUNCTION public.sf_record_milestone_evidence(
  p_milestone_id uuid,
  p_evidence_type text,
  p_storage_path text,
  p_sha256_hash text,
  p_file_size_bytes bigint DEFAULT NULL,
  p_mime_type text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_gps_latitude numeric DEFAULT NULL,
  p_gps_longitude numeric DEFAULT NULL,
  p_gps_accuracy_meters numeric DEFAULT NULL,
  p_client_timestamp timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_id  uuid;
  v_milestone_state milestone_state;
  v_evidence_id uuid;
  v_user_role pact_party_role;
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

  -- Cargar hito + pact
  SELECT m.pact_id, m.state INTO v_pact_id, v_milestone_state
  FROM public.milestones m WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  -- Validar que el caller es parte del pacto y obtener su rol
  SELECT role INTO v_user_role
  FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  -- Solo el constructor sube evidencias en MVP
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede subir evidencias';
  END IF;

  -- El hito debe estar en un estado que permita evidencias
  IF v_milestone_state NOT IN ('in_progress', 'ready_for_review') THEN
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


-- ---------------------------------------------------------------------
-- sf_submit_milestone_for_review
-- ---------------------------------------------------------------------
-- El constructor declara que el hito está listo. Pasa a ready_for_review.
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
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_id  uuid;
  v_milestone_state milestone_state;
  v_user_role pact_party_role;
  v_evidence_count int;
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

  SELECT role INTO v_user_role
  FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;

  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede marcar el hito como listo';
  END IF;

  IF v_milestone_state != 'in_progress' THEN
    RAISE EXCEPTION 'El hito no está en progreso (estado actual: %)', v_milestone_state;
  END IF;

  -- Exigir al menos 1 evidencia activa
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


-- ---------------------------------------------------------------------
-- sf_get_milestone_detail
-- ---------------------------------------------------------------------
-- Detalle del hito + evidencias en JSON. Solo para partes del pacto.
DROP FUNCTION IF EXISTS public.sf_get_milestone_detail;
CREATE OR REPLACE FUNCTION public.sf_get_milestone_detail(p_milestone_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_id  uuid;
  v_user_role pact_party_role;
  v_result jsonb;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id INTO v_pact_id
  FROM public.milestones m WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  SELECT role INTO v_user_role
  FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No tienes acceso a este hito';
  END IF;

  SELECT jsonb_build_object(
    'milestone', jsonb_build_object(
      'id', m.id,
      'pact_id', m.pact_id,
      'pact_display_id', p.display_id,
      'pact_title', p.title,
      'pact_type', p.pact_type::text,
      'display_id', m.display_id,
      'ordinal', m.ordinal,
      'name', m.name,
      'description', m.description,
      'amount_cents', m.amount_cents,
      'target_date', m.target_date,
      'state', m.state::text,
      'state_updated_at', m.state_updated_at,
      'started_at', m.started_at,
      'submitted_at', m.submitted_at,
      'validated_at', m.validated_at,
      'approved_by_promotor_at', m.approved_by_promotor_at,
      'rejected_at', m.rejected_at,
      'paid_at', m.paid_at,
      'my_role', v_user_role::text
    ),
    'evidences', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', e.id,
        'evidence_type', e.evidence_type::text,
        'storage_path', e.storage_path,
        'file_size_bytes', e.file_size_bytes,
        'mime_type', e.mime_type,
        'description', e.description,
        'gps_latitude', e.gps_latitude,
        'gps_longitude', e.gps_longitude,
        'gps_accuracy_meters', e.gps_accuracy_meters,
        'client_timestamp', e.client_timestamp,
        'server_timestamp', e.server_timestamp,
        'sha256_hash', e.sha256_hash,
        'is_superseded', e.is_superseded,
        'uploaded_by_user_id', e.uploaded_by_user_id,
        'uploaded_by_name', uploader.full_name,
        'is_mine', (e.uploaded_by_user_id = v_user_id)
      ) ORDER BY e.server_timestamp DESC)
      FROM public.milestone_evidences e
      LEFT JOIN public.users uploader ON uploader.id = e.uploaded_by_user_id
      WHERE e.milestone_id = p_milestone_id
        AND NOT e.is_superseded
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_milestone_detail TO authenticated;


-- ---------------------------------------------------------------------
-- BUCKET DE STORAGE: milestone-evidences
-- ---------------------------------------------------------------------
-- Bucket privado. Las evidencias son confidenciales y solo accesibles
-- para las partes del pacto.
-- Nota: storage.buckets se gestiona vía storage.create_bucket().
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'milestone-evidences',
  'milestone-evidences',
  false, -- privado
  20971520, -- 20 MB max por archivo
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic',
        'video/mp4', 'video/quicktime',
        'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;


-- ---------------------------------------------------------------------
-- POLICIES RLS sobre storage.objects
-- ---------------------------------------------------------------------
-- Path esperado: {pact_id}/{milestone_id}/{filename}
-- Validamos que el caller sea parte del pacto del primer segmento del path.

-- INSERT: solo el constructor del pacto puede subir
DROP POLICY IF EXISTS "milestone_evidences_insert_constructor"
  ON storage.objects;
CREATE POLICY "milestone_evidences_insert_constructor"
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'milestone-evidences'
    AND EXISTS (
      SELECT 1
      FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE u.auth_provider_id = (auth.uid())::text
        AND pp.role = 'constructor'
        AND pp.pact_id::text = split_part(name, '/', 1)
    )
  );

-- SELECT: cualquier parte del pacto puede leer
DROP POLICY IF EXISTS "milestone_evidences_select_party"
  ON storage.objects;
CREATE POLICY "milestone_evidences_select_party"
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'milestone-evidences'
    AND EXISTS (
      SELECT 1
      FROM public.pact_parties pp
      JOIN public.users u ON u.id = pp.user_id
      WHERE u.auth_provider_id = (auth.uid())::text
        AND pp.pact_id::text = split_part(name, '/', 1)
    )
  );

-- DELETE: bloqueado (append-only)
DROP POLICY IF EXISTS "milestone_evidences_no_delete"
  ON storage.objects;
CREATE POLICY "milestone_evidences_no_delete"
  ON storage.objects
  FOR DELETE TO authenticated
  USING (false);

-- UPDATE: bloqueado (append-only)
DROP POLICY IF EXISTS "milestone_evidences_no_update"
  ON storage.objects;
CREATE POLICY "milestone_evidences_no_update"
  ON storage.objects
  FOR UPDATE TO authenticated
  USING (false);


-- ---------------------------------------------------------------------
-- Comentarios + reload schema
-- ---------------------------------------------------------------------
COMMENT ON FUNCTION public.sf_mock_fund_pact IS
  'DEV ONLY. Mock del depósito Mangopay. Pact: signed → in_execution. Primer hito: pending → in_progress.';
COMMENT ON FUNCTION public.sf_record_milestone_evidence IS
  'Registra evidencia tras subirla a Storage. Solo el constructor. Append-only.';
COMMENT ON FUNCTION public.sf_submit_milestone_for_review IS
  'Constructor declara hito listo. Requiere ≥1 evidencia activa. Hito → ready_for_review.';
COMMENT ON FUNCTION public.sf_get_milestone_detail IS
  'Detalle hito + evidencias. Solo para partes del pacto.';

NOTIFY pgrst, 'reload schema';
