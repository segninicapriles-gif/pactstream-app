-- =====================================================================
-- Sprint 5 chunk 6 · Cron de paralización automática
-- =====================================================================
-- Detecta certificaciones v2.1 cuyo pre-depósito ha vencido y las
-- paraliza pasándolas a 'paused_no_predeposit'. Notifica a las partes
-- (operativa + económica) sobre la paralización.
--
-- Programado con pg_cron cada hora. Idempotente.
-- =====================================================================


DROP FUNCTION IF EXISTS public.sf_check_predeposit_deadlines;
CREATE OR REPLACE FUNCTION public.sf_check_predeposit_deadlines()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_milestone   record;
  v_paused_ids  uuid[] := ARRAY[]::uuid[];
  v_recipients  uuid[];
  v_actor_user  uuid;
BEGIN
  FOR v_milestone IN
    SELECT m.id, m.name, m.pact_id, m.predeposit_deadline_at,
           m.predeposit_received_cents, m.net_amount_cents,
           p.title AS pact_title, p.created_by_user_id
    FROM public.milestones m
    JOIN public.pacts p ON p.id = m.pact_id
    WHERE m.state = 'pending_predeposit'
      AND m.predeposit_deadline_at IS NOT NULL
      AND m.predeposit_deadline_at < now()
  LOOP
    UPDATE public.milestones
    SET state = 'paused_no_predeposit',
        state_updated_at = now()
    WHERE id = v_milestone.id;

    v_paused_ids := array_append(v_paused_ids, v_milestone.id);
    v_actor_user := v_milestone.created_by_user_id;

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_milestone.pact_id, 'milestone_paused_by_cron',
      jsonb_build_object(
        'milestone_id', v_milestone.id,
        'deadline', v_milestone.predeposit_deadline_at,
        'predeposit_received_cents', v_milestone.predeposit_received_cents,
        'net_amount_cents', v_milestone.net_amount_cents,
        'reason', 'predeposit_deadline_expired'
      ),
      v_actor_user);

    INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
    VALUES (v_actor_user, 'milestone_paused_by_cron', 'milestone', v_milestone.id,
      jsonb_build_object('deadline', v_milestone.predeposit_deadline_at));

    SELECT array_agg(user_id) INTO v_recipients
    FROM public.fn_notification_recipients(
      v_milestone.pact_id, NULL, true, NULL
    );

    PERFORM public.fn_create_notifications(
      p_user_ids        := v_recipients,
      p_notification_type := 'milestone_paused_no_predeposit',
      p_title           := 'Obra paralizada · ' || coalesce(v_milestone.name, 'Hito'),
      p_body            := 'La certificación de "' ||
                           coalesce(v_milestone.pact_title, 'la obra') ||
                           '" quedó paralizada porque el pre-depósito no se completó en plazo. ' ||
                           'El promotor puede reanudarla aportando el importe pendiente.',
      p_pact_id         := v_milestone.pact_id,
      p_milestone_id    := v_milestone.id,
      p_cta_url         := '/pacts/' || v_milestone.pact_id::text ||
                           '/milestones/' || v_milestone.id::text,
      p_priority        := 'high',
      p_idempotency_root := 'paused_no_predeposit:' || v_milestone.id::text
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'paused_count', array_length(v_paused_ids, 1),
    'paused_ids', coalesce(to_jsonb(v_paused_ids), '[]'::jsonb),
    'checked_at', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_check_predeposit_deadlines TO authenticated, service_role;

COMMENT ON FUNCTION public.sf_check_predeposit_deadlines IS
  'Sprint 5 chunk 6 · Job de paralización automática. Detecta hitos '
  'v2.1 con pre-depósito vencido y los pasa a paused_no_predeposit, '
  'notificando a las partes. Programado vía pg_cron cada hora.';


-- =====================================================================
-- Programación con pg_cron (Supabase Pro+)
-- =====================================================================
-- En Free puede no estar disponible la extensión; si falla aquí, hay
-- que cambiar a Edge Function + cron-job.org externo.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Limpiamos cualquier job previo con el mismo nombre.
SELECT cron.unschedule('check-predeposit-deadlines')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'check-predeposit-deadlines'
);

-- Programar: minuto 0 de cada hora.
SELECT cron.schedule(
  'check-predeposit-deadlines',
  '0 * * * *',
  $$ SELECT public.sf_check_predeposit_deadlines(); $$
);

NOTIFY pgrst, 'reload schema';
