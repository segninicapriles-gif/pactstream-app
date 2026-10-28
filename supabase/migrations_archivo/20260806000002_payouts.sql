-- 20260806000002_payouts.sql
-- Fase 2.3 Mangopay: cash-out a banco (PayOut). Un payout es a nivel de WALLET
-- del constructor (no de un pacto), por eso tabla propia y no `payments`.
-- La escribe SOLO el backend (service_role: mangopay-payout la inserta, el
-- webhook la actualiza). El constructor solo LEE sus payouts.
--
-- Aditiva: crea tabla + una columna; no altera nada existente.

alter table public.users
  add column if not exists mangopay_bank_account_id text;

create table if not exists public.payouts (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.users(id),  -- constructor
  mangopay_payout_id       text unique,
  mangopay_bank_account_id text,
  amount_cents             bigint not null,
  state                    text not null default 'pending', -- pending|succeeded|failed
  created_at               timestamptz not null default now(),
  succeeded_at             timestamptz,
  failed_at                timestamptz,
  failure_reason           text
);

create index if not exists idx_payouts_user on public.payouts(user_id, created_at desc);
create index if not exists idx_payouts_state on public.payouts(state);

alter table public.payouts enable row level security;

-- El constructor LEE sus propios payouts.
drop policy if exists "payouts_select_own" on public.payouts;
create policy "payouts_select_own"
  on public.payouts for select
  to authenticated
  using (
    exists (
      select 1 from public.users u
      where u.id = payouts.user_id
        and u.auth_provider_id = auth.uid()::text
    )
  );

-- Sin policies de escritura para authenticated: RLS las bloquea; el backend
-- (service_role) inserta/actualiza y bypassa RLS.
