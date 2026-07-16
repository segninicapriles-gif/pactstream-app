-- =====================================================================
-- Fase 0 · Auditoría 16-jul-2026 · Cierre de dos policies permisivas
-- =====================================================================
--
-- Corrige dos policies detectadas en la auditoría integral 16-jul:
--
-- 1) `ai_assistant_messages.aam_select_own_or_admin` — el `OR (parte del
--    mismo pacto)` deja que cualquier parte del pacto lea los hilos IA
--    de las demás. Los mensajes del asistente son PROPIOS del usuario;
--    ni promotor lee lo que preguntó el constructor ni al revés.
--
-- 2) `app_settings.app_settings_select_all` — `USING (true)` deja que
--    cualquier usuario autenticado lea la kv de configuración interna
--    (feature flags, secretos operativos). La tabla NO se usa desde el
--    cliente Flutter (grep = 0 hits en `lib/`); service_role sigue
--    leyendo y escribiendo desde Edge Functions. Se cierra el acceso
--    para `authenticated`.
--
-- Aditivo y reversible. No toca datos.
-- Verificación tras aplicar (ambas queries deben devolver 0):
--   SELECT count(*) FROM pg_policies WHERE tablename='app_settings' AND 'authenticated'=ANY(roles);
--   SELECT count(*) FROM pg_policies WHERE tablename='ai_assistant_messages' AND qual ILIKE '%pact_parties%';

-- ─── 1) ai_assistant_messages ────────────────────────────────────────
-- Reemplaza la policy que permitía "propio OR miembro del pacto"
-- por "solo propio o admin".

DROP POLICY IF EXISTS aam_select_own_or_admin ON public.ai_assistant_messages;

CREATE POLICY aam_select_own ON public.ai_assistant_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.id = ai_assistant_messages.user_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    )
  );

COMMENT ON POLICY aam_select_own ON public.ai_assistant_messages IS
  'Auditoría 16-jul: los hilos del asistente IA son estrictamente del usuario que los generó. Antes cualquier parte del pacto los leía.';

-- ─── 2) app_settings ─────────────────────────────────────────────────
-- La tabla no la lee el cliente Flutter. La cerramos para authenticated;
-- service_role (Edge Functions) sigue funcionando porque BYPASSA RLS.

DROP POLICY IF EXISTS app_settings_select_all ON public.app_settings;

-- Sin policy para authenticated + RLS activa = default-deny para authenticated.
-- No creamos policy nueva para authenticated a propósito.

COMMENT ON TABLE public.app_settings IS
  'Configuración operativa interna (kv). Solo service_role lee/escribe. Auditoría 16-jul: se retiró la policy app_settings_select_all USING(true).';
