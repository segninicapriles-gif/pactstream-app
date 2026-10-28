-- 20261029020000_nif_clave_natural.sql
-- Identidad común (auditoría de interconexión, Fase 3). Decisión vigente
-- (7-ago-2026): «SSO ligero» — la persona se identifica por email/Google en
-- cada app; NO hay proveedor de identidad común. La EMPRESA se identifica por su
-- NIF, la misma clave en las tres apps:
--   1. sf_normalizar_nif: mayúsculas, sin espacios, puntos ni guiones (igual
--      que CostPact en clientes y empresas).
--   2. organizations.cif se guarda normalizado (ya era único).
--   3. Las propuestas de CostPact traen el NIF de la empresa constructora y, al
--      aceptarse, la parte constructora se liga a su organización por NIF.

create or replace function public.sf_normalizar_nif(p text)
returns text
language sql
immutable
as $$ select nullif(upper(regexp_replace(coalesce(p, ''), '[\s.-]', '', 'g')), '') $$;

create or replace function public.sf_organizations_normaliza_cif()
returns trigger
language plpgsql
as $$
begin
  new.cif := public.sf_normalizar_nif(new.cif);
  return new;
end;
$$;

drop trigger if exists organizations_normaliza_cif on public.organizations;
create trigger organizations_normaliza_cif
  before insert or update of cif on public.organizations
  for each row execute function public.sf_organizations_normaliza_cif();

alter table public.budget_proposals add column if not exists constructor_nif text;

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
  v_cnif     text := public.sf_normalizar_nif(p_payload ->> 'constructor_nif');
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
           constructor_nif = v_cnif,
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
       constructor_name, constructor_nif, title, total_amount_cents, payload)
    values
      (v_partner, v_ref, v_promotor, nullif(trim(p_payload ->> 'promotor_name'), ''), v_constr,
       v_cname, v_cnif, v_title, v_total, p_payload - 'promotor_email' - 'constructor_email')
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
  v_org      uuid;
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

  -- NIF como clave natural: si la empresa constructora ya tiene organización en
  -- PactStream, la parte queda ligada a ella (su equipo ve la obra). Solo si la
  -- persona invitada aún no tiene cuenta o ya es miembro de esa organización:
  -- nunca se cuelga a alguien de una organización que no es la suya.
  if v_prop.constructor_nif is not null then
    select o.id into v_org from public.organizations o
     where o.cif = v_prop.constructor_nif;
    if v_org is not null and (
         not exists (select 1 from public.users u
                      where lower(u.email::text) = v_prop.constructor_email and u.deleted_at is null)
         or exists (select 1 from public.users u
                     join public.organization_members om on om.user_id = u.id
                    where lower(u.email::text) = v_prop.constructor_email
                      and om.organization_id = v_org and om.state = 'active')) then
      update public.pact_parties set organization_id = v_org
       where pact_id = v_pact_id and role = 'constructor';
    end if;
  end if;

  update public.budget_proposals
     set status = 'accepted', pact_id = v_pact_id, decided_at = now(), updated_at = now()
   where id = v_prop.id;

  return jsonb_build_object('pact_id', v_pact_id, 'display_id', v_display, 'plan_items', v_items);
end;
$$;

notify pgrst, 'reload schema';
