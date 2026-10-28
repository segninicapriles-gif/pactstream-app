-- Restringir ai_prompts: solo service_role debe leer/escribir.
-- El asistente IA accede vía edge function (service_role), no desde el cliente.
-- Auditoría: hallazgo bajo — los prompts son IP.

REVOKE ALL ON public.ai_prompts FROM authenticated;

-- Reemplazar la política RLS permisiva por una restrictiva
DROP POLICY IF EXISTS ai_prompts_select_active ON public.ai_prompts;
CREATE POLICY ai_prompts_service_only ON public.ai_prompts
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
