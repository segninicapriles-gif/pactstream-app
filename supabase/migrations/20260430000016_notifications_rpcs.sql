-- =====================================================================
-- Sprint 3 chunk 2 · Migration 0020
-- RPCs para que el cliente Flutter lea notificaciones in-app del usuario.
-- =====================================================================
-- Funciones:
--   sf_list_my_notifications(p_limit, p_only_unread)  → lista paginada
--   sf_count_unread_notifications()                   → badge bottom nav
--   sf_mark_notification_read(p_notification_id)      → al hacer tap
--   sf_mark_all_notifications_read()                  → CTA "marcar todas"
-- =====================================================================

-- ---------------------------------------------------------------------
-- sf_list_my_notifications
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_list_my_notifications;
CREATE OR REPLACE FUNCTION public.sf_list_my_notifications(
  p_limit int DEFAULT 50,
  p_only_unread boolean DEFAULT false
)
RETURNS TABLE(
  id uuid,
  notification_type text,
  pact_id uuid,
  pact_display_id text,
  pact_title text,
  milestone_id uuid,
  priority text,
  title text,
  body text,
  cta_url text,
  read_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  RETURN QUERY
  SELECT
    n.id,
    n.notification_type,
    n.pact_id,
    p.display_id AS pact_display_id,
    p.title AS pact_title,
    n.milestone_id,
    n.priority::text,
    n.title,
    n.body,
    n.cta_url,
    n.read_at,
    n.created_at
  FROM public.notifications n
  LEFT JOIN public.pacts p ON p.id = n.pact_id
  WHERE n.user_id = v_user_id
    AND n.channel = 'in_app'
    AND (NOT p_only_unread OR n.read_at IS NULL)
  ORDER BY n.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_list_my_notifications TO authenticated;


-- ---------------------------------------------------------------------
-- sf_count_unread_notifications
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_count_unread_notifications;
CREATE OR REPLACE FUNCTION public.sf_count_unread_notifications()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_count int;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RETURN 0;
  END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT count(*)::int INTO v_count
  FROM public.notifications
  WHERE user_id = v_user_id
    AND channel = 'in_app'
    AND read_at IS NULL;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_count_unread_notifications TO authenticated;


-- ---------------------------------------------------------------------
-- sf_mark_notification_read
-- ---------------------------------------------------------------------
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
  v_auth_uid uuid;
  v_user_id uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.notifications
  SET read_at = now()
  WHERE id = p_notification_id
    AND user_id = v_user_id
    AND read_at IS NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_mark_notification_read TO authenticated;


-- ---------------------------------------------------------------------
-- sf_mark_all_notifications_read
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.sf_mark_all_notifications_read;
CREATE OR REPLACE FUNCTION public.sf_mark_all_notifications_read()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_count int;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  WITH updated AS (
    UPDATE public.notifications
    SET read_at = now()
    WHERE user_id = v_user_id
      AND channel = 'in_app'
      AND read_at IS NULL
    RETURNING id
  )
  SELECT count(*)::int INTO v_count FROM updated;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_mark_all_notifications_read TO authenticated;


COMMENT ON FUNCTION public.sf_list_my_notifications IS
  'Lista las notificaciones in_app del usuario autenticado, con join al pact (display_id, title) para mostrar contexto.';
COMMENT ON FUNCTION public.sf_count_unread_notifications IS
  'Cuenta no leídas para el badge del bottom nav.';

NOTIFY pgrst, 'reload schema';
