-- =====================================================================
-- Sprint 1 · Migration 0004
-- RPCs para flujo KYC (mock + preparado para Onfido real en V2).
-- =====================================================================
-- Esta migration añade:
--   1. RPC sf_simulate_kyc_verification: para desarrollo, marca el KYC
--      del usuario actual como 'verified' instantáneamente.
--   2. RPC sf_get_my_profile: lee el perfil del usuario autenticado.
--      Útil para que el cliente sepa el kyc_status sin hacer queries
--      directas a la tabla.
--
-- En V2 con Onfido real:
--   - sf_simulate_kyc_verification se reemplaza por un webhook handler
--     que recibe el callback de Onfido y actualiza kyc_status.
--   - El cliente no llama directamente — Onfido SDK + redirect, y la
--     transición la hace el webhook server-side.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_get_my_profile: obtiene el perfil del usuario autenticado
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_get_my_profile;
CREATE OR REPLACE FUNCTION public.sf_get_my_profile()
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  primary_role user_role,
  kyc_status kyc_status,
  organization_id uuid,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id, u.full_name, u.email, u.primary_role, u.kyc_status,
         u.organization_id, u.created_at
  FROM public.users u
  WHERE u.auth_provider_id = (auth.uid())::text
    AND u.deleted_at IS NULL;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_my_profile TO authenticated;

COMMENT ON FUNCTION public.sf_get_my_profile IS
  'Devuelve el perfil del usuario autenticado actual. Devuelve 0 filas si no existe perfil.';

-- ---------------------------------------------------------------------
-- sf_simulate_kyc_verification: MOCK · solo para desarrollo
-- ---------------------------------------------------------------------
-- Marca el kyc_status del usuario actual como 'verified'.
-- Cuando integremos Onfido real, esta RPC se elimina y la transición
-- la hace el webhook handler de Onfido. Mientras tanto, permite
-- testear el flujo end-to-end sin dependencia externa.
--
-- Args:
--   p_decision : 'verified' | 'pending_review' | 'rejected'
--   p_reason   : motivo (opcional, solo si rejected)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_simulate_kyc_verification;
CREATE OR REPLACE FUNCTION public.sf_simulate_kyc_verification(
  p_decision text DEFAULT 'verified',
  p_reason   text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  kyc_status kyc_status,
  kyc_verified_at timestamptz
)
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

  -- Validar decision
  IF p_decision NOT IN ('verified', 'pending_review', 'rejected') THEN
    RAISE EXCEPTION 'Decision inválida: %', p_decision;
  END IF;

  v_status := p_decision::kyc_status;

  UPDATE public.users
  SET kyc_status = v_status,
      kyc_verified_at = CASE WHEN v_status = 'verified' THEN now() ELSE kyc_verified_at END,
      kyc_provider = 'onfido_mock_dev',
      kyc_external_id = 'mock_' || extract(epoch from now())::text
  WHERE auth_provider_id = v_auth_uid::text
  RETURNING users.id INTO v_user_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado para el usuario autenticado';
  END IF;

  -- Audit log
  INSERT INTO public.audit_log(actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (
    v_user_id,
    'kyc_simulated',
    'user',
    v_user_id,
    jsonb_build_object('decision', p_decision, 'reason', p_reason, 'mode', 'dev_mock')
  );

  RETURN QUERY
    SELECT u.id, u.kyc_status, u.kyc_verified_at
    FROM public.users u
    WHERE u.id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_simulate_kyc_verification TO authenticated;

COMMENT ON FUNCTION public.sf_simulate_kyc_verification IS
  'MOCK · Sprint 1 chunk 2. En producción se elimina y se reemplaza por webhook handler de Onfido.';
