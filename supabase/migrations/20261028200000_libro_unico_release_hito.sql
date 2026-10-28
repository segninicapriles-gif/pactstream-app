-- 20261028200000_libro_unico_release_hito.sql
-- Fase 1 interconexión de datos (auditoría 27-oct): UN solo libro para liberar
-- un hito, se pague con Mangopay o en modo mock.
--
-- Antes: el mock (sf_milestone_promotor_decide) solo ponía el hito en 'paid';
-- no bajaba la custodia ni escribía deposit_movements ni payments. Los
-- ingresos y la custodia del pacto no cuadraban con los hitos pagados.
--
-- Ahora: _sf_milestone_release_ledger hace guard de saldo + decremento de
-- custodia + deposit_movements + hito 'paid' + payments + evento. La llaman
-- el mock y sf_milestone_confirm_release (Mangopay). payments.idempotency_key
-- = 'release:<hito>' en ambos caminos, así que un hito no se libera dos veces.
--
-- Efecto en el mock: aprobar un hito con custodia < neto ya FALLA con
-- «Saldo en custodia insuficiente» (igual que con Mangopay; además los CHECK
-- deposit_current_cents >= 0 y balance_after_cents >= 0 lo exigen). Los hitos
-- ya pagados no se tocan (deposit_movements es append-only).

create or replace function public._sf_milestone_release_ledger(
  p_milestone_id uuid,
  p_actor        uuid,
  p_transfer_id  text,   -- NULL en mock
  p_via          text    -- 'mock' | 'mangopay'
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pact_id       uuid;
  v_net_cents     bigint;
  v_deposit_cents bigint;
  v_constructor   uuid;
begin
  if p_via not in ('mock', 'mangopay') then
    raise exception 'Vía de release inválida: %', p_via;
  end if;

  select m.pact_id, coalesce(m.net_amount_cents, m.amount_cents)
    into v_pact_id, v_net_cents
  from public.milestones m where m.id = p_milestone_id;
  if v_pact_id is null then
    raise exception 'Hito no encontrado: %', p_milestone_id;
  end if;

  select user_id into v_constructor
    from public.pact_parties where pact_id = v_pact_id and role = 'constructor' limit 1;

  -- Guard de saldo (C3) con lock del pacto.
  select deposit_current_cents into v_deposit_cents
    from public.pacts where id = v_pact_id for update;
  if v_deposit_cents < v_net_cents then
    raise exception 'Saldo en custodia insuficiente para liberar el hito (custodia: % € / neto: % €)',
      translate(to_char(v_deposit_cents / 100.0, 'FM999,999,990.00'), ',.', '.,'),
      translate(to_char(v_net_cents / 100.0, 'FM999,999,990.00'), ',.', '.,');
  end if;

  update public.pacts
     set deposit_current_cents = deposit_current_cents - v_net_cents
   where id = v_pact_id;

  insert into public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    related_milestone_id, balance_before_cents, balance_after_cents,
    mangopay_transaction_id, notes
  ) values (
    v_pact_id, 'milestone_release', -v_net_cents, p_actor,
    p_milestone_id, v_deposit_cents, v_deposit_cents - v_net_cents,
    p_transfer_id,
    case when p_via = 'mangopay'
      then 'Release de hito confirmado por Mangopay (transfer ' || p_transfer_id || ')'
      else 'Release de hito (MOCK · sin movimiento real de fondos)' end
  );

  -- Hito 'paid' (dispara los triggers AFTER UPDATE: progreso de obra + póliza).
  update public.milestones
     set state = 'paid', approved_by_promotor_at = now(), paid_at = now()
   where id = p_milestone_id;

  insert into public.payments (
    pact_id, milestone_id, payment_type, amount_cents, state,
    destination_user_id, mangopay_transaction_id, idempotency_key, succeeded_at
  ) values (
    v_pact_id, p_milestone_id, 'milestone_release', v_net_cents, 'succeeded',
    v_constructor, p_transfer_id, 'release:' || p_milestone_id, now()
  );

  insert into public.pact_events (pact_id, event_type, payload, actor_user_id)
  values (v_pact_id, 'milestone_paid',
    jsonb_strip_nulls(jsonb_build_object('milestone_id', p_milestone_id, 'amount_cents', v_net_cents,
      'transfer_id', p_transfer_id, 'via', p_via,
      'note', case when p_via = 'mock' then 'MOCK release · Mangopay pendiente' end)),
    p_actor);

  return v_net_cents;
end;
$$;

revoke all on function public._sf_milestone_release_ledger(uuid, uuid, text, text) from public;
revoke all on function public._sf_milestone_release_ledger(uuid, uuid, text, text) from anon, authenticated;

comment on function public._sf_milestone_release_ledger(uuid, uuid, text, text) is
  'Interna. Libro único de liberación de un hito (guard de saldo, custodia, deposit_movements, paid, payments, evento). La llaman sf_milestone_promotor_decide (mock) y sf_milestone_confirm_release (Mangopay). El llamador valida estado y bloquea el hito.';

-- ── Mock: sf_milestone_promotor_decide ──────────────────────────────
CREATE OR REPLACE FUNCTION public.sf_milestone_promotor_decide(
  p_milestone_id uuid,
  p_decision text,
  p_rationale text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid; v_user_id uuid; v_pact_id uuid; v_pact_type pact_type;
  v_milestone_state milestone_state; v_user_role pact_party_role;
  v_final_state milestone_state; v_amount_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  -- ── Auditoría 2026-07-13 M1: lock de la fila del hito ────────────
  -- Serializa decisiones concurrentes sobre el mismo hito (evita doble
  -- release / doble disputa). Debe ejecutarse ANTES de leer el estado.
  PERFORM 1 FROM public.milestones WHERE id = p_milestone_id FOR UPDATE;

  SELECT m.pact_id, m.state, m.amount_cents, p.pact_type
  INTO v_pact_id, v_milestone_state, v_amount_cents, v_pact_type
  FROM public.milestones m JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;
  IF v_pact_id IS NULL THEN RAISE EXCEPTION 'Hito no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN RAISE EXCEPTION 'Solo el promotor puede decidir'; END IF;
  IF p_decision NOT IN ('approve', 'dispute') THEN RAISE EXCEPTION 'Decisión inválida: %', p_decision; END IF;

  IF v_pact_type = 'obra_menor' AND v_milestone_state = 'ready_for_review' THEN
    UPDATE public.milestones SET state = 'in_validation' WHERE id = p_milestone_id;
    UPDATE public.milestones SET state = 'approved_by_tech', validated_at = now() WHERE id = p_milestone_id;
    UPDATE public.milestones SET state = 'awaiting_promotor' WHERE id = p_milestone_id;
    INSERT INTO public.milestone_validations (milestone_id, validator_user_id, decision, rationale)
    VALUES (p_milestone_id, v_user_id, 'approved'::validation_decision,
      coalesce('[obra menor: validación automática por promotor] ' || p_rationale, '[obra menor: validación automática por promotor]'));
  ELSIF v_milestone_state != 'awaiting_promotor' THEN
    RAISE EXCEPTION 'El hito no está esperando decisión del promotor (estado: %)', v_milestone_state;
  END IF;

  IF p_decision = 'approve' THEN
    -- Fase 1 interconexión (28-oct): el mock escribe el MISMO libro que el
    -- release real (guard de saldo, custodia, deposit_movements, payments).
    v_amount_cents := public._sf_milestone_release_ledger(p_milestone_id, v_user_id, NULL, 'mock');
    v_final_state := 'paid';
  ELSE
    UPDATE public.milestones SET state = 'disputed' WHERE id = p_milestone_id;
    v_final_state := 'disputed';
    INSERT INTO public.milestone_objections (milestone_id, raised_by_user_id, reason_categories, reason_detail)
    VALUES (p_milestone_id, v_user_id, ARRAY['other']::text[],
      coalesce(p_rationale, 'Objeción del promotor'));
    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact_id, 'milestone_disputed',
      jsonb_build_object('milestone_id', p_milestone_id, 'rationale', p_rationale), v_user_id);
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'milestone_promotor_decided', 'milestone', p_milestone_id,
    jsonb_build_object('decision', p_decision, 'final_state', v_final_state::text, 'released_cents',
      CASE WHEN p_decision = 'approve' THEN v_amount_cents END));

  RETURN jsonb_build_object('success', true, 'milestone_state', v_final_state::text);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.sf_milestone_promotor_decide(uuid,text,text) TO authenticated;

COMMENT ON FUNCTION public.sf_milestone_promotor_decide(uuid,text,text) IS
  'El promotor decide approve|dispute. Obra mayor: desde awaiting_promotor. Obra menor: desde ready_for_review (cascada). approve = release MOCK por _sf_milestone_release_ledger (mismo libro que Mangopay, con guard de saldo). Lock FOR UPDATE del hito (M1).';

-- ── Mangopay: sf_milestone_confirm_release ──────────────────────────
create or replace function public.sf_milestone_confirm_release(
  p_milestone_id  uuid,
  p_amount_cents  bigint,
  p_transfer_id   text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pact_id    uuid;
  v_state      milestone_state;
  v_pact_type  pact_type;
  v_promotor   uuid;
  v_net_cents  bigint;
begin
  -- Lock del hito (serializa con el mock y otros releases).
  perform 1 from public.milestones where id = p_milestone_id for update;

  select m.pact_id, m.state, p.pact_type
    into v_pact_id, v_state, v_pact_type
  from public.milestones m
  join public.pacts p on p.id = m.pact_id
  where m.id = p_milestone_id;
  if v_pact_id is null then
    raise exception 'Hito no encontrado: %', p_milestone_id;
  end if;

  -- Idempotencia: si ya está pagado, no repetir.
  if v_state = 'paid' then
    return jsonb_build_object('success', true, 'idempotent', true);
  end if;

  select user_id into v_promotor
    from public.pact_parties where pact_id = v_pact_id and role = 'promotor' limit 1;

  -- Cascada de obra menor (sin técnico): ready_for_review → awaiting_promotor.
  if v_pact_type = 'obra_menor' and v_state = 'ready_for_review' then
    update public.milestones set state = 'in_validation' where id = p_milestone_id;
    update public.milestones set state = 'approved_by_tech', validated_at = now() where id = p_milestone_id;
    update public.milestones set state = 'awaiting_promotor' where id = p_milestone_id;
    insert into public.milestone_validations (milestone_id, validator_user_id, decision, rationale)
    values (p_milestone_id, v_promotor, 'approved'::validation_decision,
      '[obra menor: validación automática por promotor · release Mangopay]');
    v_state := 'awaiting_promotor';
  end if;

  if v_state <> 'awaiting_promotor' then
    raise exception 'El hito no está esperando decisión del promotor (estado: %)', v_state;
  end if;

  v_net_cents := public._sf_milestone_release_ledger(p_milestone_id, v_promotor, p_transfer_id, 'mangopay');

  insert into public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_promotor, 'milestone_confirm_release', 'milestone', p_milestone_id,
    jsonb_build_object('net_cents', v_net_cents, 'transfer_id', p_transfer_id));

  return jsonb_build_object('success', true, 'released_cents', v_net_cents);
end;
$$;

revoke all on function public.sf_milestone_confirm_release(uuid, bigint, text) from public;
revoke all on function public.sf_milestone_confirm_release(uuid, bigint, text) from authenticated;
grant execute on function public.sf_milestone_confirm_release(uuid, bigint, text) to service_role;

notify pgrst, 'reload schema';
