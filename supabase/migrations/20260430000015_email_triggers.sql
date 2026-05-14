-- =====================================================================
-- Sprint 3 · Migration 0019
-- Triggers de notificaciones automáticas por eventos del pacto.
-- =====================================================================
-- Diseño:
--   - Trigger AFTER INSERT en pact_events que llama a handle_pact_event_notify
--   - Esa función mapea event_type → destinatarios + título + body + CTA
--   - Insertamos filas en public.notifications (channel='email' y 'in_app')
--   - Una Edge Function (email-sender) consume las pending email y las envía
--   - Idempotency_key garantiza que no se duplican notificaciones
-- =====================================================================

-- Helper interno para crear notificaciones evitando duplicados.
CREATE OR REPLACE FUNCTION public._enqueue_notification(
  p_user_id uuid,
  p_pact_id uuid,
  p_milestone_id uuid,
  p_type text,
  p_channel notification_channel,
  p_title text,
  p_body text,
  p_cta_url text,
  p_idempotency_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (
    user_id, pact_id, milestone_id, notification_type,
    channel, priority, title, body, cta_url, idempotency_key
  ) VALUES (
    p_user_id, p_pact_id, p_milestone_id, p_type,
    p_channel,
    CASE
      WHEN p_type IN ('milestone_paid', 'milestone_disputed', 'pact_completed')
        THEN 'high'::notification_priority
      ELSE 'normal'::notification_priority
    END,
    p_title, p_body, p_cta_url, p_idempotency_key
  )
  ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$;

-- Crea notificaciones (email + in_app) para uno o varios users.
CREATE OR REPLACE FUNCTION public._notify_users(
  p_user_ids uuid[],
  p_pact_id uuid,
  p_milestone_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_cta_url text,
  p_idempotency_prefix text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  FOREACH v_uid IN ARRAY p_user_ids LOOP
    PERFORM public._enqueue_notification(
      v_uid, p_pact_id, p_milestone_id, p_type,
      'email'::notification_channel,
      p_title, p_body, p_cta_url,
      p_idempotency_prefix || ':email:' || v_uid::text
    );
    PERFORM public._enqueue_notification(
      v_uid, p_pact_id, p_milestone_id, p_type,
      'in_app'::notification_channel,
      p_title, p_body, p_cta_url,
      p_idempotency_prefix || ':in_app:' || v_uid::text
    );
  END LOOP;
END;
$$;


-- Trigger handler principal: mira el event_type y dispara notificaciones.
CREATE OR REPLACE FUNCTION public.handle_pact_event_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pact public.pacts%ROWTYPE;
  v_milestone_id uuid;
  v_milestone_name text;
  v_amount_cents bigint;
  v_constructor_user uuid;
  v_promotor_user uuid;
  v_tecnico_user uuid;
  v_all_users uuid[];
  v_idem text;
BEGIN
  -- Cargar pact
  SELECT * INTO v_pact FROM public.pacts WHERE id = NEW.pact_id;
  IF v_pact.id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Cargar usuarios por rol
  SELECT user_id INTO v_promotor_user FROM public.pact_parties
    WHERE pact_id = NEW.pact_id AND role = 'promotor';
  SELECT user_id INTO v_constructor_user FROM public.pact_parties
    WHERE pact_id = NEW.pact_id AND role = 'constructor';
  SELECT user_id INTO v_tecnico_user FROM public.pact_parties
    WHERE pact_id = NEW.pact_id AND role = 'tecnico';

  -- Lista de todos los users con cuenta
  SELECT array_agg(user_id) INTO v_all_users
  FROM public.pact_parties
  WHERE pact_id = NEW.pact_id AND user_id IS NOT NULL;

  -- Identificador único por evento
  v_idem := 'evt:' || NEW.id::text;

  -- Extraer milestone_id del payload si existe
  v_milestone_id := (NEW.payload->>'milestone_id')::uuid;
  IF v_milestone_id IS NOT NULL THEN
    SELECT name, amount_cents INTO v_milestone_name, v_amount_cents
    FROM public.milestones WHERE id = v_milestone_id;
  END IF;

  -- ========== MAPEO POR TIPO ==========
  CASE NEW.event_type

    -- Cuando todas las partes han aceptado → toca firmar
    WHEN 'all_parties_accepted' THEN
      PERFORM public._notify_users(
        v_all_users, v_pact.id, NULL,
        'all_parties_accepted',
        'Listos para firmar · ' || v_pact.title,
        'Todas las partes han aceptado la invitación. Es momento de firmar el contrato del pacto ' || v_pact.display_id || '.',
        '/pacts/' || v_pact.id || '/sign',
        v_idem
      );

    -- Contrato firmado por todos
    WHEN 'contract_fully_signed' THEN
      PERFORM public._notify_users(
        v_all_users, v_pact.id, NULL,
        'contract_fully_signed',
        'Contrato firmado · ' || v_pact.title,
        'Todas las partes han firmado el contrato del pacto ' || v_pact.display_id || '. El pacto está listo para activar la custodia.',
        '/pacts/' || v_pact.id,
        v_idem
      );

    -- Pacto activado (mock fund o producción)
    WHEN 'mock_funded' THEN
      IF v_constructor_user IS NOT NULL THEN
        PERFORM public._notify_users(
          ARRAY[v_constructor_user], v_pact.id, v_milestone_id,
          'pact_funded',
          'Obra activada · primer hito en ejecución',
          'El promotor ha activado la custodia del pacto ' || v_pact.display_id || '. Ya puedes empezar a subir evidencias del primer hito.',
          '/pacts/' || v_pact.id,
          v_idem
        );
      END IF;

    -- Constructor declara hito listo para revisión
    WHEN 'milestone_submitted_for_review' THEN
      -- En obra mayor: notificar al técnico
      IF v_pact.pact_type = 'obra_mayor' AND v_tecnico_user IS NOT NULL THEN
        PERFORM public._notify_users(
          ARRAY[v_tecnico_user], v_pact.id, v_milestone_id,
          'milestone_pending_tech_review',
          'Hito pendiente de validación técnica',
          'El constructor ha completado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '. Revisa las evidencias y valida.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id,
          v_idem
        );
      ELSIF v_pact.pact_type = 'obra_menor' AND v_promotor_user IS NOT NULL THEN
        -- En obra menor: notificar directamente al promotor
        PERFORM public._notify_users(
          ARRAY[v_promotor_user], v_pact.id, v_milestone_id,
          'milestone_pending_promotor',
          'Hito pendiente de tu validación',
          'En tu obra menor "' || v_pact.title || '", el constructor ha completado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '". Revisa las evidencias.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id,
          v_idem
        );
      END IF;

    -- Técnico revisó el hito
    WHEN 'milestone_tech_reviewed' THEN
      IF (NEW.payload->>'decision') = 'approve' AND v_promotor_user IS NOT NULL THEN
        PERFORM public._notify_users(
          ARRAY[v_promotor_user], v_pact.id, v_milestone_id,
          'milestone_pending_promotor',
          'Hito aprobado por el técnico · te toca',
          'El técnico ha aprobado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '. Aprueba para liberar el pago.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id,
          v_idem
        );
      ELSIF (NEW.payload->>'decision') IN ('reject', 'request_info') AND v_constructor_user IS NOT NULL THEN
        PERFORM public._notify_users(
          ARRAY[v_constructor_user], v_pact.id, v_milestone_id,
          'milestone_needs_rework',
          CASE WHEN (NEW.payload->>'decision') = 'reject'
            THEN 'Hito rechazado por el técnico'
            ELSE 'El técnico solicita más información'
          END,
          'Revisa los comentarios del técnico para el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id,
          v_idem
        );
      END IF;

    -- Promotor aprobó y se pagó el hito
    WHEN 'milestone_paid' THEN
      IF v_constructor_user IS NOT NULL THEN
        PERFORM public._notify_users(
          ARRAY[v_constructor_user], v_pact.id, v_milestone_id,
          'milestone_paid',
          'Pago liberado · ' || COALESCE(v_milestone_name, 'hito'),
          'Se han liberado ' || (v_amount_cents::numeric / 100) || ' € a tu cuenta por el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id,
          v_idem
        );
      END IF;
      -- También notificamos al técnico (informativo, sin email obligatorio)
      IF v_tecnico_user IS NOT NULL THEN
        PERFORM public._enqueue_notification(
          v_tecnico_user, v_pact.id, v_milestone_id,
          'milestone_paid',
          'in_app'::notification_channel,
          'Hito pagado',
          'El hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || ' se ha pagado al constructor.',
          '/pacts/' || v_pact.id,
          v_idem || ':tec_inapp'
        );
      END IF;

    -- Hito en disputa
    WHEN 'milestone_disputed' THEN
      PERFORM public._notify_users(
        v_all_users, v_pact.id, v_milestone_id,
        'milestone_disputed',
        'Hito en disputa · acción requerida',
        'El promotor ha objetado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '. Las partes deben resolver la disputa.',
        '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id,
        v_idem
      );

    -- Pacto completado (todos los hitos pagados)
    WHEN 'pact_completed' THEN
      PERFORM public._notify_users(
        v_all_users, v_pact.id, NULL,
        'pact_completed',
        'Obra completada · ' || v_pact.title,
        'Todos los hitos del pacto ' || v_pact.display_id || ' se han pagado. La obra queda cerrada en PactStream.',
        '/pacts/' || v_pact.id,
        v_idem
      );

    ELSE
      -- otros eventos no generan notificaciones por ahora
      NULL;
  END CASE;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Si algo falla en la notificación, NO bloqueamos el evento de negocio.
  -- Log y seguimos.
  RAISE WARNING 'handle_pact_event_notify error for event % (%): %', NEW.id, NEW.event_type, SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pact_event_notify ON public.pact_events;
CREATE TRIGGER trg_pact_event_notify
  AFTER INSERT ON public.pact_events
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_pact_event_notify();


-- También notificación al invitar parte (sucede vía sf_invite_party, no pact_events)
CREATE OR REPLACE FUNCTION public.handle_party_invited_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pact public.pacts%ROWTYPE;
  v_creator_name text;
BEGIN
  -- Solo notificar si hay user_id (cuenta existente) o email (para enviar email)
  IF NEW.user_id IS NULL AND NEW.snapshot_email IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = NEW.pact_id;

  SELECT full_name INTO v_creator_name
  FROM public.users WHERE id = v_pact.created_by_user_id;

  -- Si tiene cuenta, notificación in-app + email
  IF NEW.user_id IS NOT NULL THEN
    PERFORM public._notify_users(
      ARRAY[NEW.user_id], NEW.pact_id, NULL,
      'pact_invitation',
      'Te han invitado a un pacto · ' || v_pact.title,
      COALESCE(v_creator_name, 'Alguien') || ' te ha invitado como ' || NEW.role::text ||
      ' al pacto ' || v_pact.display_id || ' (' || v_pact.title || ').',
      '/pacts/' || NEW.pact_id,
      'invite:' || NEW.id::text
    );
  ELSE
    -- No tiene cuenta: registramos un email "huérfano" en notifications (sin user_id no es viable)
    -- En este caso la Edge Function leerá directamente pact_parties con snapshot_email
    -- y enviará el email con un magic link de registro. Ver email-sender Edge Function.
    NULL;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_party_invited_notify error for party % : %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_party_invited_notify ON public.pact_parties;
CREATE TRIGGER trg_party_invited_notify
  AFTER INSERT ON public.pact_parties
  FOR EACH ROW
  WHEN (NEW.accepted_at IS NULL)  -- solo invitaciones, no aceptaciones automáticas
  EXECUTE FUNCTION public.handle_party_invited_notify();


-- =====================================================================
-- RPC: marcar como enviado / fallido (la usa la Edge Function)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_notification_sent(
  p_notification_id uuid
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.notifications
  SET sent_at = now()
  WHERE id = p_notification_id AND sent_at IS NULL;
$$;
GRANT EXECUTE ON FUNCTION public.mark_notification_sent TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.mark_notification_failed(
  p_notification_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.notifications
  SET failed_at = now(), failure_reason = p_reason
  WHERE id = p_notification_id;
$$;
GRANT EXECUTE ON FUNCTION public.mark_notification_failed TO authenticated, service_role;


-- =====================================================================
-- RPC: obtener email del destinatario (la Edge Function lo necesita)
-- =====================================================================
-- Devuelve email del user_id o el snapshot_email si no tiene cuenta.
CREATE OR REPLACE FUNCTION public.get_notification_target(
  p_notification_id uuid
)
RETURNS TABLE(
  email text,
  full_name text,
  user_id uuid,
  has_account boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.email::text AS email,
    u.full_name,
    u.id AS user_id,
    true AS has_account
  FROM public.notifications n
  JOIN public.users u ON u.id = n.user_id
  WHERE n.id = p_notification_id
    AND u.deleted_at IS NULL
    AND u.email IS NOT NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_notification_target TO authenticated, service_role;


COMMENT ON FUNCTION public.handle_pact_event_notify IS
  'Trigger AFTER INSERT en pact_events. Genera notificaciones (email + in_app) según event_type. Idempotente por idempotency_key.';
COMMENT ON FUNCTION public.handle_party_invited_notify IS
  'Trigger AFTER INSERT en pact_parties. Notifica al invitado si tiene cuenta. Email vía Edge Function lee directamente pact_parties.';

NOTIFY pgrst, 'reload schema';
