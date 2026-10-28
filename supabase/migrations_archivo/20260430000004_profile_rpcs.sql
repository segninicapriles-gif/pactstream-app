-- =====================================================================
-- Sprint 1 chunk 4 · Migration 0006
-- RPCs para gestión del perfil de usuario.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_get_my_profile_extended: igual que sf_get_my_profile pero con
-- todos los campos del perfil (no solo los básicos).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_get_my_profile_extended;
CREATE OR REPLACE FUNCTION public.sf_get_my_profile_extended()
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  phone_e164 text,
  primary_role user_role,
  national_id text,
  province text,
  profession text,
  colegio text,
  num_colegiacion text,
  organization_id uuid,
  organization_name text,
  organization_cif text,
  kyc_status kyc_status,
  kyc_verified_at timestamptz,
  kyc_provider text,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id, u.full_name, u.email, u.phone_e164,
    u.primary_role, u.national_id, u.province,
    u.profession, u.colegio, u.num_colegiacion,
    u.organization_id, o.legal_name, o.cif,
    u.kyc_status, u.kyc_verified_at, u.kyc_provider,
    u.created_at
  FROM public.users u
  LEFT JOIN public.organizations o ON o.id = u.organization_id
  WHERE u.auth_provider_id = (auth.uid())::text
    AND u.deleted_at IS NULL;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_my_profile_extended TO authenticated;

-- ---------------------------------------------------------------------
-- sf_delete_my_account: derecho de supresión RGPD.
-- ---------------------------------------------------------------------
-- Soft delete: marca deleted_at en public.users. La supresión real
-- (anonimización + hard delete) se ejecuta en un job nocturno tras 12
-- meses (data_model doc §5.5), respetando los plazos legales:
--   - Datos del pacto: 10 años (LOE responsabilidad civil decenal)
--   - Datos KYC: 10 años (Ley 10/2010 PBC)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_delete_my_account;
CREATE OR REPLACE FUNCTION public.sf_delete_my_account(
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_active_pacts int;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT id INTO v_user_id
  FROM public.users
  WHERE auth_provider_id = v_auth_uid::text
    AND deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado o ya eliminado';
  END IF;

  -- Verificar que no tenga pactos activos (no puede borrar cuenta con
  -- compromisos legales en curso)
  SELECT count(*) INTO v_active_pacts
  FROM public.pact_parties pp
  JOIN public.pacts p ON p.id = pp.pact_id
  WHERE pp.user_id = v_user_id
    AND p.state IN ('inviting', 'signing', 'signed', 'funded',
                    'in_execution', 'disputed', 'suspended');

  IF v_active_pacts > 0 THEN
    RAISE EXCEPTION 'No puedes borrar tu cuenta con % pactos activos. Cierra o cancela los pactos primero.', v_active_pacts;
  END IF;

  -- Soft delete
  UPDATE public.users SET deleted_at = now() WHERE id = v_user_id;

  -- Audit
  INSERT INTO public.audit_log(actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (
    v_user_id, 'account_deleted', 'user', v_user_id,
    jsonb_build_object('reason', p_reason, 'mode', 'soft_delete')
  );

  RETURN v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_delete_my_account TO authenticated;

COMMENT ON FUNCTION public.sf_delete_my_account IS
  'RGPD · derecho de supresión. Soft delete + audit. Hard delete + anonimización por job tras plazos legales.';
