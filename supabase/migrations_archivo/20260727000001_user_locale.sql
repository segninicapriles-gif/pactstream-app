-- ---------------------------------------------------------------------
-- 20260727000001_user_locale.sql
--
-- Preferencia de IDIOMA del usuario, para la versión en inglés
-- norteamericano de la app.
--
-- Eje independiente de `country_iso`:
--   * `country_iso` → MONEDA e identificación fiscal (ya existía).
--   * `locale`      → IDIOMA de la interfaz (esta migración).
-- Un promotor estadounidense que financia una obra en España necesita
-- `locale='en'` con `country_iso='ES'`; con una sola columna eso no se puede
-- expresar.
--
-- Cambio ADITIVO:
--   1. `users.locale` con DEFAULT 'es' → las filas existentes no cambian de
--      idioma y ningún cliente antiguo se rompe.
--   2. `handle_new_auth_user` persiste `locale` y `country_iso` desde la
--      metadata del signUp (el wizard los recoge ANTES de que exista la fila,
--      así que tienen que viajar en la metadata).
--   3. `sf_set_my_locale` para cambiarlo desde ajustes.
--   4. `sf_get_my_profile_extended` lo devuelve.
--
-- NO aplicada automáticamente. Revisar y ejecutar con `supabase db push`.
-- ---------------------------------------------------------------------

-- ── 1. Columna ───────────────────────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS locale text NOT NULL DEFAULT 'es';

-- Se guarda solo el código ISO 639-1 ('es', 'en'), no el locale completo
-- ('es_ES'): permite añadir es-MX o en-GB sin migrar datos existentes.
-- El CHECK evita que un cliente con un bug escriba basura que luego rompa el
-- parseo en el arranque de la app.
ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_locale_supported;
ALTER TABLE public.users
  ADD CONSTRAINT users_locale_supported
  CHECK (locale IN ('es', 'es-419', 'en'));

COMMENT ON COLUMN public.users.locale IS
  'Idioma de interfaz preferido (ISO 639-1). Independiente de country_iso, '
  'que resuelve moneda e identificación fiscal. Ampliar el CHECK al añadir '
  'un idioma nuevo a AppLanguage en el cliente Flutter.';

CREATE INDEX IF NOT EXISTS users_locale_idx ON public.users (locale);
-- Índice para segmentar comunicaciones por idioma (emails transaccionales,
-- avisos). Sin él, cada envío masivo hace seq scan de toda la tabla.


-- ── 2. Alta de usuario: persistir idioma y país ──────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_meta             jsonb;
  v_user_id          uuid;
  v_org_id           uuid;
  v_role             text;
  v_invitation_token uuid;
  v_locale           text;
  v_country          char(2);
BEGIN
  v_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  v_role := v_meta->>'primary_role';

  -- Idioma elegido en el paso 1 del wizard. Se valida aquí y no se confía en
  -- el cliente: cualquier valor no soportado cae a español en vez de violar
  -- el CHECK y tumbar el alta entera.
  -- `lower()` normaliza 'ES-419' → 'es-419'. El guion se conserva: es una
  -- subetiqueta de región BCP 47, no un separador nuestro.
  v_locale := lower(COALESCE(v_meta->>'locale', 'es'));
  IF v_locale NOT IN ('es', 'es-419', 'en') THEN
    v_locale := 'es';
  END IF;

  -- País del selector. Mismo criterio defensivo: default 'ES' si no viene o
  -- no es un alpha-2.
  v_country := upper(COALESCE(NULLIF(v_meta->>'country_iso', ''), 'ES'))::char(2);

  BEGIN
    v_invitation_token := (v_meta->>'invitation_token')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_invitation_token := NULL;
  END;

  IF v_invitation_token IS NOT NULL THEN
    INSERT INTO public.users (
      auth_provider_id,
      full_name,
      email,
      phone_e164,
      primary_role,
      organization_id,
      kyc_status,
      locale,
      country_iso
    ) VALUES (
      NEW.id::text,
      COALESCE(v_meta->>'full_name', NEW.email),
      NEW.email,
      v_meta->>'phone_e164',
      NULL,
      NULL,
      'not_started',
      v_locale,
      v_country
    )
    RETURNING id INTO v_user_id;

    INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
    VALUES
      (v_user_id, 'terms_of_service',
       COALESCE(v_meta->>'terms_version', '1.0'),
       'sha256_placeholder_terms'),
      (v_user_id, 'privacy_policy',
       COALESCE(v_meta->>'privacy_version', '1.0'),
       'sha256_placeholder_privacy');

    INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
    VALUES (v_user_id, 'user_registered_via_invite', 'user', v_user_id,
      jsonb_build_object('invitation_token', v_invitation_token));

    RETURN NEW;
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RETURN NEW;
  END IF;

  IF v_role = 'constructor' AND COALESCE(v_meta->>'organization_name', '') <> '' THEN
    INSERT INTO public.organizations (legal_name, cif, province)
    VALUES (
      v_meta->>'organization_name',
      v_meta->>'cif_or_nif',
      v_meta->>'province'
    )
    RETURNING id INTO v_org_id;
  END IF;

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
    kyc_status,
    locale,
    country_iso
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
    'not_started',
    v_locale,
    v_country
  )
  RETURNING id INTO v_user_id;

  INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
  VALUES
    (v_user_id, 'terms_of_service',
     COALESCE(v_meta->>'terms_version', '1.0'),
     'sha256_placeholder_terms'),
    (v_user_id, 'privacy_policy',
     COALESCE(v_meta->>'privacy_version', '1.0'),
     'sha256_placeholder_privacy');

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_user_id, 'user_registered', 'user', v_user_id);

  RETURN NEW;
END;
$$;


-- ── 3. Cambio de idioma desde ajustes ────────────────────────────────

DROP FUNCTION IF EXISTS public.sf_set_my_locale(text);

CREATE OR REPLACE FUNCTION public.sf_set_my_locale(p_locale text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locale text;
BEGIN
  v_locale := lower(COALESCE(p_locale, ''));

  -- Se rechaza explícitamente en vez de caer a español en silencio: aquí el
  -- llamante es la app con una acción deliberada del usuario, así que un
  -- valor inválido es un bug del cliente y debe verse.
  IF v_locale NOT IN ('es', 'es-419', 'en') THEN
    RAISE EXCEPTION 'Unsupported locale: %', p_locale
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.users
     SET locale = v_locale
   WHERE auth_provider_id = (auth.uid())::text
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No profile for current user'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN v_locale;
END;
$$;

REVOKE ALL ON FUNCTION public.sf_set_my_locale(text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.sf_set_my_locale(text) TO authenticated;


-- ── 4. Exponer el idioma en el perfil ────────────────────────────────

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
  locale text,
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
    u.locale,
    u.created_at
  FROM public.users u
  LEFT JOIN public.organizations o ON o.id = u.organization_id
  WHERE u.auth_provider_id = (auth.uid())::text
    AND u.deleted_at IS NULL;
$$;

REVOKE ALL ON FUNCTION public.sf_get_my_profile_extended() FROM anon;
GRANT EXECUTE ON FUNCTION public.sf_get_my_profile_extended TO authenticated;

NOTIFY pgrst, 'reload schema';
