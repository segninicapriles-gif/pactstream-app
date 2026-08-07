-- 20260806000001_sf_milestone_confirm_release.sql
-- Fase 2.2 Mangopay: libera el neto de un hito TRAS un Transfer real
-- (escrow → constructor). Lo invoca SOLO mangopay-release (service_role), y solo
-- si el Transfer devolvió SUCCEEDED.
--
-- Replica el camino 'approve' de sf_milestone_promotor_decide (incl. la cascada
-- de obra menor) y ACTIVA el decremento de custodia C3 que allí está documentado
-- pero comentado — con el enum correcto ('milestone_release', no
-- 'release_for_cert') y el guard de saldo. Idempotente. Deja intacto el mock
-- sf_milestone_promotor_decide (sigue siendo el default con ESCROW_PROVIDER=mock).
--
-- Aditiva: no altera tablas ni funciones existentes.

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
  v_pact_id        uuid;
  v_state          milestone_state;
  v_pact_type      pact_type;
  v_net_cents      bigint;
  v_deposit_cents  bigint;
  v_promotor       uuid;
  v_constructor    uuid;
begin
  -- Lock del hito (serializa con el mock y otros releases).
  perform 1 from public.milestones where id = p_milestone_id for update;

  select m.pact_id, m.state, coalesce(m.net_amount_cents, m.amount_cents), p.pact_type
    into v_pact_id, v_state, v_net_cents, v_pact_type
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
  select user_id into v_constructor
    from public.pact_parties where pact_id = v_pact_id and role = 'constructor' limit 1;

  -- Cascada de obra menor (sin técnico): ready_for_review → awaiting_promotor.
  -- Réplica de sf_milestone_promotor_decide.
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

  -- ── C3: guard de saldo + decremento de custodia (ahora SÍ cableado) ──
  select deposit_current_cents into v_deposit_cents
    from public.pacts where id = v_pact_id for update;
  if v_deposit_cents < v_net_cents then
    raise exception 'Saldo en custodia insuficiente para liberar el hito (custodia: % / neto: %)',
      v_deposit_cents, v_net_cents;
  end if;

  update public.pacts
     set deposit_current_cents = deposit_current_cents - v_net_cents
   where id = v_pact_id;

  insert into public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    related_milestone_id, balance_before_cents, balance_after_cents,
    mangopay_transaction_id, notes
  ) values (
    v_pact_id, 'milestone_release', -v_net_cents, v_promotor,
    p_milestone_id, v_deposit_cents, v_deposit_cents - v_net_cents,
    p_transfer_id, 'Release de hito confirmado por Mangopay (transfer ' || p_transfer_id || ')'
  );

  -- Hito 'paid' (dispara los triggers AFTER UPDATE: progreso de obra + póliza).
  update public.milestones
     set state = 'paid', approved_by_promotor_at = now(), paid_at = now()
   where id = p_milestone_id;

  -- Registro en payments (idempotencia del release + trazabilidad Mangopay).
  insert into public.payments (
    pact_id, milestone_id, payment_type, amount_cents, state,
    destination_user_id, mangopay_transaction_id, idempotency_key, succeeded_at
  ) values (
    v_pact_id, p_milestone_id, 'milestone_release', v_net_cents, 'succeeded',
    v_constructor, p_transfer_id, 'release:' || p_milestone_id, now()
  );

  insert into public.pact_events (pact_id, event_type, payload, actor_user_id)
  values (v_pact_id, 'milestone_paid',
    jsonb_build_object('milestone_id', p_milestone_id, 'amount_cents', v_net_cents,
      'transfer_id', p_transfer_id, 'via', 'mangopay'),
    v_promotor);

  insert into public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_promotor, 'milestone_confirm_release', 'milestone', p_milestone_id,
    jsonb_build_object('net_cents', v_net_cents, 'transfer_id', p_transfer_id));

  return jsonb_build_object('success', true, 'released_cents', v_net_cents);
end;
$$;

revoke all on function public.sf_milestone_confirm_release(uuid, bigint, text) from public;
revoke all on function public.sf_milestone_confirm_release(uuid, bigint, text) from authenticated;
grant execute on function public.sf_milestone_confirm_release(uuid, bigint, text) to service_role;
