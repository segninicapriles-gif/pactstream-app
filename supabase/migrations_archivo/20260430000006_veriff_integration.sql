-- =====================================================================
-- Sprint 1.5 · Migration 0008
-- Integración Veriff real (reemplaza mock KYC).
-- =====================================================================
-- Cambios:
--   - Añade estado 'in_progress' al enum kyc_status (mientras la sesión
--     Veriff está abierta y el usuario está completando documento+selfie).
--   - Añade campo kyc_session_url a users para guardar la URL temporal.
--   - Crea índice en webhook_events para queries por external_id.
--
-- Nota: 'in_progress' ya existe en el enum kyc_status del schema base.
-- Esta migration solo añade el campo de URL.
-- =====================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS kyc_session_url text;

COMMENT ON COLUMN public.users.kyc_session_url IS
  'URL temporal de la sesión Veriff. Vacía cuando no hay sesión activa.';

-- Índice para búsquedas rápidas de webhook events por external_id
CREATE INDEX IF NOT EXISTS idx_webhook_events_external_id
  ON public.webhook_events(external_id);
