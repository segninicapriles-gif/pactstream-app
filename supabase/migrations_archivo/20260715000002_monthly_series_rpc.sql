-- =====================================================================
-- Migración · Dashboards con datos reales (pendiente desde auditoría v2)
-- sf_get_monthly_series: series mensuales para los charts de la home.
-- =====================================================================
-- Devuelve, para el usuario autenticado, las series de los últimos 6
-- meses (mes actual incluido) que alimentan los charts de la home:
--   billing     · céntimos cobrados/mes  (hitos con paid_at, rol constructor)
--   fund_flow   · céntimos pagados/mes   (hitos con paid_at, rol promotor)
--   validations · nº de validaciones/mes (milestone_validations propias)
--
-- Shape: {"billing":[{"month":"2026-02","value":0},...x6],
--         "fund_flow":[...], "validations":[...]}
-- Meses en orden ascendente, formato YYYY-MM; los meses sin actividad
-- van a 0 (la UI muestra empty state si TODO es 0).
--
-- Aditiva: función nueva, sin cambios de datos ni de otras funciones.

CREATE OR REPLACE FUNCTION public.sf_get_monthly_series()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_billing jsonb; v_flow jsonb; v_validations jsonb;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  WITH months AS (
    SELECT date_trunc('month', now()) - (interval '1 month' * g) AS m
    FROM generate_series(5, 0, -1) AS g
  ),
  cobrado AS (
    SELECT date_trunc('month', ms.paid_at) AS m, sum(ms.amount_cents) AS v
    FROM public.milestones ms
    JOIN public.pact_parties pp ON pp.pact_id = ms.pact_id
      AND pp.user_id = v_user_id AND pp.role = 'constructor'
    WHERE ms.paid_at IS NOT NULL
      AND ms.paid_at >= date_trunc('month', now()) - interval '5 months'
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'month', to_char(months.m, 'YYYY-MM'),
    'value', coalesce(cobrado.v, 0)
  ) ORDER BY months.m)
  INTO v_billing
  FROM months LEFT JOIN cobrado ON cobrado.m = months.m;

  WITH months AS (
    SELECT date_trunc('month', now()) - (interval '1 month' * g) AS m
    FROM generate_series(5, 0, -1) AS g
  ),
  pagado AS (
    SELECT date_trunc('month', ms.paid_at) AS m, sum(ms.amount_cents) AS v
    FROM public.milestones ms
    JOIN public.pact_parties pp ON pp.pact_id = ms.pact_id
      AND pp.user_id = v_user_id AND pp.role = 'promotor'
    WHERE ms.paid_at IS NOT NULL
      AND ms.paid_at >= date_trunc('month', now()) - interval '5 months'
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'month', to_char(months.m, 'YYYY-MM'),
    'value', coalesce(pagado.v, 0)
  ) ORDER BY months.m)
  INTO v_flow
  FROM months LEFT JOIN pagado ON pagado.m = months.m;

  WITH months AS (
    SELECT date_trunc('month', now()) - (interval '1 month' * g) AS m
    FROM generate_series(5, 0, -1) AS g
  ),
  vals AS (
    SELECT date_trunc('month', mv.decision_at) AS m, count(*) AS v
    FROM public.milestone_validations mv
    WHERE mv.validator_user_id = v_user_id
      AND mv.decision_at >= date_trunc('month', now()) - interval '5 months'
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'month', to_char(months.m, 'YYYY-MM'),
    'value', coalesce(vals.v, 0)
  ) ORDER BY months.m)
  INTO v_validations
  FROM months LEFT JOIN vals ON vals.m = months.m;

  RETURN jsonb_build_object(
    'billing', v_billing,
    'fund_flow', v_flow,
    'validations', v_validations
  );
END;
$$;

REVOKE ALL ON FUNCTION public.sf_get_monthly_series() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sf_get_monthly_series() TO authenticated;

COMMENT ON FUNCTION public.sf_get_monthly_series() IS
  'Series mensuales (6 meses) para los charts de la home: cobrado (constructor), pagado (promotor) y validaciones (técnico) del usuario autenticado.';

NOTIFY pgrst, 'reload schema';
