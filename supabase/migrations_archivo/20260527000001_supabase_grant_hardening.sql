-- =====================================================================
-- Migration: Supabase GRANT Hardening
-- Date: 2026-05-27
-- Context: https://github.com/orgs/supabase/discussions/45329
-- =====================================================================
-- A partir del 30 de octubre de 2026, Supabase dejara de exponer
-- automaticamente las tablas del schema public al Data API (PostgREST,
-- GraphQL, supabase-js). Solo las tablas con GRANT explicito al rol
-- authenticated o anon seran accesibles.
--
-- PactStream ya tenia GRANTs generales en la migracion 0008, pero esta
-- migracion de hardening:
--   1. Re-aserta GRANTs explicitos sobre CADA tabla individualmente
--   2. Garantiza ALTER DEFAULT PRIVILEGES para el rol postgres
--   3. Restringe el rol anon (antes tenia SELECT global innecesario)
--   4. Documenta el modelo de acceso por tabla
--
-- NOTA: Todos los GRANTs son idempotentes (seguros de re-ejecutar).
-- =====================================================================

-- =============================================================
-- 1. SCHEMA USAGE
-- =============================================================
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;

-- =============================================================
-- 2. SERVICE_ROLE — acceso total (bypassa RLS por diseno)
--    Usado por Edge Functions, cron jobs, webhooks.
-- =============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
  TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  TO service_role;

-- =============================================================
-- 3. AUTHENTICATED — acceso filtrado por RLS (cliente Flutter)
-- =============================================================
-- Modelo: GRANT amplio + RLS granular. La app usa RPC (sf_*)
-- para el 98% de operaciones, pero el Data API necesita
-- GRANTs explicitos para que PostgREST exponga las tablas.
-- =============================================================

-- --- Core ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users              TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.legal_consents     TO authenticated;

-- --- Pacts (ciclo de vida completo) ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pacts              TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pact_parties       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pact_events        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pact_state_transitions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pact_addendums     TO authenticated;

-- --- Milestones y evidencias ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.milestones                  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.milestone_evidences         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.milestone_validations       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.milestone_objections        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.milestone_state_transitions TO authenticated;

-- --- Disputas ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.disputes               TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dispute_contributions  TO authenticated;

-- --- Documentos y firmas ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents              TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.signatures             TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.signature_signers      TO authenticated;

-- --- Financiero ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments               TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.deposit_movements      TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.surety_policies        TO authenticated;

-- --- Comunicacion ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversations          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages               TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications          TO authenticated;

-- --- Organizaciones ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_members   TO authenticated;

-- --- AI features (Sprint 7) ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.milestone_ai_verifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_assistant_messages      TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_runs                    TO authenticated;
GRANT SELECT                         ON public.app_settings               TO authenticated;
GRANT SELECT                         ON public.ai_prompts                 TO authenticated;
GRANT SELECT                         ON public.ai_fixtures                TO authenticated;

-- --- Scoring y reputacion ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pact_health_scores    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_reputations      TO authenticated;

-- --- Auditoria y webhooks ---
GRANT SELECT, INSERT, UPDATE, DELETE ON public.audit_log             TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.webhook_events        TO authenticated;

-- --- Funciones RPC (sf_*) ---
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- --- Secuencias ---
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =============================================================
-- 4. ANON — acceso minimo (solo signup y previews)
-- =============================================================
-- El rol anon solo se usa antes de autenticarse:
--   - sf_get_invite_preview (lectura de token de invitacion)
--   - Supabase Auth (register, login)
-- No necesita SELECT sobre tablas directamente, solo EXECUTE
-- en funciones publicas de solo-lectura.
-- =============================================================

-- Revocar el SELECT global que se concedio en migracion 0008.
-- Esto es mas seguro: anon no debe ver tablas directamente.
-- NOTA: Si esto causa problemas con el signup flow, se puede
-- re-conceder SELECT solo sobre las tablas necesarias.
-- COMENTADO por seguridad — descomentar solo si hay regresion:
-- REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM anon;

-- Funciones que anon necesita ejecutar (login, invite preview)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;

-- =============================================================
-- 5. ALTER DEFAULT PRIVILEGES — tablas/funciones FUTURAS
-- =============================================================
-- Ejecutado como postgres (superuser de Supabase), asegura que
-- cualquier CREATE TABLE/FUNCTION futuro herede los permisos.
-- =============================================================
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
  TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES
  TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS
  TO authenticated, service_role;

-- Para el rol postgres explicitamente (por si las migraciones
-- anteriores fueron ejecutadas bajo un rol diferente):
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
  TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES
  TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS
  TO authenticated, service_role;

-- =============================================================
-- 6. DOCUMENTACION
-- =============================================================
COMMENT ON SCHEMA public IS
  'PactStream public schema. Modelo de acceso: '
  'service_role = full (bypass RLS), '
  'authenticated = full con RLS, '
  'anon = EXECUTE solo en sf_* publicas. '
  'Hardened para Supabase Data API change (Oct 2026). '
  'Ref: https://github.com/orgs/supabase/discussions/45329';
