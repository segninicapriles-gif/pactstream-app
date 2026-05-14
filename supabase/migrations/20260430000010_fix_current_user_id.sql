-- =====================================================================
-- Sprint 2 chunk 1 · Migration 0012 (HOTFIX)
-- Corrige public.current_user_id() para devolver public.users.id en
-- lugar del sub del JWT (que es auth.users.id).
-- =====================================================================
-- Bug: la función original devolvía el auth.uid() del JWT, pero todos
-- los triggers (pact_state_transitions, milestone_state_transitions, etc.)
-- usan ese valor como FK contra public.users.id — UUID DISTINTO. Esto
-- provocaba violaciones de FK al transicionar estados.
--
-- Fix: hacer lookup en public.users para devolver el id correcto.
--
-- Performance: la función se sigue marcando STABLE; Postgres puede
-- cachear el resultado dentro de la misma query/transacción.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.current_user_id() RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT u.id
  FROM public.users u
  WHERE u.auth_provider_id = (current_setting('request.jwt.claims', true)::json->>'sub')
    AND u.deleted_at IS NULL
  LIMIT 1
$$;

COMMENT ON FUNCTION public.current_user_id() IS
  'Devuelve public.users.id del usuario autenticado. Hace lookup por auth_provider_id desde el JWT sub. Usar en triggers y RLS que necesiten el PK de public.users.';
