-- 20260806000000_sf_pact_confirm_payin.sql
-- Fase 2.1 Mangopay: confirma un PAY-IN REAL (Bankwire) y actualiza el ledger
-- de custodia. Lo invoca SOLO el webhook (service_role) tras verificar contra
-- la API de Mangopay que el ingreso está SUCCEEDED.
--
-- Replica la lógica de ledger de sf_pact_fund_initial (mock), pero:
--   · disparado por un ingreso real (no por el promotor pulsando un botón),
--   · idempotente (si el pacto ya tiene initial_deposit, no repite),
--   · deja intacto sf_pact_fund_initial (el mock sigue como default).
--
-- Aditiva: NO altera tablas ni funciones existentes. Aplicar con `supabase db
-- push` y anotar en el historial de migraciones.

create or replace function public.sf_pact_confirm_payin(
  p_pact_id       uuid,
  p_amount_cents  bigint,
  p_payin_id      text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pact             public.pacts%rowtype;
  v_promotor_user_id uuid;
  v_already          integer;
begin
  select * into v_pact from public.pacts where id = p_pact_id;
  if v_pact.id is null then
    raise exception 'Pacto no encontrado: %', p_pact_id;
  end if;

  -- Idempotencia: si ya existe el depósito inicial de este pacto, no repetir.
  select count(*) into v_already
  from public.deposit_movements
  where pact_id = p_pact_id and movement_type = 'initial_deposit';
  if v_already > 0 then
    return jsonb_build_object('success', true, 'idempotent', true);
  end if;

  -- Solo fondea si el pacto sigue en 'signed' (aún no fondeado).
  if v_pact.state <> 'signed' then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', 'estado no signed');
  end if;

  select user_id into v_promotor_user_id
  from public.pact_parties
  where pact_id = p_pact_id and role = 'promotor'
  limit 1;

  -- Transiciones state machine: signed → funded → in_execution
  update public.pacts
     set state = 'funded', deposit_current_cents = p_amount_cents
   where id = p_pact_id;
  update public.pacts
     set state = 'in_execution'
   where id = p_pact_id;

  -- Movimiento de depósito (con trazabilidad Mangopay)
  insert into public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    balance_before_cents, balance_after_cents, mangopay_transaction_id, notes
  ) values (
    p_pact_id, 'initial_deposit', p_amount_cents, v_promotor_user_id,
    0, p_amount_cents, p_payin_id,
    'Depósito inicial confirmado por Mangopay (pay-in ' || p_payin_id || ')'
  );

  insert into public.pact_events (pact_id, event_type, payload, actor_user_id)
  values (p_pact_id, 'pact_funded',
    jsonb_build_object('deposit_cents', p_amount_cents, 'payin_id', p_payin_id, 'via', 'mangopay'),
    v_promotor_user_id);

  insert into public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_promotor_user_id, 'pact_confirm_payin', 'pact', p_pact_id,
    jsonb_build_object('deposit_cents', p_amount_cents, 'payin_id', p_payin_id));

  return jsonb_build_object('success', true, 'deposit_cents', p_amount_cents);
end;
$$;

-- SOLO el webhook (service_role) confirma un ingreso real. Nunca authenticated.
revoke all on function public.sf_pact_confirm_payin(uuid, bigint, text) from public;
revoke all on function public.sf_pact_confirm_payin(uuid, bigint, text) from authenticated;
grant execute on function public.sf_pact_confirm_payin(uuid, bigint, text) to service_role;
