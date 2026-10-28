-- =====================================================================
-- Tope de coste IA MENSUAL (además del diario)
-- =====================================================================
-- Contexto (22-jul-2026): ai_provider pasa a 'live' en fase de pruebas.
-- Andrés fija un tope mensual de 20 € mientras se prueba; el diario (5 €)
-- sigue actuando como primer freno. Si cualquiera de los dos se supera,
-- el gateway degrada a demo (mismo patrón que sf_ai_today_cost_cents).
-- ⚠️ Antes de abrir al público: revisar ambos límites (decisión Andrés).

CREATE OR REPLACE FUNCTION public.sf_ai_month_cost_cents()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(sum(cost_cents), 0)
  FROM public.ai_runs
  WHERE created_at >= date_trunc('month', now())
    AND provider = 'live';
$$;

GRANT EXECUTE ON FUNCTION public.sf_ai_month_cost_cents() TO service_role;

-- Setting: tope mensual en euros. 0 o ausente = sin tope mensual.
INSERT INTO public.app_settings (key, value, description)
VALUES (
  'ai_max_cost_eur_month',
  '20'::jsonb,
  'Tope de gasto IA acumulado en el mes natural (EUR). Si SUM(cost_cents) del mes supera este valor, el gateway fuerza demo. 0 = sin tope mensual. Fijado a 20 en fase de pruebas (22-jul-2026); revisar antes del lanzamiento público.'
)
ON CONFLICT (key) DO UPDATE SET value = excluded.value, description = excluded.description;

NOTIFY pgrst, 'reload schema';
