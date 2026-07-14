-- =====================================================================
-- Migración · P1-4 auditoría UX 14-jul-2026
-- sf_get_milestone_detail: exponer el motivo de la última validación.
-- =====================================================================
-- PROBLEMA: cuando el técnico rechaza un hito o pide más información,
-- escribe un `rationale` que se guarda en `milestone_validations`, pero
-- sf_get_milestone_detail no lo devuelve. El constructor ve el banner
-- "Revisa las observaciones" sin poder leer las observaciones.
--
-- CAMBIO (aditivo): se añade al objeto `milestone` del JSON la última
-- validación registrada para el hito:
--   - last_validation_decision   ('approved'|'rejected'|'info_requested')
--   - last_validation_rationale  (texto libre de quien validó, puede ser null)
--   - last_validation_at         (timestamptz de la decisión)
--   - last_validation_by_name    (full_name del validador, puede ser null)
--
-- El resto del payload es idéntico a la definición previa
-- (20260430000013_milestone_evidence_rpcs.sql). La app Flutter ya lee
-- estos campos como opcionales, así que aplicar o no esta migración no
-- rompe versiones antiguas ni nuevas del cliente.
--
-- NOTA IMPORTANTE ANTES DE APLICAR: esta definición parte de la última
-- versión de la función presente en este repo (migración ...000013). Si
-- la función desplegada en la base de datos se modificó fuera de las
-- migraciones (p. ej. campos de evidencia añadidos en Sprint 6 como
-- uploaded_by_email / uploader_via_org_name, que el cliente Dart lee
-- como opcionales pero que NO aparecen en ninguna migración del repo),
-- hay que fusionar esos campos aquí antes de ejecutar, o se perderían.
-- Verificar con:  select pg_get_functiondef('public.sf_get_milestone_detail'::regproc);

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
      'my_role', v_user_role::text,
      -- P1-4 · última validación registrada (rationale del técnico o
      -- del promotor en obra menor). NULL si aún no hay validaciones.
      'last_validation_decision', lv.decision,
      'last_validation_rationale', lv.rationale,
      'last_validation_at', lv.decision_at,
      'last_validation_by_name', lv.validator_name
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
  LEFT JOIN LATERAL (
    SELECT
      v.decision::text  AS decision,
      v.rationale       AS rationale,
      v.decision_at     AS decision_at,
      vu.full_name      AS validator_name
    FROM public.milestone_validations v
    LEFT JOIN public.users vu ON vu.id = v.validator_user_id
    WHERE v.milestone_id = m.id
    ORDER BY v.decision_at DESC
    LIMIT 1
  ) lv ON true
  WHERE m.id = p_milestone_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_milestone_detail TO authenticated;

COMMENT ON FUNCTION public.sf_get_milestone_detail IS
  'Detalle de hito + evidencias + última validación (rationale) en JSON. Solo partes del pacto.';

-- Recordatorio post-aplicación (PostgREST):
--   NOTIFY pgrst, 'reload schema';
