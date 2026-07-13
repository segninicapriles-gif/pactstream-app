-- REVISAR Y EJECUTAR MANUALMENTE. NO APLICADO. Verificar impacto en usuarios existentes.
-- =====================================================================
-- AUDITORÍA 2026-07-13 · PactStream A1
-- Eliminar RPC de desarrollo peligrosas.
-- =====================================================================
-- Problema:
--   sf_mock_fund_pact (20260520000003_quick_win_mock_fund_and_submit.sql)
--   y sf_simulate_kyc_verification (20260430000003_kyc_rpc_fix.sql) son
--   RPC de DEV que permiten, respectivamente:
--     - marcar un pacto como financiado (in_execution) SIN pago real, y
--     - auto-verificar el KYC ('verified') sin proveedor.
--   Hoy solo están REVOCADAS de authenticated/anon
--   (20260531000005_security_hardening.sql), lo cual es frágil: cualquier
--   GRANT amplio futuro (p.ej. GRANT EXECUTE ON ALL FUNCTIONS ... a
--   authenticated/anon) las vuelve a exponer. La medida robusta es
--   ELIMINARLAS del esquema de producción.
--
-- ANTES DE EJECUTAR — verificar que NINGÚN flujo de producción depende de
-- ellas. Se han encontrado llamadas potenciales solo en flujos DEV/QA.
-- Si el cliente Flutter (build dev) aún las invoca, se debe gatear esa
-- ruta detrás de un flag de entorno ANTES de aplicar este DROP.
--
-- IMPACTO EN USUARIOS EXISTENTES:
--   - Producción: ninguno (ya estaban revocadas para clientes).
--   - Entornos DEV que dependan del "mock funding" / "mock KYC" perderán
--     esos atajos; usar el flujo real (Mangopay / proveedor KYC) o
--     recrear las funciones localmente solo en dev.
-- =====================================================================

-- Firmas exactas (verificadas en las migraciones fuente):
--   sf_mock_fund_pact(p_pact_id uuid)
--   sf_simulate_kyc_verification(p_decision text, p_reason text)
DROP FUNCTION IF EXISTS public.sf_mock_fund_pact(uuid);
DROP FUNCTION IF EXISTS public.sf_simulate_kyc_verification(text, text);

NOTIFY pgrst, 'reload schema';
