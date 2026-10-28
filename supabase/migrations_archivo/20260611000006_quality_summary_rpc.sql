-- Reconstruida el 2026-07-13 desde supabase_migrations.schema_migrations del remoto
-- (pactstream-dev / erqglsrnknhwqhfupckf). Esta migracion YA estaba aplicada en el
-- remoto pero no versionada en el repo local; se recupera para alinear el historial.
-- Fuente: statements[] almacenados por el CLI de Supabase.

-- Quality summary RPC for dashboard (mejora 4.4)
-- Returns aggregated quality metrics for the authenticated user's pacts.

CREATE OR REPLACE FUNCTION sf_get_quality_summary()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result  jsonb;
BEGIN
  SELECT jsonb_build_object(
    'avg_quality_score',    COALESCE(AVG(qh.quality_score), 0),
    'total_holdback_cents', COALESCE(SUM(qh.holdback_cents), 0)::int,
    'holdback_count',       COUNT(qh.id)::int,
    'pacts_with_ipc',       (
      SELECT COUNT(*)::int FROM pacts p2
      WHERE p2.ipc_enabled = true
        AND EXISTS (
          SELECT 1 FROM pact_members pm2
          WHERE pm2.pact_id = p2.id AND pm2.user_id = v_user_id
        )
    ),
    'total_acopio_cents',   COALESCE((
      SELECT SUM(m2.amount_cents)::int FROM milestones m2
      WHERE m2.category = 'acopio'
        AND m2.state NOT IN ('paid', 'cancelled')
        AND EXISTS (
          SELECT 1 FROM pact_members pm3
          WHERE pm3.pact_id = m2.pact_id AND pm3.user_id = v_user_id
        )
    ), 0)
  ) INTO v_result
  FROM quality_holdbacks qh
  JOIN milestones m ON m.id = qh.milestone_id
  JOIN pact_members pm ON pm.pact_id = m.pact_id AND pm.user_id = v_user_id;

  RETURN v_result;
END;
$$;
