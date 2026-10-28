-- REVISAR Y EJECUTAR MANUALMENTE. NO APLICADO. Verificar impacto en usuarios existentes.
-- =====================================================================
-- AUDITORÍA 2026-07-13 · PactStream M3 / M7
-- Fijar search_path en funciones sensibles + recomendación de grants.
-- =====================================================================
-- M3: funciones SECURITY DEFINER usadas en RLS/autorización SIN
--     "SET search_path" son vulnerables a search_path hijacking (un rol
--     que cree objetos en un esquema con prioridad podría interceptar
--     referencias no cualificadas). Se fija search_path = public.
--
-- Firmas verificadas:
--   user_in_pact(p_pact_id uuid, p_user_id uuid)   (initial_schema:931, SECURITY DEFINER)
--   check_kyc_verified(p_user_id uuid)             (security_hardening:100, SECURITY DEFINER)
--   current_user_id()                              (initial_schema:926, usada en RLS)
-- =====================================================================

ALTER FUNCTION public.user_in_pact(uuid, uuid)   SET search_path = public;
ALTER FUNCTION public.check_kyc_verified(uuid)   SET search_path = public;
-- current_user_id() se usa en múltiples políticas RLS; fijarlo también:
ALTER FUNCTION public.current_user_id()          SET search_path = public;


-- =====================================================================
-- M7 · RECOMENDACIÓN (COMENTADA — revisar impacto con datos reales)
-- =====================================================================
-- El proyecto concede EXECUTE de forma masiva sobre TODAS las funciones
-- del esquema public a authenticated y anon, y fija ese comportamiento
-- para funciones FUTURAS vía ALTER DEFAULT PRIVILEGES
-- (20260430000008_fix_grants.sql y 20260527000001_supabase_grant_hardening.sql:
--   línea 103: GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
--   línea 126: GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;
--   líneas 134-157: ALTER DEFAULT PRIVILEGES ... GRANT EXECUTE ON FUNCTIONS ...).
--
-- Riesgo: cualquier función nueva (incluidas RPC internas, helpers de
-- dinero o mocks recreados) queda EJECUTABLE por defecto para clientes
-- sin login (anon) o cualquier autenticado. Esto es lo que reexpone
-- automáticamente las mocks (ver 20260713000003) y contradice el
-- principio de mínimo privilegio.
--
-- REMEDIACIÓN RECOMENDADA (aplicar tras auditar qué RPC debe ser pública
-- para cada rol; NO ejecutar a ciegas, rompería el cliente si se revoca
-- una RPC que la app usa):
--
--   -- 1) Revocar el permiso masivo actual:
--   -- REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
--   -- REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;
--
--   -- 2) Eliminar los defaults amplios (por cada rol que los definió,
--   --    p.ej. postgres):
--   -- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
--   -- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM authenticated;
--   -- ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
--   -- ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM authenticated;
--
--   -- 3) Conceder EXECUTE EXPLÍCITO solo a las RPC que la app invoca,
--   --    p.ej.:
--   -- GRANT EXECUTE ON FUNCTION public.sf_get_my_profile_extended()      TO authenticated;
--   -- GRANT EXECUTE ON FUNCTION public.sf_update_my_profile(text,text,text) TO authenticated;
--   -- ... (enumerar la superficie pública real, rol por rol).
--
-- Hasta hacerlo, cada migración que cree una RPC nueva debe REVOCARLA
-- explícitamente de anon (y de authenticated si no es pública).

NOTIFY pgrst, 'reload schema';
