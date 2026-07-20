-- 20260720000002 · Disputas: cerrar el callejón sin salida
-- ─────────────────────────────────────────────────────────────────────────────
-- CONTEXTO (verificado 20-jul-2026):
--   Un hito podía ENTRAR en 'disputed' (escrow_guards.sql:266 + el trigger
--   fn_dispute_escrow_auto_create crea el dispute_escrow), pero NO había forma
--   de SALIR: `sf_resolve_dispute_escrow` solo repartía el dinero del escrow y
--   dejaba `milestones.state = 'disputed'` para siempre. Además no tenía ningún
--   call-site en Dart. Resultado: 'disputed' era terminal de facto.
--
-- ESTE FIX (solo backend; la UI va aparte para no pisar otra sesión activa):
--   `sf_resolve_dispute_escrow` v2 = money (igual que antes) + transición del
--   estado del hito según el resultado, respetando el state machine v2.1
--   (validate_milestone_state_transition permite disputed → paid|in_execution).
--
--   Mapeo (decisión de producto de Andrés, 20-jul):
--     favor_constructor (disputa RECHAZADA) → 'paid'         → se procede al pago
--     favor_promotor    (disputa APROBADA)  → 'in_execution' → ajustes para liberar
--     split             (parcial)           → 'in_execution' → completar lo pendiente
--
-- ⚠️ CAVEAT DE DINERO (clase F1.5 — verificar en staging antes de prod):
--   El salto disputed→'paid' NO replica la contabilidad del release que sí hace
--   el camino normal awaiting_promotor→paid (fila en `pagos`, advance_released).
--   Hoy el release es MOCK (Mangopay pendiente), así que no descuadra dinero
--   real, pero cuando se cablee el pago real hay que enganchar aquí el mismo
--   asiento contable. Documentado a propósito.

CREATE OR REPLACE FUNCTION public.sf_resolve_dispute_escrow(
  p_milestone_id uuid,
  p_resolution text,
  p_promotor_pct numeric DEFAULT 100,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_escrow record;
  v_to_promotor bigint;
  v_to_constructor bigint;
  v_final_state text;
  v_milestone_state milestone_state;
  v_milestone_new_state milestone_state;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT de.*
  INTO v_escrow
  FROM public.dispute_escrows de
  WHERE de.milestone_id = p_milestone_id;

  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'No hay escrow de disputa para este hito';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_escrow.pact_id AND user_id = v_user_id;

  -- Solo técnico o promotor pueden resolver
  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o promotor pueden resolver la disputa';
  END IF;

  IF v_escrow.state NOT IN ('deposited', 'pending_deposit') THEN
    RAISE EXCEPTION 'El escrow ya fue resuelto (estado: %)', v_escrow.state;
  END IF;

  IF p_resolution NOT IN ('favor_promotor', 'favor_constructor', 'split') THEN
    RAISE EXCEPTION 'Resolución inválida: %. Usar favor_promotor | favor_constructor | split', p_resolution;
  END IF;

  IF p_promotor_pct < 0 OR p_promotor_pct > 100 THEN
    RAISE EXCEPTION 'p_promotor_pct debe estar entre 0 y 100';
  END IF;

  -- Distribuir fondos
  v_to_promotor := (v_escrow.escrow_amount_cents * p_promotor_pct / 100)::bigint;
  v_to_constructor := v_escrow.escrow_amount_cents - v_to_promotor;

  IF p_resolution = 'favor_promotor' THEN
    v_final_state := 'released_to_promotor';
    v_to_promotor := v_escrow.escrow_amount_cents;
    v_to_constructor := 0;
  ELSIF p_resolution = 'favor_constructor' THEN
    v_final_state := 'released_to_constructor';
    v_to_promotor := 0;
    v_to_constructor := v_escrow.escrow_amount_cents;
  ELSE
    v_final_state := 'split';
  END IF;

  UPDATE public.dispute_escrows
  SET state = v_final_state,
      resolved_at = now(),
      resolution_note = p_note,
      released_to_promotor_cents = v_to_promotor,
      released_to_constructor_cents = v_to_constructor
  WHERE id = v_escrow.id;

  -- Descontar del depósito del pacto
  UPDATE public.pacts
  SET deposit_current_cents = greatest(0, deposit_current_cents - v_escrow.escrow_amount_cents)
  WHERE id = v_escrow.pact_id;

  -- ── NUEVO: transición del estado del hito (salir de 'disputed') ──────────────
  -- Sin esto, el hito quedaba en 'disputed' para siempre (callejón sin salida).
  SELECT state INTO v_milestone_state FROM public.milestones WHERE id = p_milestone_id;
  IF v_milestone_state = 'disputed' THEN
    v_milestone_new_state := CASE p_resolution
      WHEN 'favor_constructor' THEN 'paid'::milestone_state          -- disputa rechazada → se paga
      ELSE 'in_execution'::milestone_state                           -- favor_promotor / split → ajustes
    END;
    -- El trigger validate_milestone_state_transition valida disputed →
    -- {paid, in_execution}; el trigger de completitud del pacto se dispara al
    -- llegar a 'paid'. (Ver CAVEAT DE DINERO en la cabecera.)
    UPDATE public.milestones
    SET state = v_milestone_new_state
    WHERE id = p_milestone_id;
  END IF;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_escrow.pact_id, 'dispute_escrow_resolved',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'resolution', p_resolution,
      'milestone_new_state', v_milestone_new_state,
      'to_promotor_cents', v_to_promotor,
      'to_constructor_cents', v_to_constructor,
      'note', p_note
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'dispute_escrow_resolved', 'dispute_escrow', v_escrow.id,
    jsonb_build_object('resolution', p_resolution, 'promotor_pct', p_promotor_pct,
                       'milestone_new_state', v_milestone_new_state));

  RETURN jsonb_build_object(
    'success', true,
    'resolution', p_resolution,
    'milestone_new_state', v_milestone_new_state,
    'to_promotor_cents', v_to_promotor,
    'to_constructor_cents', v_to_constructor,
    'state', v_final_state
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_resolve_dispute_escrow(uuid, text, numeric, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
