-- =====================================================================
-- Sprint 1 · Migration 0005 (HOTFIX)
-- Corrige la ambigüedad de kyc_verified_at en sf_simulate_kyc_verification.
-- =====================================================================
-- Bug: el RETURNS TABLE creaba un OUT parameter con el mismo nombre
-- que la columna, y la cláusula CASE no podía resolver a cuál se refería.
-- Fix: usar alias de tabla en el UPDATE + simplificar a RETURNS uuid.
-- =====================================================================

DROP FUNCTION IF EXISTS public.sf_simulate_kyc_verification;

CREATE OR REPLACE FUNCTION public.sf_simulate_kyc_verification(
  p_decision text DEFAULT 'verified',
  p_reason   text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_status   kyc_status;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  IF p_decision NOT IN ('verified', 'pending_review', 'rejected') THEN
    RAISE EXCEPTION 'Decision inválida: %', p_decision;
  END IF;

  v_status := p_decision::kyc_status;

  UPDATE public.users u
  SET kyc_status      = v_status,
      kyc_verified_at = CASE WHEN v_status = 'verified' THEN now() ELSE u.kyc_verified_at END,
      kyc_provider    = 'onfido_mock_dev',
      kyc_external_id = 'mock_' || extract(epoch from now())::text
  WHERE u.auth_provider_id = v_auth_uid::text
  RETURNING u.id INTO v_user_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado para el usuario autenticado';
  END IF;

  INSERT INTO public.audit_log(actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (
    v_user_id,
    'kyc_simulated',
    'user',
    v_user_id,
    jsonb_build_object('decision', p_decision, 'reason', p_reason, 'mode', 'dev_mock')
  );

  RETURN v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_simulate_kyc_verification TO authenticated;
