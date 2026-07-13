-- REVISAR Y EJECUTAR MANUALMENTE. NO APLICADO. Verificar impacto en usuarios existentes.
-- =====================================================================
-- AUDITORÍA 2026-07-13 · PactStream C2 (CRÍTICO — explotable con anon key)
-- Vistas que saltan RLS (security definer implícito del owner).
-- =====================================================================
-- RE-DERIVADO 2026-07-13 sobre la definición ACTUAL del remoto. La lista de
-- columnas de v_user_active_pacts se reproduce EXACTAMENTE como está hoy en
-- el remoto (junio amplió la tabla pacts: funding_mode, mangopay_wallet_id,
-- iban_custodia, master_contract_doc_id, iva_*, etc.). Solo se añade el
-- filtro por usuario y security_invoker; no se quita ni reordena columna
-- alguna (CREATE OR REPLACE VIEW exige mismo prefijo de columnas).
--
-- Problema original:
--   v_user_active_pacts y v_pact_financial_progress se crearon SIN
--   security_invoker → corren con privilegios del OWNER y NO aplican las
--   RLS de pacts / pact_parties / milestones. Además `anon` tiene SELECT
--   sobre ellas. Resultado: cualquiera con la anon key y sin login podía
--   listar TODOS los pactos y su progreso financiero de TODA la plataforma.
--
-- Remediación:
--   (1) security_invoker = on en ambas vistas.
--   (2) v_user_active_pacts se recrea (sobre su definición ACTUAL) añadiendo
--       el filtro explícito por usuario actual, de forma que my_role/
--       my_user_id correspondan SIEMPRE al usuario del llamante.
--   (3) REVOKE SELECT ... FROM anon en ambas vistas.
--
-- IMPACTO:
--   - Autenticados: sin cambios funcionales; siguen viendo solo sus pactos.
--   - Consumo anónimo de estas vistas deja de devolver datos.
-- =====================================================================

-- ── (1)+(2) v_user_active_pacts: security_invoker + filtro por usuario ──
-- Lista de columnas = definición ACTUAL del remoto (pg_get_viewdef).
CREATE OR REPLACE VIEW public.v_user_active_pacts
WITH (security_invoker = on) AS
SELECT DISTINCT
  p.id,
  p.display_id,
  p.title,
  p.description,
  p.obra_address_line,
  p.obra_postal_code,
  p.obra_city,
  p.obra_province,
  p.obra_country_iso,
  p.obra_cadastral_ref,
  p.obra_type,
  p.total_amount_cents,
  p.iva_rate_pct,
  p.iva_included,
  p.total_with_iva_cents,
  p.platform_fee_pct,
  p.estimated_start_date,
  p.estimated_end_date,
  p.state,
  p.state_updated_at,
  p.funding_mode,
  p.mangopay_wallet_id,
  p.iban_custodia,
  p.master_contract_doc_id,
  p.created_by_user_id,
  p.created_at,
  p.updated_at,
  p.closed_at,
  pp.role    AS my_role,
  pp.user_id AS my_user_id
FROM public.pacts p
JOIN public.pact_parties pp ON pp.pact_id = p.id
WHERE p.state <> ALL (ARRAY['closed'::pact_state, 'cancelled'::pact_state])
  AND pp.user_id = (
    SELECT id FROM public.users
    WHERE auth_provider_id = (auth.uid())::text
      AND deleted_at IS NULL
  );

COMMENT ON VIEW public.v_user_active_pacts IS
  'Auditoría 2026-07-13 C2: security_invoker=on + filtro por usuario actual. Solo devuelve pactos activos donde el llamante es parte.';

-- ── (1) v_pact_financial_progress: security_invoker ─────────────────
-- No lleva columna de usuario; el aislamiento lo garantiza la RLS de
-- pacts/milestones al ejecutarse como el llamante (security_invoker).
ALTER VIEW public.v_pact_financial_progress SET (security_invoker = on);

COMMENT ON VIEW public.v_pact_financial_progress IS
  'Auditoría 2026-07-13 C2: security_invoker=on. El progreso financiero se filtra por la RLS de pacts/milestones del llamante.';

-- ── (3) Cortar el acceso anónimo ────────────────────────────────────
REVOKE SELECT ON public.v_user_active_pacts        FROM anon;
REVOKE SELECT ON public.v_pact_financial_progress  FROM anon;

NOTIFY pgrst, 'reload schema';
