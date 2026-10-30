-- NG-61 · Obra pública verificable (piloto P3).
--
-- Migración ADITIVA: no toca ninguna tabla ni función existente; solo añade
-- tres piezas nuevas y un disparador sobre pact_addendums.
--
-- 1. pact_modification_log: registro de modificaciones de un pacto. APPEND-ONLY
--    de verdad: un disparador rechaza UPDATE, DELETE y TRUNCATE. pact_addendums
--    no sirve como registro porque es una tabla de flujo (su fila cambia de
--    estado al firmarse) y no guarda el importe anterior y el posterior.
-- 2. Cada anexo que pasa a 'active' deja su entrada en el registro, con el
--    importe antes y después tal como lo calculó handle_addendum_active().
-- 3. obras_publicas + registro_publico_obra(slug): la ficha que se publica y la
--    única vía de lectura sin sesión. Devuelve SOLO datos de la obra: ni
--    nombres, ni correos, ni ids de usuario, ni coordenadas del dispositivo,
--    ni rutas de Storage.
--
-- NO se ha aplicado en ningún entorno. Revisar con /revisar-migracion.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Registro de modificaciones (append-only)
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists public.pact_modification_log (
  id                         uuid primary key default gen_random_uuid(),
  pact_id                    uuid not null references public.pacts(id) on delete restrict,
  ordinal                    integer not null check (ordinal >= 1),
  motivo                     text not null check (length(btrim(motivo)) > 0),
  importe_anterior_cents     bigint not null,
  importe_posterior_cents    bigint not null,
  plazo_dias_delta           integer not null default 0,
  fecha_efecto               timestamptz not null default now(),
  -- Quién aprueba se publica como ROL (parte del pacto), nunca como persona.
  aprobado_por_roles         public.pact_party_role[] not null,
  -- Interno: no sale en la vista pública.
  registrado_por_user_id     uuid,
  documento_storage_path     text,
  documento_sha256           text check (documento_sha256 is null or documento_sha256 ~ '^[0-9a-f]{64}$'),
  addendum_id                uuid unique references public.pact_addendums(id) on delete restrict,
  created_at                 timestamptz not null default now(),
  constraint pact_modification_log_ordinal_por_pacto unique (pact_id, ordinal),
  constraint pact_modification_log_aprobado_no_vacio check (cardinality(aprobado_por_roles) > 0)
);

comment on table public.pact_modification_log is
  'Registro de modificaciones de un pacto (NG-61). APPEND-ONLY: UPDATE, DELETE y TRUNCATE los rechaza un disparador. Una corrección es una entrada nueva.';

create index if not exists idx_pact_modification_log_pact on public.pact_modification_log (pact_id, ordinal);

create or replace function public.pact_modification_log_inmutable()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'pact_modification_log es append-only: % no está permitido. Registra una entrada nueva.', tg_op
    using errcode = 'restrict_violation';
end;
$$;

revoke all on function public.pact_modification_log_inmutable() from public, anon, authenticated;

drop trigger if exists trg_pact_modification_log_no_update on public.pact_modification_log;
create trigger trg_pact_modification_log_no_update
  before update or delete on public.pact_modification_log
  for each row execute function public.pact_modification_log_inmutable();

drop trigger if exists trg_pact_modification_log_no_truncate on public.pact_modification_log;
create trigger trg_pact_modification_log_no_truncate
  before truncate on public.pact_modification_log
  for each statement execute function public.pact_modification_log_inmutable();

alter table public.pact_modification_log enable row level security;

-- Las partes del pacto leen su registro. Nadie escribe por la Data API: las
-- entradas nacen del disparador de anexos (SECURITY DEFINER) o del service_role.
drop policy if exists pact_modification_log_select_party on public.pact_modification_log;
create policy pact_modification_log_select_party on public.pact_modification_log
  for select to authenticated
  using (exists (
    select 1
      from public.pact_parties pp
      join public.users u on u.id = pp.user_id
     where pp.pact_id = pact_modification_log.pact_id
       and u.auth_provider_id = (auth.uid())::text
       and u.deleted_at is null));

-- Los privilegios por defecto de postgres en public todavía dan arwd a anon y
-- authenticated: se retiran ANTES de conceder lo justo (las pruebas lo vigilan).
-- Sin UPDATE ni DELETE para nadie, y sin INSERT para authenticated.
revoke all on public.pact_modification_log from public, anon, authenticated;
grant select on public.pact_modification_log to authenticated;
grant select, insert on public.pact_modification_log to service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. Cada anexo activado deja su entrada
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.log_addendum_modification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_total_nuevo bigint;
  v_roles       public.pact_party_role[] := '{}';
  v_ordinal     integer;
begin
  -- Serializa por pacto para que dos activaciones simultáneas no choquen en el
  -- ordinal. AFTER: handle_addendum_active() (BEFORE) ya actualizó el total.
  select total_amount_cents into v_total_nuevo
    from public.pacts where id = new.pact_id for update;

  if new.signed_at_promotor    is not null then v_roles := v_roles || 'promotor'::public.pact_party_role;    end if;
  if new.signed_at_constructor is not null then v_roles := v_roles || 'constructor'::public.pact_party_role; end if;
  if new.signed_at_tecnico     is not null then v_roles := v_roles || 'tecnico'::public.pact_party_role;     end if;
  if cardinality(v_roles) = 0 then
    v_roles := array[new.proposed_by_role];
  end if;

  select coalesce(max(ordinal), 0) + 1 into v_ordinal
    from public.pact_modification_log where pact_id = new.pact_id;

  insert into public.pact_modification_log (
    pact_id, ordinal, motivo,
    importe_anterior_cents, importe_posterior_cents, plazo_dias_delta,
    fecha_efecto, aprobado_por_roles, registrado_por_user_id,
    documento_storage_path, documento_sha256, addendum_id)
  values (
    new.pact_id, v_ordinal,
    coalesce(nullif(btrim(new.justification), ''), new.title),
    v_total_nuevo - new.extra_amount_cents, v_total_nuevo, new.extra_days,
    coalesce(new.finalized_at, now()), v_roles, new.proposed_by_user_id,
    new.detailed_doc_storage_path,
    -- Un hash con otro formato no debe bloquear la activación del anexo.
    case when lower(new.detailed_doc_sha256) ~ '^[0-9a-f]{64}$' then lower(new.detailed_doc_sha256) end,
    new.id)
  on conflict (addendum_id) do nothing;

  return new;
end;
$$;

revoke all on function public.log_addendum_modification() from public, anon, authenticated;

drop trigger if exists trg_addendum_active_log_modification on public.pact_addendums;
create trigger trg_addendum_active_log_modification
  after update of state on public.pact_addendums
  for each row
  when (new.state = 'active'::public.addendum_state and old.state is distinct from 'active'::public.addendum_state)
  execute function public.log_addendum_modification();

-- ─────────────────────────────────────────────────────────────────────────
-- 3. Ficha publicada y lectura pública
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists public.obras_publicas (
  id                          uuid primary key default gen_random_uuid(),
  pact_id                     uuid not null unique references public.pacts(id) on delete restrict,
  slug                        text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  organo_contratacion         text not null,
  expediente                  text,
  importe_adjudicacion_cents  bigint not null check (importe_adjudicacion_cents >= 0),
  publicada                   boolean not null default false,
  es_demo                     boolean not null default false,
  publicada_at                timestamptz,
  created_at                  timestamptz not null default now()
);

comment on table public.obras_publicas is
  'Ficha de una obra pública con vista ciudadana (NG-61). Solo se lee sin sesión a través de registro_publico_obra(slug), y solo si publicada = true.';

alter table public.obras_publicas enable row level security;

drop policy if exists obras_publicas_select_party on public.obras_publicas;
create policy obras_publicas_select_party on public.obras_publicas
  for select to authenticated
  using (exists (
    select 1
      from public.pact_parties pp
      join public.users u on u.id = pp.user_id
     where pp.pact_id = obras_publicas.pact_id
       and u.auth_provider_id = (auth.uid())::text
       and u.deleted_at is null));

-- Publicar es una decisión de administración: solo service_role escribe.
revoke all on public.obras_publicas from public, anon, authenticated;
grant select on public.obras_publicas to authenticated;
grant select, insert, update on public.obras_publicas to service_role;

create or replace function public.registro_publico_obra(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'esquema', 'cimbrium.registro-obra-publica/v1',
    'generado_at', now(),
    'obra', jsonb_build_object(
      'slug', op.slug,
      'nombre', p.title,
      'municipio', p.obra_city,
      'provincia', p.obra_province,
      'organo_contratacion', op.organo_contratacion,
      'expediente', op.expediente,
      'importe_adjudicacion_cents', op.importe_adjudicacion_cents,
      'importe_vigente_cents', p.total_amount_cents,
      'es_demo', op.es_demo or p.is_demo_only),
    'hitos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ordinal', m.ordinal,
        'nombre', m.name,
        'importe_cents', m.amount_cents,
        'estado', m.state,
        'fecha_prevista', m.target_date,
        'evidencias', coalesce((
          select jsonb_agg(jsonb_build_object(
            'tipo', e.evidence_type,
            'sha256', e.sha256_hash,
            'sellada_at', e.server_timestamp)
            order by e.server_timestamp)
          from public.milestone_evidences e
          where e.milestone_id = m.id and not e.is_superseded), '[]'::jsonb),
        'certificaciones', coalesce((
          select jsonb_agg(jsonb_build_object(
            'decision', v.decision,
            'fecha', v.decision_at,
            'numero_certificacion', m.costpact_cert_numero)
            order by v.decision_at)
          from public.milestone_validations v
          where v.milestone_id = m.id), '[]'::jsonb))
        order by m.ordinal)
      from public.milestones m
      where m.pact_id = p.id and m.previous_version_id is null), '[]'::jsonb),
    'modificaciones', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ordinal', l.ordinal,
        'motivo', l.motivo,
        'importe_anterior_cents', l.importe_anterior_cents,
        'importe_posterior_cents', l.importe_posterior_cents,
        'plazo_dias_delta', l.plazo_dias_delta,
        'fecha', l.fecha_efecto,
        'aprobado_por', l.aprobado_por_roles,
        'documento_sha256', l.documento_sha256)
        order by l.ordinal)
      from public.pact_modification_log l
      where l.pact_id = p.id), '[]'::jsonb))
  from public.obras_publicas op
  join public.pacts p on p.id = op.pact_id
  where op.slug = p_slug and op.publicada;
$$;

comment on function public.registro_publico_obra(text) is
  'Vista ciudadana de una obra publicada (NG-61). Sin datos personales: ni nombres, ni ids de usuario, ni coordenadas, ni rutas de Storage. NULL si no existe o no está publicada.';

revoke all on function public.registro_publico_obra(text) from public;
grant execute on function public.registro_publico_obra(text) to anon, authenticated, service_role;
