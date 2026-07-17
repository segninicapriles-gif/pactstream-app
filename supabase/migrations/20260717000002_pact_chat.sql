-- =====================================================================
-- Fase 2 · Auditoría 16-jul · F2.4b · Chat in-app entre partes del pacto
-- =====================================================================
--
-- Sin chat in-app hoy toda la coordinación se va a WhatsApp y las
-- disputas ocurren sin contexto compartido (auditoría 16-jul).
--
-- MVP mínimo funcional:
--   - pact_messages: tabla append-mostly con soft-delete del autor.
--   - pact_message_reads: last_read_at por (pact_id, user_id) para
--     calcular no leídos sin coste.
--   - RPCs: sf_send_pact_message, sf_list_pact_messages (keyset),
--     sf_mark_pact_read, sf_unread_pact_messages_count.
--   - Al enviar mensaje se inserta pact_events tipo 'pact_message_sent'
--     → el trigger F2.4 fn_notifications_from_event crea notificación
--     para las demás partes. (Actualizamos esa función abajo para
--     incluir el nuevo case.)
--
-- No incluye MVP: attachments, edición, reply-to, presencia (typing),
-- reacciones. Todo eso es v2 sobre este mismo esquema.

-- ─── 1. Tablas ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pact_messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id        uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES public.users(id),
  body           text NOT NULL CHECK (
    length(btrim(body)) > 0 AND length(body) <= 2000
  ),
  created_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz  -- soft-delete: el autor puede retirar el mensaje
);

CREATE INDEX IF NOT EXISTS idx_pact_messages_pact_created
  ON public.pact_messages (pact_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.pact_message_reads (
  pact_id      uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pact_id, user_id)
);

ALTER TABLE public.pact_messages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pact_message_reads  ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.pact_messages IS
  'Chat entre partes de un pacto. Todo acceso vía RPC (RLS deny-by-default).';

-- ─── 2. RLS · deny-by-default (todo acceso vía RPCs SECURITY DEFINER) ─

-- No hay ninguna policy explícita → default-deny para authenticated.
-- Las RPCs abajo son SECURITY DEFINER y validan pertenencia por su
-- cuenta usando fn_user_can_act_on_pact.

-- ─── 3. RPC · enviar mensaje ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sf_send_pact_message(
  p_pact_id uuid,
  p_body    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     uuid;
  v_message_id  uuid;
  v_pact_state  text;
  v_body_clean  text;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  -- Bloqueamos escritura en pactos terminales (evita ensuciar
  -- histórico legal de pactos ya cerrados).
  SELECT state::text INTO v_pact_state
    FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state IN ('cancelled', 'completed_paid') THEN
    RAISE EXCEPTION 'No se puede enviar mensajes en un pacto %', v_pact_state;
  END IF;

  v_body_clean := btrim(p_body);
  IF length(v_body_clean) = 0 THEN
    RAISE EXCEPTION 'El mensaje está vacío';
  END IF;
  IF length(v_body_clean) > 2000 THEN
    RAISE EXCEPTION 'El mensaje supera 2000 caracteres';
  END IF;

  INSERT INTO public.pact_messages (pact_id, sender_user_id, body)
       VALUES (p_pact_id, v_user_id, v_body_clean)
    RETURNING id INTO v_message_id;

  -- Registrar en pact_events → dispara trigger de notificaciones (F2.4)
  -- que notifica a las demás partes. Solo enviamos un preview del body
  -- (nunca 2000 caracteres en el payload de un evento).
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
       VALUES (
         p_pact_id,
         'pact_message_sent',
         jsonb_build_object(
           'message_id', v_message_id,
           'preview', left(v_body_clean, 140)
         ),
         v_user_id
       );

  -- Marcamos el propio mensaje como leído para el autor.
  INSERT INTO public.pact_message_reads (pact_id, user_id, last_read_at)
       VALUES (p_pact_id, v_user_id, now())
   ON CONFLICT (pact_id, user_id)
   DO UPDATE SET last_read_at = EXCLUDED.last_read_at;

  RETURN jsonb_build_object('id', v_message_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_send_pact_message(uuid, text) TO authenticated;

-- ─── 4. RPC · listar mensajes (paginación keyset) ───────────────────

CREATE OR REPLACE FUNCTION public.sf_list_pact_messages(
  p_pact_id   uuid,
  p_limit     int  DEFAULT 50,
  p_before_at timestamptz DEFAULT NULL
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
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  -- Clamping defensivo del limit.
  p_limit := greatest(1, least(coalesce(p_limit, 50), 200));

  SELECT jsonb_agg(payload ORDER BY ord DESC)
    INTO v_items
    FROM (
      SELECT
        m.created_at AS ord,
        jsonb_build_object(
          'id', m.id,
          'sender_user_id', m.sender_user_id,
          'sender_name', u.full_name,
          'sender_role', pp.role::text,
          -- Cuando el mensaje está soft-deleted, no exponemos su cuerpo
          -- a nadie (queda una tombstone visible en el hilo).
          'body', CASE WHEN m.deleted_at IS NULL THEN m.body ELSE NULL END,
          'deleted_at', m.deleted_at,
          'created_at', m.created_at,
          'is_mine', (m.sender_user_id = v_user_id)
        ) AS payload
      FROM public.pact_messages m
      LEFT JOIN public.users u ON u.id = m.sender_user_id
      LEFT JOIN public.pact_parties pp
             ON pp.pact_id = m.pact_id AND pp.user_id = m.sender_user_id
      WHERE m.pact_id = p_pact_id
        AND (p_before_at IS NULL OR m.created_at < p_before_at)
      ORDER BY m.created_at DESC
      LIMIT p_limit
    ) t;

  RETURN coalesce(v_items, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_list_pact_messages(uuid, int, timestamptz) TO authenticated;

-- ─── 5. RPC · marcar como leídos ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sf_mark_pact_read(p_pact_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  INSERT INTO public.pact_message_reads (pact_id, user_id, last_read_at)
       VALUES (p_pact_id, v_user_id, now())
   ON CONFLICT (pact_id, user_id)
   DO UPDATE SET last_read_at = EXCLUDED.last_read_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_mark_pact_read(uuid) TO authenticated;

-- ─── 6. RPC · contar no leídos ──────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sf_unread_pact_messages_count(
  p_pact_id uuid
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      uuid;
  v_last_read_at timestamptz;
  v_count        int;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  SELECT last_read_at INTO v_last_read_at
    FROM public.pact_message_reads
   WHERE pact_id = p_pact_id AND user_id = v_user_id;

  SELECT count(*) INTO v_count
    FROM public.pact_messages m
   WHERE m.pact_id = p_pact_id
     AND m.deleted_at IS NULL
     AND m.sender_user_id <> v_user_id
     AND (v_last_read_at IS NULL OR m.created_at > v_last_read_at);

  RETURN coalesce(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_unread_pact_messages_count(uuid) TO authenticated;

-- ─── 7. RPC · soft-delete de mensaje propio ─────────────────────────

CREATE OR REPLACE FUNCTION public.sf_delete_pact_message(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.pact_messages
     SET deleted_at = coalesce(deleted_at, now())
   WHERE id = p_message_id
     AND sender_user_id = v_user_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mensaje no encontrado o no eres el autor';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_delete_pact_message(uuid) TO authenticated;

-- ─── 8. Actualizar trigger F2.4 para el nuevo event_type ────────────
-- Añadimos 'pact_message_sent' al switch de fn_notifications_from_event.
-- Como CREATE OR REPLACE requiere el cuerpo completo, y no queremos
-- duplicar los 200 líneas de la migración 20260717000001, hacemos un
-- ALTER indirecto: cambiamos la función para que llame a un helper
-- separado por tipo — pero eso es refactor. Solución más simple:
-- redefinir la función completa incluyendo el WHEN nuevo. Para evitar
-- desincronizar copias, extraemos el helper por chat aparte.

CREATE OR REPLACE FUNCTION public.fn_notify_pact_message(
  p_pact_id       uuid,
  p_sender_id     uuid,
  p_message_id    uuid,
  p_preview       text,
  p_event_id      uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipients uuid[];
  v_sender_name text;
  v_pact_title  text;
BEGIN
  SELECT full_name INTO v_sender_name FROM public.users WHERE id = p_sender_id;
  SELECT title     INTO v_pact_title  FROM public.pacts WHERE id = p_pact_id;

  SELECT array_agg(user_id) INTO v_recipients
    FROM public.fn_notification_recipients(p_pact_id, NULL, false, p_sender_id);

  PERFORM public.fn_create_notifications(
    p_user_ids          := v_recipients,
    p_notification_type := 'pact_message',
    p_title             := 'Mensaje en ' || coalesce(v_pact_title, 'la obra'),
    p_body              := coalesce(v_sender_name, 'Alguien') || ': ' ||
                           coalesce(p_preview, ''),
    p_pact_id           := p_pact_id,
    p_cta_url           := '/pacts/' || p_pact_id::text || '/chat',
    p_priority          := 'normal',
    p_idempotency_root  := 'event:' || p_event_id::text
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_notify_pact_message(uuid, uuid, uuid, text, uuid) FROM PUBLIC;

-- Y ahora actualizamos el trigger para añadir el nuevo case. Redefinimos
-- la función completa (patrón necesario en Postgres).

CREATE OR REPLACE FUNCTION public.fn_notifications_from_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipients      uuid[];
  v_pact_title      text;
  v_milestone_id    uuid;
  v_milestone_name  text;
  v_milestone_amount bigint;
  v_amount_cents    bigint;
  v_decision        text;
  v_idem            text;
BEGIN
  IF NEW.event_type IN (
    'mock_funded',
    'evidence_uploaded',
    'milestone_submitted_for_review'
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW.event_type IN ('pact_finalized', 'all_parties_accepted') THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_pact_title FROM public.pacts WHERE id = NEW.pact_id;
  v_milestone_id := NULLIF(NEW.payload ->> 'milestone_id', '')::uuid;
  IF v_milestone_id IS NOT NULL THEN
    SELECT name, amount_cents INTO v_milestone_name, v_milestone_amount
      FROM public.milestones WHERE id = v_milestone_id;
  END IF;
  v_idem := 'event:' || NEW.id::text;

  CASE NEW.event_type

    WHEN 'contract_fully_signed' THEN
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(NEW.pact_id, NULL, false, NEW.actor_user_id);
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'contract_signed',
        p_title := 'Contrato firmado · ' || coalesce(v_pact_title, 'la obra'),
        p_body := 'Todas las partes han firmado. El promotor puede '
               || 'configurar ya el Hito 0 Asegurado.',
        p_pact_id := NEW.pact_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    WHEN 'milestone_tech_reviewed' THEN
      v_decision := NEW.payload ->> 'decision';
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id,
          CASE WHEN v_decision = 'approve'
               THEN ARRAY['constructor', 'promotor']
               ELSE ARRAY['constructor'] END,
          false, NEW.actor_user_id
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'milestone_tech_reviewed',
        p_title := CASE v_decision
          WHEN 'approve'        THEN 'Técnico validó el hito · '
          WHEN 'reject'         THEN 'Técnico pide correcciones · '
          WHEN 'info_requested' THEN 'Técnico pide más información · '
          ELSE                       'Decisión del técnico · '
        END || coalesce(v_milestone_name, 'Sin nombre'),
        p_body := CASE v_decision
          WHEN 'approve'
            THEN 'El técnico ha validado el hito. Ahora le toca al promotor aprobar el pago.'
          WHEN 'reject'
            THEN 'El técnico ha rechazado el hito. Revisa el motivo y aporta las correcciones.'
          WHEN 'info_requested'
            THEN 'El técnico necesita más información antes de validar. Revisa qué falta.'
          ELSE 'El técnico ha registrado su decisión sobre el hito.'
        END,
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text
                  || '/milestones/' || v_milestone_id::text,
        p_priority := CASE WHEN v_decision = 'approve' THEN 'normal' ELSE 'high' END,
        p_idempotency_root := v_idem
      );

    WHEN 'milestone_paid' THEN
      v_amount_cents := coalesce(
        NULLIF(NEW.payload ->> 'amount_cents', '')::bigint,
        v_milestone_amount
      );
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['constructor'], true, NULL
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'milestone_paid',
        p_title := 'Cobrado ·  '
          || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
          || ' €',
        p_body := 'Se ha liberado el pago del hito "'
               || coalesce(v_milestone_name, 'sin nombre')
               || '" de ' || coalesce(v_pact_title, 'la obra') || '.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text
                  || '/milestones/' || v_milestone_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    WHEN 'cert_v21_created' THEN
      v_amount_cents := NULLIF(NEW.payload ->> 'gross_cents', '')::bigint;
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['promotor'], true, NEW.actor_user_id
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'cert_created',
        p_title := 'Nueva certificación · ' || coalesce(v_pact_title, 'la obra'),
        p_body := 'El constructor ha emitido una certificación de '
               || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
               || ' €. Revisa y aprueba el pre-depósito.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    WHEN 'deposit_replenished' THEN
      v_amount_cents := NULLIF(NEW.payload ->> 'amount_cents', '')::bigint;
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['constructor', 'tecnico'], false, NEW.actor_user_id
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'deposit_replenished',
        p_title := 'Depósito repuesto · ' || coalesce(v_pact_title, 'la obra'),
        p_body := 'El promotor ha añadido '
               || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
               || ' € al depósito de la obra. Puedes continuar con el siguiente hito.',
        p_pact_id := NEW.pact_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'normal',
        p_idempotency_root := v_idem
      );

    WHEN 'pact_completed' THEN
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(NEW.pact_id, NULL, false, NULL);
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'pact_completed',
        p_title := 'Obra finalizada · ' || coalesce(v_pact_title, ''),
        p_body := 'Todos los hitos han quedado certificados y pagados. ¡Enhorabuena!',
        p_pact_id := NEW.pact_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'normal',
        p_idempotency_root := v_idem
      );

    WHEN 'milestone_paused_by_cron' THEN
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['promotor'], true, NULL
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'milestone_paused',
        p_title := 'Hito pausado · ' || coalesce(v_milestone_name, ''),
        p_body := 'El hito se ha pausado automáticamente porque venció el '
               || 'plazo del pre-depósito. Repón el depósito para reactivar la obra.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    -- NUEVO F2.4b · mensaje de chat enviado
    WHEN 'pact_message_sent' THEN
      PERFORM public.fn_notify_pact_message(
        NEW.pact_id,
        NEW.actor_user_id,
        NULLIF(NEW.payload ->> 'message_id', '')::uuid,
        NEW.payload ->> 'preview',
        NEW.id
      );

    ELSE
      NULL;
  END CASE;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'fn_notifications_from_event failed for event %: %',
      NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_notifications_from_event IS
  'Auditoría 16-jul F2.4 + F2.4b: notifica 8 event_types del ciclo del pacto (incluye pact_message_sent del chat).';
