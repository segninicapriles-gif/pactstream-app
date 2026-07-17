-- =====================================================================
-- Fase 2 · Auditoría 16-jul · F2.4 (parte notif. proactivas)
-- =====================================================================
--
-- La infraestructura de notifications existe desde el Sprint 6
-- (20260520000005_notifications_helpers.sql), pero solo 3 RPCs la
-- consumen a mano: mock_fund, record_evidence, submit_for_review.
-- Faltan los eventos del CICLO DEL DINERO — precisamente los que
-- generan más ansiedad y por los que el usuario abre la app "a ver
-- si ha pasado algo".
--
-- Estrategia: en vez de reescribir cada RPC (invasivo y riesgoso),
-- un AFTER INSERT trigger sobre pact_events consume los tipos NO
-- instrumentados aún. Ventajas:
--   - No toca ninguna RPC core → riesgo mínimo.
--   - Cualquier futura RPC que inserte pact_events dispara notif
--     automáticamente sin cambio adicional.
--   - Reversible con DROP TRIGGER.
--
-- Cubre 7 event_types que hoy pasan silenciosos:
--   contract_fully_signed      → todas las partes
--   milestone_tech_reviewed    → constructor (y promotor si aprobado)
--   milestone_paid             → constructor
--   cert_v21_created           → promotor
--   deposit_replenished        → constructor + técnico
--   pact_completed             → todas las partes
--   milestone_paused_by_cron   → promotor (necesita reponer depósito)
--
-- Idempotency: fn_create_notifications usa idempotency_key con root
-- 'event:{pact_event_id}' → si el trigger se re-ejecuta o el mismo
-- pact_event se inserta dos veces, no duplica.

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
  -- Saltar los event_types ya notificados a mano en su RPC (evita
  -- duplicados con las 3 instrumentaciones existentes del Sprint 6).
  IF NEW.event_type IN (
    'mock_funded',
    'evidence_uploaded',
    'milestone_submitted_for_review'
  ) THEN
    RETURN NEW;
  END IF;

  -- Los eventos administrativos (pact_finalized, all_parties_accepted)
  -- ya se notifican por email vía otros triggers → los saltamos aquí.
  IF NEW.event_type IN ('pact_finalized', 'all_parties_accepted') THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_pact_title FROM public.pacts WHERE id = NEW.pact_id;
  v_milestone_id := NULLIF(NEW.payload ->> 'milestone_id', '')::uuid;
  IF v_milestone_id IS NOT NULL THEN
    SELECT name, amount_cents INTO v_milestone_name, v_milestone_amount
    FROM public.milestones WHERE id = v_milestone_id;
  END IF;

  -- Idempotency por pact_event.id: garantiza que aunque el trigger
  -- se dispare dos veces (raro pero posible), la notificación NO se
  -- duplica gracias al UNIQUE en notifications.idempotency_key.
  v_idem := 'event:' || NEW.id::text;

  CASE NEW.event_type

    -- ── Contrato firmado por todas las partes ─────────────────────
    WHEN 'contract_fully_signed' THEN
      SELECT array_agg(user_id) INTO v_recipients
      FROM public.fn_notification_recipients(
        NEW.pact_id, NULL, false, NEW.actor_user_id
      );
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

    -- ── Técnico ha revisado (aprobado / rechazado / info pedida) ─
    WHEN 'milestone_tech_reviewed' THEN
      v_decision := NEW.payload ->> 'decision';
      -- Notificamos al constructor SIEMPRE (le afecta directo).
      -- Si el técnico aprobó, además notificamos al promotor (le toca).
      SELECT array_agg(user_id) INTO v_recipients
      FROM public.fn_notification_recipients(
        NEW.pact_id,
        CASE WHEN v_decision = 'approve'
             THEN ARRAY['constructor', 'promotor']
             ELSE ARRAY['constructor'] END,
        false,
        NEW.actor_user_id
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

    -- ── Hito pagado — al constructor le llega el cobro ────────────
    WHEN 'milestone_paid' THEN
      v_amount_cents := coalesce(
        NULLIF(NEW.payload ->> 'amount_cents', '')::bigint,
        v_milestone_amount
      );
      -- Al constructor (con permiso económico). Excluimos al actor
      -- si es el propio constructor viendo su UI.
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

    -- ── Certificación nueva creada — al promotor le toca aprobar ──
    WHEN 'cert_v21_created' THEN
      v_amount_cents := NULLIF(NEW.payload ->> 'gross_cents', '')::bigint;
      SELECT array_agg(user_id) INTO v_recipients
      FROM public.fn_notification_recipients(
        NEW.pact_id, ARRAY['promotor'], true, NEW.actor_user_id
      );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'cert_created',
        p_title := 'Nueva certificación · '
                || coalesce(v_pact_title, 'la obra'),
        p_body := 'El constructor ha emitido una certificación de '
               || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
               || ' €. Revisa y aprueba el pre-depósito.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    -- ── Depósito repuesto — al constructor le llega la cobertura ──
    WHEN 'deposit_replenished' THEN
      v_amount_cents := NULLIF(NEW.payload ->> 'amount_cents', '')::bigint;
      SELECT array_agg(user_id) INTO v_recipients
      FROM public.fn_notification_recipients(
        NEW.pact_id,
        ARRAY['constructor', 'tecnico'],
        false,
        NEW.actor_user_id
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

    -- ── Pacto completado — a todos ─────────────────────────────────
    WHEN 'pact_completed' THEN
      SELECT array_agg(user_id) INTO v_recipients
      FROM public.fn_notification_recipients(
        NEW.pact_id, NULL, false, NULL
      );
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

    -- ── Hito pausado por cron (deadline vencido) — al promotor ────
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

    ELSE
      -- Cualquier otro event_type no cubierto: no-op. Añadir aquí
      -- según aparezcan eventos nuevos.
      NULL;
  END CASE;

  RETURN NEW;
EXCEPTION
  -- Nunca romper la operación core por un fallo de notificación. Si
  -- fn_create_notifications falla (raro), el trigger no explota — la
  -- inserción del pact_event sigue adelante.
  WHEN OTHERS THEN
    RAISE WARNING 'fn_notifications_from_event failed for event %: %',
      NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- El trigger reemplaza cualquier versión anterior con el mismo nombre.
DROP TRIGGER IF EXISTS trg_notifications_from_event ON public.pact_events;
CREATE TRIGGER trg_notifications_from_event
  AFTER INSERT ON public.pact_events
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notifications_from_event();

COMMENT ON FUNCTION public.fn_notifications_from_event IS
  'Auditoría 16-jul F2.4: instrumenta notificaciones para los 7 event_types del ciclo del dinero que aún no las tenían. Idempotent por event.id. Falla silenciosa: no rompe la operación core si notificar falla.';
