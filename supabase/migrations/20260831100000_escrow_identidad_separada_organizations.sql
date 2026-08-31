-- Identidad de escrow separada por rol — organizations
-- ============================================================================
-- Simétrica de 20260831090000 (que lo hizo para users), con dos diferencias
-- que conviene no pasar por alto.
--
-- POR QUÉ APLICA IGUAL
-- pact_parties tiene organization_id ADEMÁS de user_id, y el `role` va en la
-- misma fila. O sea: una organización puede ser parte de un pacto con un rol,
-- exactamente igual que una persona, y por tanto puede ser constructor en un
-- pacto y promotor en otro. Con una sola columna (organizations.mangopay_user_id,
-- declarada como «LegalUser»), la segunda identidad pisaría a la primera.
--
-- EN QUÉ SE DIFERENCIA DE users — LEER ANTES DE COPIAR
--
--  1. NO se toca ningún trigger anti-escalada, y es a propósito. users tiene
--     enforce_users_privileged_columns porque su RLS permite al propio usuario
--     hacer UPDATE de su fila. organizations NO: su RLS tiene una única política,
--     `org_select_member`, de SOLO LECTURA. Sin política de UPDATE, un cliente
--     authenticated no puede escribir en la tabla, así que no hay vector que
--     cerrar. Añadir un trigger aquí sería ruido copiado sin entender.
--     ⚠️ Si algún día se añade una política de UPDATE sobre organizations, ESTAS
--     DOS COLUMNAS TIENEN QUE PASAR A ESTAR PROTEGIDAS. Es el mismo agujero que
--     en users: quien pueda escribirlas apunta el cobro a donde quiera.
--
--  2. NO hay código que actualizar. Ninguna Edge Function lee ni escribe
--     organizations.mangopay_user_id (verificado por grep sobre supabase/functions
--     el 31-ago-2026). La columna está hoy muerta: 2 organizaciones, ninguna con
--     id, y 0 de las 44 filas de pact_parties usan organization_id.
--     Esto es preventivo: se hace ahora porque cuesta cero y porque el día que
--     una organización cobre de verdad ya no será gratis.
--
-- ⚠️ organizations.org_type es el análogo exacto de users.primary_role: un tipo
--    DECLARADO en la ficha (hoy 'constructor' en Tomato), no el rol ejercido. Vale
--    como vía rápida, nunca como autorización — la autoridad es pact_parties.role
--    de esa organización. Es el mismo error que dio un 403 permanente a un usuario
--    real en el PR #5. Ver la nota de memoria rol-por-pacto-no-por-perfil.
-- ============================================================================

-- ── 1 · Columnas nuevas ─────────────────────────────────────────────────────
alter table public.organizations
  add column if not exists escrow_owner_id text,
  add column if not exists escrow_payer_id text;

comment on column public.organizations.escrow_owner_id is
  'Cuenta conectada del proveedor de escrow con la que la organización COBRA (acct_… en Stripe).';
comment on column public.organizations.escrow_payer_id is
  'Identidad del proveedor de escrow con la que la organización PAGA (cus_… en Stripe).';
comment on column public.organizations.mangopay_user_id is
  'DEPRECADA: sustituida por escrow_owner_id / escrow_payer_id (migración 20260831100000). Nunca la escribió ningún flujo.';

-- ── 2 · Backfill por prefijo (hoy no-op: ninguna organización tiene id) ─────
update public.organizations
   set escrow_owner_id = mangopay_user_id
 where mangopay_user_id like 'acct\_%' and escrow_owner_id is null;

update public.organizations
   set escrow_payer_id = mangopay_user_id
 where mangopay_user_id like 'cus\_%' and escrow_payer_id is null;

-- ── 3 · Unicidad ────────────────────────────────────────────────────────────
create unique index if not exists organizations_escrow_owner_id_key
  on public.organizations (escrow_owner_id) where escrow_owner_id is not null;
create unique index if not exists organizations_escrow_payer_id_key
  on public.organizations (escrow_payer_id) where escrow_payer_id is not null;

-- ── 4 · CHECK de prefijo ────────────────────────────────────────────────────
-- Igual que en users: se admite id numérico por el proveedor legacy Mangopay,
-- cuyos LegalUser son numéricos. Lo que importa se mantiene: un cus_ no entra en
-- la columna de cobro ni un acct_ en la de pago.
alter table public.organizations drop constraint if exists organizations_escrow_owner_id_prefijo;
alter table public.organizations
  add constraint organizations_escrow_owner_id_prefijo
  check (
    escrow_owner_id is null
    or escrow_owner_id ~ '^acct_'
    or escrow_owner_id ~ '^[0-9]+$'
  );

alter table public.organizations drop constraint if exists organizations_escrow_payer_id_prefijo;
alter table public.organizations
  add constraint organizations_escrow_payer_id_prefijo
  check (
    escrow_payer_id is null
    or escrow_payer_id ~ '^cus_'
    or escrow_payer_id ~ '^[0-9]+$'
  );
