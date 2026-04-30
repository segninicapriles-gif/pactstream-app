-- =====================================================================
-- Sprint 1 · Migration 0002
-- Funciones RPC para registro de usuarios.
-- =====================================================================
-- Esta migration añade:
--   1. RPC sf_complete_registration: crea public.users + legal_consents
--      en una sola transacción tras el alta en auth.users.
--   2. Política RLS: permitir al usuario insertar SU propia fila en
--      public.users (alternativa para casos donde la RPC no se use).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Política RLS: permitir auto-insertar la fila en public.users
-- ---------------------------------------------------------------------
-- Solo permite que un usuario autenticado inserte una fila en public.users
-- si el auth_provider_id coincide con su propio JWT sub claim.
DROP POLICY IF EXISTS users_self_insert ON public.users;
CREATE POLICY users_self_insert ON public.users FOR INSERT
  WITH CHECK (auth_provider_id = (auth.uid())::text);

-- ---------------------------------------------------------------------
-- RPC: sf_complete_registration
-- ---------------------------------------------------------------------
-- Llamada desde la app tras supabase.auth.signUp(). Crea el perfil del
-- usuario en public.users y registra los consentimientos legales en
-- legal_consents. Atómico: si falla algo, rollback.
--
-- Args:
--   p_full_name         : nombre completo
--   p_phone_e164        : teléfono en formato E.164 (+34...)
--   p_primary_role      : 'promotor' | 'constructor' | 'tecnico'
--   p_organization_name : nombre de empresa (solo constructor/promotor corp.)
--   p_cif_or_nif        : CIF (constructor) o NIF (promotor/técnico)
--   p_province          : provincia (string, ISO o nombre)
--   p_profession        : titulación profesional (solo técnico)
--   p_colegio           : colegio profesional (solo técnico)
--   p_num_colegiacion   : número de colegiación (solo técnico)
--   p_terms_version     : versión del documento de Términos aceptado
--   p_privacy_version   : versión del documento de Privacidad aceptado
--
-- Returns:
--   uuid : el id del usuario creado en public.users
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_complete_registration;
CREATE OR REPLACE FUNCTION public.sf_complete_registration(
  p_full_name         text,
  p_phone_e164        text,
  p_primary_role      text,
  p_organization_name text DEFAULT NULL,
  p_cif_or_nif        text DEFAULT NULL,
  p_province          text DEFAULT NULL,
  p_profession        text DEFAULT NULL,
  p_colegio           text DEFAULT NULL,
  p_num_colegiacion   text DEFAULT NULL,
  p_terms_version     text DEFAULT '1.0',
  p_privacy_version   text DEFAULT '1.0'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid     uuid;
  v_email        text;
  v_user_id      uuid;
  v_org_id       uuid;
BEGIN
  -- Autenticación obligatoria
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado. Llamar después de signUp.';
  END IF;

  -- Email del JWT
  SELECT email INTO v_email FROM auth.users WHERE id = v_auth_uid;
  IF v_email IS NULL THEN
    RAISE EXCEPTION 'Usuario auth sin email asociado.';
  END IF;

  -- Validar rol
  IF p_primary_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RAISE EXCEPTION 'Rol inválido: %', p_primary_role;
  END IF;

  -- Si es constructor con datos de empresa, crear organización primero
  IF p_primary_role = 'constructor' AND p_organization_name IS NOT NULL THEN
    INSERT INTO public.organizations (legal_name, cif, province)
    VALUES (p_organization_name, p_cif_or_nif, p_province)
    RETURNING id INTO v_org_id;
  END IF;

  -- Crear perfil en public.users
  INSERT INTO public.users (
    auth_provider_id,
    full_name,
    email,
    phone_e164,
    national_id,
    province,
    primary_role,
    profession,
    colegio,
    num_colegiacion,
    organization_id,
    kyc_status
  ) VALUES (
    v_auth_uid::text,
    p_full_name,
    v_email,
    p_phone_e164,
    CASE WHEN p_primary_role IN ('promotor', 'tecnico') THEN p_cif_or_nif END,
    p_province,
    p_primary_role::user_role,
    p_profession,
    p_colegio,
    p_num_colegiacion,
    v_org_id,
    'not_started'
  )
  RETURNING id INTO v_user_id;

  -- Registrar consentimientos legales (RGPD trazabilidad)
  INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash, ip_address)
  VALUES
    (v_user_id, 'terms_of_service', p_terms_version, 'sha256_placeholder_terms_v' || p_terms_version, NULL),
    (v_user_id, 'privacy_policy',   p_privacy_version, 'sha256_placeholder_privacy_v' || p_privacy_version, NULL);

  -- Audit
  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_user_id, 'user_registered', 'user', v_user_id);

  RETURN v_user_id;
END;
$$;

-- Permitir a usuarios autenticados llamar la RPC
GRANT EXECUTE ON FUNCTION public.sf_complete_registration TO authenticated;

COMMENT ON FUNCTION public.sf_complete_registration IS
  'Sprint 1: completa el registro tras auth.signUp. Crea public.users + legal_consents en transacción atómica.';
