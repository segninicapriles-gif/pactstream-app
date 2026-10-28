-- ============================================================================
-- P6 (hallazgo M3) — Vista SECURITY DEFINER residual de pactstream-dev
-- ----------------------------------------------------------------------------
-- Proyecto:  pactstream-dev (erqglsrnknhwqhfupckf)
-- Destino:   pactstream-app/supabase/migrations/20260901120000_p6_v_my_pacts_summary_security_invoker.sql
--            (formato timestamp del repo; posterior a la última: 20260814201100)
-- Estado:    PROPUESTA — NO APLICADA.
--
-- CONTEXTO: es la ÚNICA vista SECURITY DEFINER que queda en pactstream-dev (el
-- advisor solo marca esta; la vieja 20260713000002 cubría v_user_active_pacts y
-- v_pact_financial_progress, que hoy ya no aparecen como definer).
--
-- v_my_pacts_summary YA filtra por usuario en su WHERE
--   (pp.user_id = (select id from users where auth_provider_id = auth.uid()::text)),
-- así que hoy no fuga. Pero al ser definer SALTA la RLS de pacts/pact_parties: si
-- alguien edita la vista y quita el WHERE, nada la protege. Este es un caso LIMPIO
-- para security_invoker (a diferencia de los agregados de ConstructPro): la RLS
-- subyacente `user_in_pact()` funciona para `authenticated` y devuelve los pactos
-- del llamante — defensa en profundidad sin cambiar el resultado.
--
-- ARREGLO: security_invoker = on + retirar el SELECT a anon. Idempotente.
-- IMPACTO: autenticados sin cambios; consumo anónimo deja de devolver datos.
-- ============================================================================

alter view public.v_my_pacts_summary set (security_invoker = on);

revoke select on public.v_my_pacts_summary from anon;

comment on view public.v_my_pacts_summary is
  'Auditoria 2026-09-01 (P6): security_invoker=on + sin acceso anon. Aislamiento por la RLS de pacts/pact_parties (user_in_pact) ademas del filtro propio por auth.uid().';

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- REVERSIÓN:
--   alter view public.v_my_pacts_summary set (security_invoker = off);
--   grant select on public.v_my_pacts_summary to anon;
-- ----------------------------------------------------------------------------
