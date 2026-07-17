-- ---------------------------------------------------------------------
-- 20260717000003_profile_country_iso.sql
--
-- Expone `users.country_iso` en el perfil extendido para que la app
-- resuelva la MONEDA del usuario (P1-1 de la auditoría de consistencia de
-- ecosistema). Hasta ahora PactStream formateaba todo importe como `42.500 €`
-- fijo; CostPact ya es multi-moneda por país. La columna `country_iso`
-- (char(2), DEFAULT 'ES') ya existe en `users` desde el esquema inicial —
-- solo faltaba exponerla.
--
-- Cambio ADITIVO y de SOLO LECTURA: añade una columna al RETURNS TABLE de
-- una función SECURITY DEFINER. No toca datos. El cliente Flutter lee
-- `profile['country_iso']` con fallback a EUR/España, así que es compatible
-- hacia atrás.
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
  country_iso char(2),
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
    u.country_iso,
    u.created_at
  FROM public.users u
  LEFT JOIN public.organizations o ON o.id = u.organization_id
  WHERE u.auth_provider_id = (auth.uid())::text
    AND u.deleted_at IS NULL;
$$;

-- La superficie pública se mantiene: solo authenticated, nunca anon.
REVOKE ALL ON FUNCTION public.sf_get_my_profile_extended() FROM anon;
GRANT EXECUTE ON FUNCTION public.sf_get_my_profile_extended TO authenticated;
