-- =====================================================================
-- Sprint 6 chunk 6a · Helpers de notificación
-- =====================================================================
--   * Toggles por miembro de organización para recibir o no avisos.
--   * fn_notification_recipients: resuelve destinatarios (parties +
--     miembros activos con permisos correctos), con exclusión opcional
--     del actor.
--   * fn_create_notifications: helper bulk con idempotency_key.
--   * RPCs sf_list_my_notifications, sf_mark_notification_read,
--     sf_mark_all_notifications_read.
-- =====================================================================

ALTER TABLE public.organization_members
  ADD COLUMN IF NOT EXISTS receive_notifications boolean NOT NULL DEFAULT true;

ALTER TABLE public.organization_members
  ADD COLUMN IF NOT EXISTS receive_economic_notifications boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.organization_members.receive_notifications IS
  'Si false, el miembro NO recibe ninguna notificación in-app/email de '
  'pactos donde su organización participa. Default true.';

COMMENT ON COLUMN public.organization_members.receive_economic_notifications IS
  'Si false, el miembro no recibe notificaciones de eventos económicos. '
  'Sólo aplica si también tiene can_view_economics=true. Default true.';


DROP FUNCTION IF EXISTS public.fn_notification_recipients;
CREATE OR REPLACE FUNCTION public.fn_notification_recipients(
  p_pact_id         uuid,
  p_target_roles    text[] DEFAULT NULL,
  p_economic        boolean DEFAULT false,
  p_exclude_user_id uuid DEFAULT NULL
)
RETURNS TABLE (user_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT pp.user_id
  FROM public.pact_parties pp
  WHERE pp.pact_id = p_pact_id
    AND (p_target_roles IS NULL OR pp.role::text = ANY(p_target_roles))
    AND (p_exclude_user_id IS NULL OR pp.user_id <> p_exclude_user_id)
    AND pp.user_id IS NOT NULL

  UNION

  SELECT DISTINCT om.user_id
  FROM public.pact_parties pp
  JOIN public.users u ON u.id = pp.user_id
  JOIN public.organization_members om
    ON om.organization_id = u.organization_id
   AND om.state = 'active'
   AND om.receive_notifications = true
   AND (NOT p_economic OR (om.can_view_economics AND om.receive_economic_notifications))
  WHERE pp.pact_id = p_pact_id
    AND (p_target_roles IS NULL OR pp.role::text = ANY(p_target_roles))
    AND om.user_id IS NOT NULL
    AND (p_exclude_user_id IS NULL OR om.user_id <> p_exclude_user_id);
$$;

GRANT EXECUTE ON FUNCTION public.fn_notification_recipients TO authenticated;


DROP FUNCTION IF EXISTS public.fn_create_notifications;
CREATE OR REPLACE FUNCTION public.fn_create_notifications(
  p_user_ids       uuid[],
  p_notification_type text,
  p_title          text,
  p_body           text,
  p_pact_id        uuid DEFAULT NULL,
  p_milestone_id   uuid DEFAULT NULL,
  p_cta_url        text DEFAULT NULL,
  p_priority       text DEFAULT 'normal',
  p_idempotency_root text DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  uuid;
  v_inserted int := 0;
  v_key      text;
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  FOREACH v_user_id IN ARRAY p_user_ids LOOP
    v_key := coalesce(
      p_idempotency_root,
      p_notification_type || ':' || coalesce(p_pact_id::text, '-') || ':' ||
        coalesce(p_milestone_id::text, '-') || ':' ||
        to_char(now(), 'YYYYMMDDHH24MISS')
    ) || ':' || v_user_id::text;

    BEGIN
      INSERT INTO public.notifications (
        user_id, pact_id, milestone_id,
        notification_type, channel, priority,
        title, body, cta_url, sent_at, idempotency_key
      ) VALUES (
        v_user_id, p_pact_id, p_milestone_id,
        p_notification_type, 'in_app', p_priority::notification_priority,
        p_title, p_body, p_cta_url, now(), v_key
      );
      v_inserted := v_inserted + 1;
    EXCEPTION
      WHEN unique_violation THEN
        NULL;
    END;
  END LOOP;

  RETURN v_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_notifications TO authenticated;


DROP FUNCTION IF EXISTS public.sf_list_my_notifications;
CREATE OR REPLACE FUNCTION public.sf_list_my_notifications(
  p_limit       int     DEFAULT 50,
  p_only_unread boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_items   jsonb;
BEGIN
  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT jsonb_agg(payload ORDER BY ord_at DESC)
    INTO v_items
  FROM (
    SELECT
      n.created_at AS ord_at,
      jsonb_build_object(
        'id', n.id,
        'pact_id', n.pact_id,
        'milestone_id', n.milestone_id,
        'notification_type', n.notification_type,
        'priority', n.priority::text,
        'title', n.title,
        'body', n.body,
        'cta_url', n.cta_url,
        'read_at', n.read_at,
        'sent_at', n.sent_at,
        'created_at', n.created_at
      ) AS payload
    FROM public.notifications n
    WHERE n.user_id = v_user_id
      AND n.channel = 'in_app'
      AND (NOT p_only_unread OR n.read_at IS NULL)
    ORDER BY n.created_at DESC
    LIMIT p_limit
  ) t;

  -- Array plano (no envuelto en objeto) por compatibilidad con el
  -- cliente Flutter del Sprint 3. El contador de no-leídas se obtiene
  -- aparte con sf_count_unread_notifications.
  RETURN coalesce(v_items, '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_list_my_notifications TO authenticated;


DROP FUNCTION IF EXISTS public.sf_mark_notification_read;
CREATE OR REPLACE FUNCTION public.sf_mark_notification_read(
  p_notification_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.notifications
  SET read_at = coalesce(read_at, now())
  WHERE id = p_notification_id AND user_id = v_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_mark_notification_read TO authenticated;


DROP FUNCTION IF EXISTS public.sf_mark_all_notifications_read;
CREATE OR REPLACE FUNCTION public.sf_mark_all_notifications_read()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_count   int;
BEGIN
  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  WITH upd AS (
    UPDATE public.notifications
    SET read_at = now()
    WHERE user_id = v_user_id
      AND channel = 'in_app'
      AND read_at IS NULL
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM upd;

  RETURN coalesce(v_count, 0);
END;
$$;
GRANT EXECUTE ON FUNCTION public.sf_mark_all_notifications_read TO authenticated;

NOTIFY pgrst, 'reload schema';
