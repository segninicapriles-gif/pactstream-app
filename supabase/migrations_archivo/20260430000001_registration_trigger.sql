-- =====================================================================
-- Sprint 1 · Migration 0003
-- Reemplaza el RPC de registro por un trigger en auth.users.
-- =====================================================================
-- Razón: el RPC anterior requería auth.uid() != NULL, pero tras signUp
-- con email confirmation requerido, el user NO está aún autenticado.
-- El trigger se ejecuta como SECURITY DEFINER y lee la metadata pasada
-- en raw_user_meta_data (vía el parámetro `data` de signUp).
-- =====================================================================

-- Limpieza del approach anterior
DROP POLICY IF EXISTS users_self_insert ON public.users;
DROP FUNCTION IF EXISTS public.sf_complete_registration CASCADE;

-- ---------------------------------------------------------------------
-- handle_new_auth_user
-- ---------------------------------------------------------------------
-- Se dispara AFTER INSERT en auth.users. Lee raw_user_meta_data y crea
-- public.users + legal_consents + organizations (si aplica).
--
-- Si la metadata no contiene 'primary_role', no hace nada (permite
-- crear users de prueba desde el dashboard sin afectar).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_meta    jsonb;
  v_user_id uuid;
  v_org_id  uuid;
  v_role    text;
BEGIN
  v_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  v_role := v_meta->>'primary_role';

  -- Sin metadata de PactStream → no hacer nada (user de admin/prueba)
  IF v_role IS NULL OR v_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RETURN NEW;
  END IF;

  -- Constructor con datos de empresa: crear organization primero
  IF v_role = 'constructor' AND COALESCE(v_meta->>'organization_name', '') <> '' THEN
    INSERT INTO public.organizations (legal_name, cif, province)
    VALUES (
      v_meta->>'organization_name',
      v_meta->>'cif_or_nif',
      v_meta->>'province'
    )
    RETURNING id INTO v_org_id;
  END IF;

  -- Crear public.users
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
    NEW.id::text,
    COALESCE(v_meta->>'full_name', NEW.email),
    NEW.email,
    v_meta->>'phone_e164',
    CASE WHEN v_role IN ('promotor', 'tecnico') THEN v_meta->>'cif_or_nif' END,
    v_meta->>'province',
    v_role::user_role,
    v_meta->>'profession',
    v_meta->>'colegio',
    v_meta->>'num_colegiacion',
    v_org_id,
    'not_started'
  )
  RETURNING id INTO v_user_id;

  -- Consentimientos legales (RGPD trazabilidad)
  INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
  VALUES
    (v_user_id, 'terms_of_service',
     COALESCE(v_meta->>'terms_version', '1.0'),
     'sha256_placeholder_terms'),
    (v_user_id, 'privacy_policy',
     COALESCE(v_meta->>'privacy_version', '1.0'),
     'sha256_placeholder_privacy');

  -- Audit log
  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_user_id, 'user_registered', 'user', v_user_id);

  RETURN NEW;
END;
$$;

-- Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

COMMENT ON FUNCTION public.handle_new_auth_user IS
  'Sprint 1: completa el registro automáticamente al crear auth.users. Lee raw_user_meta_data del signUp.';
