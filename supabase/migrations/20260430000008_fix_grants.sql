-- =====================================================================
-- Sprint 1.5 · Migration 0010 (HOTFIX)
-- Concede privilegios correctos a service_role y authenticated.
-- =====================================================================
-- Bug: el schema base activó RLS pero no concedió GRANT explícito a los
-- roles, lo que provocaba "permission denied for table users" desde
-- Edge Functions usando service_role.
--
-- service_role: bypass RLS + acceso total (escrituras críticas).
-- authenticated: acceso filtrado por RLS (cliente Flutter).
-- anon: acceso muy limitado (solo signup/auth).
-- =====================================================================

-- USAGE en el schema
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;

-- TABLAS — service_role puede leer/escribir todo (bypassa RLS por diseño)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO service_role;

-- TABLAS — authenticated puede operar pero RLS lo filtra
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO authenticated;

-- SECUENCIAS (necesarias para tablas con SERIAL/BIGSERIAL aunque casi todo
-- usa UUID gen_random_uuid)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
  TO authenticated, service_role;

-- FUNCIONES
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  TO authenticated, service_role;

-- DEFAULT PRIVILEGES — para que las nuevas tablas/funciones que se creen
-- en el futuro hereden estos permisos automáticamente.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO authenticated, service_role;

-- VIEWS — el ALL TABLES de arriba ya cubre las views, pero por si acaso
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

COMMENT ON SCHEMA public IS
  'Schema público de PactStream. Permisos: service_role bypassa RLS, authenticated filtrado por RLS.';
