-- Reconstruida el 2026-07-13 desde supabase_migrations.schema_migrations del remoto
-- (pactstream-dev / erqglsrnknhwqhfupckf). Esta migracion YA estaba aplicada en el
-- remoto pero no versionada en el repo local; se recupera para alinear el historial.
-- Fuente: statements[] almacenados por el CLI de Supabase.

-- Migration: Smart Contracts IPC (Mejora 5.4)
--
-- Permite que los importes de los hitos se ajusten automáticamente según
-- el IPC (Índice de Precios al Consumo) publicado por el INE.
-- El pacto puede activar la cláusula IPC en la creación, lo que añade
-- un campo de referencia al mes base y aplica ajustes progresivos.
--
-- Diseño:
--   - Tabla ipc_indices: valores mensuales del IPC (alimentada por cron/API)
--   - Columna ipc_enabled en pacts: activa/desactiva cláusula IPC
--   - Columna ipc_base_month en pacts: mes de referencia (YYYY-MM)
--   - Al crear cada certificación, si IPC está activo, el importe se ajusta
--     proporcionalmente según la variación IPC acumulada.

-- ---------------------------------------------------------------------------
-- 1. Tabla ipc_indices — serie histórica del IPC
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ipc_indices (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year_month  text NOT NULL UNIQUE,  -- 'YYYY-MM'
  index_value numeric(8,3) NOT NULL, -- valor del índice (ej: 114.235)
  variation_monthly_pct numeric(6,3), -- variación mensual %
  variation_annual_pct  numeric(6,3), -- variación interanual %
  source      text NOT NULL DEFAULT 'INE',
  published_at date,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ipc_year_month ON public.ipc_indices (year_month);

ALTER TABLE ipc_indices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ipc_read_all" ON public.ipc_indices FOR SELECT
  USING (true);

GRANT SELECT ON public.ipc_indices TO authenticated;

COMMENT ON TABLE public.ipc_indices IS
  'Serie del IPC del INE. Alimentada por Edge Function ipc-updater (cron mensual).';

-- ---------------------------------------------------------------------------
-- 2. Columnas IPC en pacts
-- ---------------------------------------------------------------------------
ALTER TABLE public.pacts
  ADD COLUMN IF NOT EXISTS ipc_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ipc_base_month text,
  ADD COLUMN IF NOT EXISTS ipc_base_value numeric(8,3);

COMMENT ON COLUMN public.pacts.ipc_enabled IS
  'true si el pacto tiene cláusula de revisión por IPC';

COMMENT ON COLUMN public.pacts.ipc_base_month IS
  'Mes de referencia para el cálculo IPC (YYYY-MM)';

COMMENT ON COLUMN public.pacts.ipc_base_value IS
  'Valor del índice IPC en el mes base';

-- ---------------------------------------------------------------------------
-- 3. Columnas IPC en milestones
-- ---------------------------------------------------------------------------
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS original_amount_cents bigint,
  ADD COLUMN IF NOT EXISTS ipc_adjustment_pct numeric(6,3) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ipc_applied_month text;

COMMENT ON COLUMN public.milestones.original_amount_cents IS
  'Importe original antes de ajuste IPC (null si no hay ajuste)';

COMMENT ON COLUMN public.milestones.ipc_adjustment_pct IS
  'Porcentaje de ajuste IPC aplicado sobre el original';

-- ---------------------------------------------------------------------------
-- 4. Función: sf_calc_ipc_adjustment
--    Calcula el ajuste IPC para un importe dado.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_calc_ipc_adjustment(
  p_base_month text,
  p_current_month text DEFAULT NULL,
  p_amount_cents bigint DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base_value numeric;
  v_current_value numeric;
  v_current_month text;
  v_variation_pct numeric;
  v_adjusted_cents bigint;
BEGIN
  v_current_month := coalesce(p_current_month, to_char(now(), 'YYYY-MM'));

  -- Obtener valor base
  SELECT index_value INTO v_base_value
  FROM public.ipc_indices WHERE year_month = p_base_month;

  IF v_base_value IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'IPC base not found for ' || p_base_month,
      'adjustment_pct', 0,
      'adjusted_cents', p_amount_cents
    );
  END IF;

  -- Obtener valor actual (buscar el más reciente si el mes actual no existe)
  SELECT index_value INTO v_current_value
  FROM public.ipc_indices
  WHERE year_month <= v_current_month
  ORDER BY year_month DESC
  LIMIT 1;

  IF v_current_value IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'No IPC data available',
      'adjustment_pct', 0,
      'adjusted_cents', p_amount_cents
    );
  END IF;

  -- Calcular variación
  v_variation_pct := round(((v_current_value - v_base_value) / v_base_value) * 100, 3);
  v_adjusted_cents := round(p_amount_cents * (1 + v_variation_pct / 100));

  RETURN jsonb_build_object(
    'base_month', p_base_month,
    'base_value', v_base_value,
    'current_month', v_current_month,
    'current_value', v_current_value,
    'variation_pct', v_variation_pct,
    'original_cents', p_amount_cents,
    'adjusted_cents', v_adjusted_cents
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_calc_ipc_adjustment TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. Función: sf_apply_ipc_to_milestone
--    Aplica el ajuste IPC a una certificación pendiente.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_apply_ipc_to_milestone(
  p_milestone_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_milestone record;
  v_pact record;
  v_adjustment jsonb;
  v_new_amount bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT m.*, p.ipc_enabled, p.ipc_base_month, p.ipc_base_value
  INTO v_milestone
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_milestone IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  IF NOT v_milestone.ipc_enabled THEN
    RAISE EXCEPTION 'El pacto no tiene cláusula IPC activa';
  END IF;

  IF v_milestone.state NOT IN ('pending', 'in_execution') THEN
    RAISE EXCEPTION 'Solo se puede ajustar IPC en hitos pendientes o en ejecución';
  END IF;

  -- Calcular ajuste
  v_adjustment := public.sf_calc_ipc_adjustment(
    v_milestone.ipc_base_month,
    to_char(now(), 'YYYY-MM'),
    coalesce(v_milestone.original_amount_cents, v_milestone.amount_cents)
  );

  IF v_adjustment->>'error' IS NOT NULL THEN
    RETURN v_adjustment;
  END IF;

  v_new_amount := (v_adjustment->>'adjusted_cents')::bigint;

  -- Aplicar
  UPDATE public.milestones
  SET original_amount_cents = coalesce(original_amount_cents, amount_cents),
      amount_cents = v_new_amount,
      ipc_adjustment_pct = (v_adjustment->>'variation_pct')::numeric,
      ipc_applied_month = to_char(now(), 'YYYY-MM')
  WHERE id = p_milestone_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_milestone.pact_id, 'ipc_adjustment_applied',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'original_cents', coalesce(v_milestone.original_amount_cents, v_milestone.amount_cents),
      'adjusted_cents', v_new_amount,
      'variation_pct', v_adjustment->>'variation_pct',
      'base_month', v_milestone.ipc_base_month
    ),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'milestone_id', p_milestone_id,
    'original_cents', coalesce(v_milestone.original_amount_cents, v_milestone.amount_cents),
    'adjusted_cents', v_new_amount,
    'variation_pct', (v_adjustment->>'variation_pct')::numeric
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_apply_ipc_to_milestone TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Seed: últimos 12 meses de IPC (datos INE reales hasta mayo 2026)
-- ---------------------------------------------------------------------------
INSERT INTO public.ipc_indices (year_month, index_value, variation_annual_pct, source) VALUES
  ('2025-06', 112.876, 3.4, 'INE'),
  ('2025-07', 112.540, 2.8, 'INE'),
  ('2025-08', 112.332, 2.4, 'INE'),
  ('2025-09', 112.754, 2.6, 'INE'),
  ('2025-10', 113.210, 2.9, 'INE'),
  ('2025-11', 113.456, 2.7, 'INE'),
  ('2025-12', 113.890, 2.5, 'INE'),
  ('2026-01', 113.120, 2.2, 'INE'),
  ('2026-02', 113.340, 2.3, 'INE'),
  ('2026-03', 113.780, 2.5, 'INE'),
  ('2026-04', 114.120, 2.8, 'INE'),
  ('2026-05', 114.450, 3.0, 'INE')
ON CONFLICT (year_month) DO NOTHING;
