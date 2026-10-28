-- ---------------------------------------------------------------------------
-- Profile edit · Sprint 8
-- Agrega avatar_url a public.users, bucket de Storage para avatares,
-- RPC sf_update_my_profile y actualiza sf_get_my_profile_extended.
-- ---------------------------------------------------------------------------

-- 1 · Columna avatar_url en public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2 · Bucket de Storage para avatares (público, máx. 5 MB, solo imágenes)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 3 · RLS en storage.objects para el bucket avatars
--     El nombre de archivo es {auth_uid}.jpg / .png / etc.
DROP POLICY IF EXISTS "Avatars public read"   ON storage.objects;
DROP POLICY IF EXISTS "Avatars owner upload"  ON storage.objects;
DROP POLICY IF EXISTS "Avatars owner update"  ON storage.objects;
DROP POLICY IF EXISTS "Avatars owner delete"  ON storage.objects;

CREATE POLICY "Avatars public read"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

CREATE POLICY "Avatars owner upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Avatars owner update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Avatars owner delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4 · RPC de actualización de perfil
-- Solo permite editar full_name, phone_e164 y avatar_url.
-- Los campos de identidad (national_id, kyc_status, etc.) son inmutables vía esta RPC.
-- RETURNS VOID: Flutter llama _load() después, no necesita el valor de retorno.
DROP FUNCTION IF EXISTS public.sf_update_my_profile(text, text, text);
CREATE OR REPLACE FUNCTION public.sf_update_my_profile(
  p_full_name   text    DEFAULT NULL,
  p_phone_e164  text    DEFAULT NULL,
  p_avatar_url  text    DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM public.users
  WHERE auth_provider_id = auth.uid()::text
    AND deleted_at IS NULL
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.users
  SET
    full_name  = COALESCE(p_full_name,  full_name),
    phone_e164 = COALESCE(p_phone_e164, phone_e164),
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    updated_at = now()
  WHERE id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_update_my_profile TO authenticated;

COMMENT ON FUNCTION public.sf_update_my_profile IS
  'Sprint 8 · Actualiza full_name, phone_e164 y avatar_url del usuario autenticado.';

-- 5 · Actualizar sf_get_my_profile_extended para incluir avatar_url
DROP FUNCTION IF EXISTS public.sf_get_my_profile_extended;
CREATE OR REPLACE FUNCTION public.sf_get_my_profile_extended()
RETURNS TABLE (
  id                uuid,
  full_name         text,
  email             text,
  phone_e164        text,
  avatar_url        text,
  primary_role      user_role,
  national_id       text,
  province          text,
  profession        text,
  colegio           text,
  num_colegiacion   text,
  organization_id   uuid,
  organization_name text,
  organization_cif  text,
  kyc_status        kyc_status,
  kyc_verified_at   timestamptz,
  kyc_provider      text,
  created_at        timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id, u.full_name, u.email, u.phone_e164, u.avatar_url,
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
