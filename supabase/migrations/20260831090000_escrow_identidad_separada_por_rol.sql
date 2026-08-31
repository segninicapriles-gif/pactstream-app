-- Identidad de escrow separada por rol funcional
-- ============================================================================
-- PROBLEMA
-- users.mangopay_user_id era UNA columna para lo que el dominio permite que
-- sean DOS identidades distintas. El rol en PactStream no es global: lo asigna
-- pact_parties.role POR PACTO, así que una misma persona puede ser constructor
-- en un pacto y promotor en otro. Esa persona necesita a la vez:
--   · una cuenta conectada (acct_… en Stripe) para COBRAR liberaciones, y
--   · un customer (cus_… en Stripe) para FONDEAR el pay-in que ella misma paga.
-- Con una sola columna, la segunda identidad pisaba a la primera y el flujo
-- perdedor quedaba roto de forma permanente (escrow-onboard es idempotente:
-- ve la columna poblada, devuelve already:true y no la sobrescribe nunca).
--
-- SOLUCIÓN
-- Dos columnas con un único significado cada una. Así el CHECK de prefijo pasa
-- a ser correcto: ata el prefijo a la COLUMNA (significado único), no al rol de
-- la persona (que puede ser varios a la vez).
--
-- mangopay_user_id se CONSERVA como vestigio deprecado: no se borra en esta
-- migración para no romper nada que aún la lea. Ya no la escribe ningún flujo.
--
-- Verificado antes de escribir: los 11 usuarios de pactstream-dev tienen
-- mangopay_user_id a NULL, así que el backfill de abajo no mueve ninguna fila.
-- ============================================================================

-- ── 1 · Columnas nuevas ─────────────────────────────────────────────────────
alter table public.users
  add column if not exists escrow_owner_id text,
  add column if not exists escrow_payer_id text;

comment on column public.users.escrow_owner_id is
  'Cuenta conectada del proveedor de escrow con la que el usuario COBRA (acct_… en Stripe). La escribe escrow-onboard-link / escrow-onboard(OWNER).';
comment on column public.users.escrow_payer_id is
  'Identidad del proveedor de escrow con la que el usuario PAGA (cus_… en Stripe). La escribe escrow-onboard(PAYER).';
comment on column public.users.mangopay_user_id is
  'DEPRECADA: sustituida por escrow_owner_id / escrow_payer_id (migración 20260831090000). Ya no la escribe ningún flujo.';

-- ── 2 · Backfill desde la columna antigua, por prefijo ──────────────────────
-- Hoy es un no-op (todo NULL). Se deja por si esta migración se aplica a un
-- entorno donde sí hubiera datos.
update public.users
   set escrow_owner_id = mangopay_user_id
 where mangopay_user_id like 'acct\_%' and escrow_owner_id is null;

update public.users
   set escrow_payer_id = mangopay_user_id
 where mangopay_user_id like 'cus\_%' and escrow_payer_id is null;

-- ── 3 · Unicidad (dos personas no pueden compartir cuenta del proveedor) ────
-- Índices parciales: el UNIQUE de columna trataría los NULL como distintos
-- igualmente, pero el índice parcial deja claro el ámbito y es más barato.
create unique index if not exists users_escrow_owner_id_key
  on public.users (escrow_owner_id) where escrow_owner_id is not null;
create unique index if not exists users_escrow_payer_id_key
  on public.users (escrow_payer_id) where escrow_payer_id is not null;

-- ── 4 · CHECK de prefijo ────────────────────────────────────────────────────
-- Se admiten también ids totalmente numéricos: son los de Mangopay, proveedor
-- legacy hoy inerte. Sin esa rama, un despliegue con ESCROW_PROVIDER=mangopay
-- reventaría al escribir. La protección que importa se mantiene: un cus_ no
-- puede entrar en la columna de cobro ni un acct_ en la de pago.
alter table public.users drop constraint if exists users_escrow_owner_id_prefijo;
alter table public.users
  add constraint users_escrow_owner_id_prefijo
  check (
    escrow_owner_id is null
    or escrow_owner_id ~ '^acct_'
    or escrow_owner_id ~ '^[0-9]+$'
  );

alter table public.users drop constraint if exists users_escrow_payer_id_prefijo;
alter table public.users
  add constraint users_escrow_payer_id_prefijo
  check (
    escrow_payer_id is null
    or escrow_payer_id ~ '^cus_'
    or escrow_payer_id ~ '^[0-9]+$'
  );

-- ── 5 · Trigger anti-escalada: proteger también las columnas nuevas ─────────
-- CRÍTICO. Sin esto, las columnas nuevas quedarían fuera de la lista de
-- privilegiadas y un cliente autenticado podría escribírselas vía PostgREST,
-- es decir, apuntar su cobro a la cuenta que quisiera. Se replica la función de
-- 20260713000001 añadiendo escrow_owner_id y escrow_payer_id.
create or replace function public.enforce_users_privileged_columns()
returns trigger
language plpgsql
as $$
BEGIN
  -- Solo aplica a clientes directos (PostgREST con SET ROLE authenticated/anon).
  -- Las RPC SECURITY DEFINER corren como owner (current_user = postgres) y
  -- el service_role (current_user = service_role) quedan exentos: pueden
  -- modificar KYC, rol, organización, etc. de forma legítima.
  IF current_user IN ('authenticated', 'anon') THEN
    IF NEW.kyc_status      IS DISTINCT FROM OLD.kyc_status
       OR NEW.kyc_verified_at IS DISTINCT FROM OLD.kyc_verified_at
       OR NEW.primary_role    IS DISTINCT FROM OLD.primary_role
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.mangopay_user_id IS DISTINCT FROM OLD.mangopay_user_id
       OR NEW.escrow_owner_id IS DISTINCT FROM OLD.escrow_owner_id
       OR NEW.escrow_payer_id IS DISTINCT FROM OLD.escrow_payer_id
       OR NEW.national_id     IS DISTINCT FROM OLD.national_id
       OR NEW.auth_provider_id IS DISTINCT FROM OLD.auth_provider_id
       OR NEW.email           IS DISTINCT FROM OLD.email
    THEN
      RAISE EXCEPTION
        'No autorizado: no puedes modificar columnas privilegiadas de tu perfil (kyc_status, kyc_verified_at, primary_role, organization_id, mangopay_user_id, escrow_owner_id, escrow_payer_id, national_id, auth_provider_id, email). Usa el flujo de servidor correspondiente.'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
