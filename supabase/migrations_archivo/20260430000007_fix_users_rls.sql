-- =====================================================================
-- Sprint 1.5 · Migration 0009 (HOTFIX)
-- Corrige la política RLS de public.users.
-- =====================================================================
-- Bug: el schema base comparaba users.id con auth.uid(), pero esos son
-- UUIDs DISTINTOS (users.id es PK de public.users, auth.uid() es PK de
-- auth.users). El campo correcto para comparar es users.auth_provider_id.
--
-- Síntoma: Edge Functions que usan el cliente con JWT no pueden leer el
-- perfil del usuario, devolviendo 0 filas (RLS las filtra silenciosamente).
-- =====================================================================

-- SELECT: el usuario solo ve su propia fila
DROP POLICY IF EXISTS users_self_select ON public.users;
CREATE POLICY users_self_select ON public.users FOR SELECT
  USING (auth_provider_id = (auth.uid())::text);

-- UPDATE: el usuario solo puede actualizar su propia fila
DROP POLICY IF EXISTS users_self_update ON public.users;
CREATE POLICY users_self_update ON public.users FOR UPDATE
  USING (auth_provider_id = (auth.uid())::text);

COMMENT ON POLICY users_self_select ON public.users IS
  'Cada usuario solo puede leer su propia fila. Compara auth_provider_id (texto del JWT sub) con auth.uid().';
