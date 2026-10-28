-- 20261028235000_propuestas_presupuesto_costpact.sql
-- Puente D (CostPact → PactStream), auditoría de interconexión 27-oct-2026.
--
-- En v2.1 solo el promotor (o el técnico) crea un pacto; el constructor entra
-- invitado. En CostPact quien pulsa «Crear contrato» es el constructor. Por eso
-- CostPact NO crea el pacto: deja una PROPUESTA dirigida al email del cliente.
-- Cuando el cliente entra en PactStream como promotor con ese email, la ve y la
-- acepta: el pacto se crea a su nombre, con los hitos del presupuesto como plan
-- (no como milestones: no consumen el techo v2.1), el enlace al presupuesto de
-- CostPact (lo que necesita bridge-emit-invoice) y el constructor ya invitado.
-- Funciona aunque el cliente aún no tenga cuenta: la propuesta espera.
--
-- Sustituye a sf_import_budget_as_pact, que creaba el pacto impersonando a un
-- promotor que ya debía existir (sin llamadores).

-- 1. Tabla ─────────────────────────────────────────────────────────────────
create table if not exists public.budget_proposals (
  id                 uuid primary key default gen_random_uuid(),
  partner_id         text not null,
  external_ref       text not null check (length(trim(external_ref)) > 0),
  promotor_email     text not null check (promotor_email = lower(trim(promotor_email)) and promotor_email <> ''),
  promotor_name      text,
  constructor_email  text not null check (constructor_email = lower(trim(constructor_email)) and constructor_email <> ''),
  constructor_name   text not null check (length(trim(constructor_name)) > 0),
  title              text not null check (length(trim(title)) > 0),
  total_amount_cents bigint not null check (total_amount_cents > 0),
  payload            jsonb not null default '{}'::jsonb,
  status             text not null default 'pending'
                     check (status in ('pending', 'accepted', 'declined')),
  pact_id            uuid references public.pacts(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  decided_at         timestamptz,
  check (promotor_email <> constructor_email)
);

-- Una propuesta por presupuesto y socio: reenviar actualiza la misma.
create unique index if not exists budget_proposals_ref_uk
  on public.budget_proposals (partner_id, external_ref);
create index if not exists budget_proposals_promotor_idx
  on public.budget_proposals (promotor_email) where status = 'pending';

comment on table public.budget_proposals is
  'Presupuestos de CostPact enviados al cliente. El cliente (promotor) los acepta y entonces se crea el pacto a su nombre.';
comment on column public.budget_proposals.payload is
  'Datos de la obra (obra_*, description, iva_rate_pct, advance_pct) y milestones (plan) tal como los envió CostPact.';

alter table public.budget_proposals enable row level security;

-- El destinatario ve sus propuestas. Nadie escribe directamente: solo las RPC.
drop policy if exists "budget_proposals: destinatario" on public.budget_proposals;
create policy "budget_proposals: destinatario" on public.budget_proposals
  for select to authenticated
  using (promotor_email = (
    select lower(u.email::text) from public.users u
     where u.auth_provider_id = auth.uid()::text and u.deleted_at is null));

revoke all on public.budget_proposals from anon, authenticated;
grant select on public.budget_proposals to authenticated;
grant all on public.budget_proposals to service_role;

-- 2. Recibir la propuesta (servidor a servidor, api-key con scope import:budget)
create or replace function public.sf_propose_budget(p_api_key text, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key_id   uuid;
  v_partner  text;
  v_scopes   text[];
  v_ref      text := nullif(trim(p_payload ->> 'costpact_presupuesto_id'), '');
  v_promotor text := lower(nullif(trim(p_payload ->> 'promotor_email'), ''));
  v_constr   text := lower(nullif(trim(p_payload ->> 'constructor_email'), ''));
  v_cname    text := nullif(trim(p_payload ->> 'constructor_name'), '');
  v_title    text := coalesce(nullif(trim(p_payload ->> 'title'), ''), 'Obra de CostPact');
  v_total    bigint := (p_payload ->> 'total_amount_cents')::bigint;
  v_row      public.budget_proposals%rowtype;
begin
  select id, partner_id, scopes into v_key_id, v_partner, v_scopes
    from public.api_keys
   where key_hash = encode(extensions.digest(p_api_key, 'sha256'), 'hex')
     and active and revoked_at is null;
  if v_key_id is null then
    raise exception 'api-key inválida o revocada' using errcode = '28000';
  end if;
  if not ('import:budget' = any (v_scopes)) then
    raise exception 'la api-key no tiene el scope import:budget' using errcode = '42501';
  end if;

  if v_ref is null then raise exception 'Falta costpact_presupuesto_id' using errcode = '22023'; end if;
  if v_promotor is null then raise exception 'El cliente no tiene email' using errcode = '22023'; end if;
  if v_constr is null or v_cname is null then
    raise exception 'Faltan los datos del constructor' using errcode = '22023';
  end if;
  if v_promotor = v_constr then
    raise exception 'El cliente y el constructor no pueden ser la misma persona' using errcode = '22023';
  end if;
  -- Mismo mínimo que sf_create_pact_v21: mejor fallar aquí que al aceptar.
  if v_total is null or v_total < 50000 then
    raise exception 'El presupuesto mínimo de un pacto es 500 €' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_payload -> 'milestones', '[]'::jsonb)) <> 'array' then
    raise exception 'milestones debe ser una lista' using errcode = '22023';
  end if;

  select * into v_row from public.budget_proposals
   where partner_id = v_partner and external_ref = v_ref;

  if v_row.id is not null and v_row.status = 'accepted' then
    -- Ya hay pacto: no se crea otro ni se cambian sus datos desde fuera.
    null;
  elsif v_row.id is not null then
    -- Pendiente o rechazada: reenviar la actualiza y la vuelve a dejar pendiente.
    update public.budget_proposals
       set promotor_email = v_promotor,
           promotor_name = nullif(trim(p_payload ->> 'promotor_name'), ''),
           constructor_email = v_constr,
           constructor_name = v_cname,
           title = v_title,
           total_amount_cents = v_total,
           payload = p_payload - 'promotor_email' - 'constructor_email',
           status = 'pending',
           decided_at = null,
           updated_at = now()
     where id = v_row.id
    returning * into v_row;
  else
    insert into public.budget_proposals
      (partner_id, external_ref, promotor_email, promotor_name, constructor_email,
       constructor_name, title, total_amount_cents, payload)
    values
      (v_partner, v_ref, v_promotor, nullif(trim(p_payload ->> 'promotor_name'), ''), v_constr,
       v_cname, v_title, v_total, p_payload - 'promotor_email' - 'constructor_email')
    returning * into v_row;
  end if;

  insert into public.api_key_usage (api_key_id, partner_id, endpoint)
  values (v_key_id, v_partner, 'sf_propose_budget');

  return jsonb_build_object(
    'ok', true,
    'proposal_id', v_row.id,
    'status', v_row.status,
    'pact_id', v_row.pact_id,
    'promotor_has_account', exists (
      select 1 from public.users u
       where lower(u.email::text) = v_promotor and u.deleted_at is null));
end;
$$;

revoke all on function public.sf_propose_budget(text, jsonb) from public, anon, authenticated;
grant execute on function public.sf_propose_budget(text, jsonb) to service_role;

-- 3. Aceptar: el promotor crea el pacto ─────────────────────────────────────
create or replace function public.sf_accept_budget_proposal(p_proposal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user     public.users%rowtype;
  v_prop     public.budget_proposals%rowtype;
  v_p        jsonb;
  v_advance  numeric;
  v_pact_id  uuid;
  v_display  text;
  v_items    int;
begin
  select * into v_user from public.users
   where auth_provider_id = auth.uid()::text and deleted_at is null;
  if v_user.id is null then
    raise exception 'Usuario no autenticado' using errcode = '28000';
  end if;

  select * into v_prop from public.budget_proposals where id = p_proposal_id for update;
  if v_prop.id is null or v_prop.promotor_email <> lower(v_user.email::text) then
    raise exception 'Propuesta no encontrada' using errcode = 'P0002';
  end if;
  if v_prop.status <> 'pending' then
    raise exception 'Esta propuesta ya no está pendiente' using errcode = '55000';
  end if;
  if v_user.primary_role::text <> 'promotor' then
    raise exception 'Solo un promotor puede aceptar un presupuesto' using errcode = '42501';
  end if;

  v_p := v_prop.payload;
  -- El adelanto v2.1 va de 10 a 40 %. Si el de CostPact queda fuera, se usa el
  -- valor por defecto: el pacto queda en borrador y el promotor lo revisa.
  v_advance := (v_p ->> 'advance_pct')::numeric;
  if v_advance is null or v_advance < 10 or v_advance > 40 then
    v_advance := 30;
  end if;

  select out_pact_id, out_display_id into v_pact_id, v_display
    from public.sf_create_pact_v21(
      p_title              => v_prop.title,
      p_obra_address_line  => coalesce(nullif(trim(v_p ->> 'obra_address_line'), ''), 'Sin dirección'),
      p_total_amount_cents => v_prop.total_amount_cents,
      p_description        => v_p ->> 'description',
      p_obra_city          => v_p ->> 'obra_city',
      p_obra_province      => v_p ->> 'obra_province',
      p_obra_postal_code   => v_p ->> 'obra_postal_code',
      p_obra_type          => coalesce(v_p ->> 'obra_type', 'reforma_integral'),
      p_iva_rate_pct       => coalesce((v_p ->> 'iva_rate_pct')::numeric, 21),
      p_advance_pct        => v_advance,
      p_obra_menor_declaration_accepted => true);

  v_items := public.sf_write_pact_plan(v_pact_id, v_p -> 'milestones');

  insert into public.pact_metadata (pact_id, key, value) values
    (v_pact_id, 'source', 'costpact'),
    (v_pact_id, 'costpact_presupuesto_id', v_prop.external_ref),
    (v_pact_id, 'partner_id', v_prop.partner_id),
    (v_pact_id, 'budget_proposal_id', v_prop.id::text)
  on conflict (pact_id, key) do update set value = excluded.value;

  perform public.sf_invite_party(v_pact_id, 'constructor', v_prop.constructor_email, v_prop.constructor_name);

  update public.budget_proposals
     set status = 'accepted', pact_id = v_pact_id, decided_at = now(), updated_at = now()
   where id = v_prop.id;

  return jsonb_build_object('pact_id', v_pact_id, 'display_id', v_display, 'plan_items', v_items);
end;
$$;

-- 4. Rechazar ───────────────────────────────────────────────────────────────
create or replace function public.sf_decline_budget_proposal(p_proposal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.budget_proposals p
     set status = 'declined', decided_at = now(), updated_at = now()
   where p.id = p_proposal_id
     and p.status = 'pending'
     and p.promotor_email = (
       select lower(u.email::text) from public.users u
        where u.auth_provider_id = auth.uid()::text and u.deleted_at is null);
  if not found then
    raise exception 'Propuesta no encontrada o ya decidida' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.sf_accept_budget_proposal(uuid) from public, anon;
revoke all on function public.sf_decline_budget_proposal(uuid) from public, anon;
grant execute on function public.sf_accept_budget_proposal(uuid) to authenticated, service_role;
grant execute on function public.sf_decline_budget_proposal(uuid) to authenticated, service_role;

-- 5. Retirar la importación anterior (creaba el pacto impersonando al promotor)
drop function if exists public.sf_import_budget_as_pact(text, jsonb);

notify pgrst, 'reload schema';
