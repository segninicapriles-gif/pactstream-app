-- REVISAR Y EJECUTAR MANUALMENTE. NO APLICADO. Verificar impacto en usuarios existentes.
-- =====================================================================
-- AUDITORÍA 2026-07-13 · PactStream C1 (CRÍTICO)
-- Escalada de privilegios vía UPDATE columnar sobre public.users.
-- =====================================================================
-- Problema:
--   La policy users_self_update (20260430000007_fix_users_rls.sql:19-21)
--   es FOR UPDATE USING(auth_provider_id = auth.uid()) SIN WITH CHECK, y
--   el rol `authenticated` tiene UPDATE sobre TODAS las columnas de la
--   tabla. Un usuario autenticado puede, con la anon/authenticated key,
--   auto-asignarse kyc_status='verified', primary_role='admin', secuestrar
--   organization_id, sobrescribir mangopay_user_id, national_id, email o
--   auth_provider_id de su propia fila.
--
-- Remediación (defensa en profundidad, 3 capas):
--   (a) Privilegio de columna: REVOKE UPDATE total + GRANT UPDATE solo
--       sobre columnas NO privilegiadas (las mismas que edita el RPC
--       oficial sf_update_my_profile: full_name, phone_e164, avatar_url;
--       + marketing_consent_at para el opt-in de marketing).
--   (b) Trigger BEFORE UPDATE que rechaza cambios en columnas sensibles
--       cuando el rol EFECTIVO del llamante es un cliente directo
--       (authenticated/anon). Las RPC del backend son SECURITY DEFINER y
--       corren como owner (current_user = postgres), por lo que NO se ven
--       afectadas; service_role tampoco.
--   (c) WITH CHECK explícito en la policy para impedir reasignar la fila
--       a otro auth_provider_id.
--
-- IMPACTO EN USUARIOS EXISTENTES:
--   - La app edita el perfil vía RPC sf_update_my_profile (SECURITY
--     DEFINER) → NO se rompe.
--   - Si algún cliente escribía directamente OTRAS columnas de users vía
--     PostgREST (patrón desaconsejado), esas escrituras dejarán de
--     funcionar. Migrar ese flujo a una RPC SECURITY DEFINER.
-- =====================================================================

-- ── (a) Privilegio de columna ───────────────────────────────────────
REVOKE UPDATE ON public.users FROM authenticated;
REVOKE UPDATE ON public.users FROM anon;

-- Columnas verificadas contra el CREATE TABLE users
-- (20260429000000_initial_schema.sql:153) y la columna avatar_url
-- añadida en 20260531000003_profile_edit.sql. Son las únicas que el
-- usuario puede editar legítimamente por sí mismo.
GRANT UPDATE (full_name, phone_e164, avatar_url, marketing_consent_at)
  ON public.users TO authenticated;

-- ── (b) Trigger anti-escalada sobre columnas sensibles ──────────────
CREATE OR REPLACE FUNCTION public.enforce_users_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Solo aplica a clientes directos (PostgREST con SET ROLE authenticated/anon).
  -- Las RPC SECURITY DEFINER corren como owner (current_user = postgres) y
  -- el service_role (current_user = service_role) quedan exentos: pueden
  -- modificar KYC, rol, organización, etc. de forma legítima.
  IF current_user IN ('authenticated', 'anon') THEN
    IF NEW.kyc_status      IS DISTINCT FROM OLD.kyc_status
       OR NEW.kyc_verified_at IS DISTINCT FROM OLD.kyc_verified_at
       OR NEW.primary_role    IS DISTINCT FROM OLD.primary_role
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.mangopay_user_id IS DISTINCT FROM OLD.mangopay_user_id
       OR NEW.national_id     IS DISTINCT FROM OLD.national_id
       OR NEW.auth_provider_id IS DISTINCT FROM OLD.auth_provider_id
       OR NEW.email           IS DISTINCT FROM OLD.email
    THEN
      RAISE EXCEPTION
        'No autorizado: no puedes modificar columnas privilegiadas de tu perfil (kyc_status, kyc_verified_at, primary_role, organization_id, mangopay_user_id, national_id, auth_provider_id, email). Usa el flujo de servidor correspondiente.'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_enforce_privileged_columns ON public.users;
CREATE TRIGGER trg_users_enforce_privileged_columns
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_users_privileged_columns();

COMMENT ON FUNCTION public.enforce_users_privileged_columns() IS
  'Auditoría 2026-07-13 C1: bloquea que un cliente directo (authenticated/anon) modifique columnas privilegiadas de public.users. RPC SECURITY DEFINER y service_role exentos.';

-- ── (c) WITH CHECK explícito en la policy ───────────────────────────
DROP POLICY IF EXISTS users_self_update ON public.users;
CREATE POLICY users_self_update ON public.users FOR UPDATE
  USING      (auth_provider_id = (auth.uid())::text)
  WITH CHECK (auth_provider_id = (auth.uid())::text);

COMMENT ON POLICY users_self_update ON public.users IS
  'Auditoría 2026-07-13 C1: el usuario solo actualiza su propia fila (USING) y no puede reasignarla a otro auth_provider_id (WITH CHECK). El alcance por columna lo imponen los GRANT y el trigger enforce_users_privileged_columns.';

NOTIFY pgrst, 'reload schema';
