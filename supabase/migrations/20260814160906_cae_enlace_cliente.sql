-- El cliente tiene que poder ver su obra sin cuenta, y para eso hace falta un
-- enlace que se pueda dar, caducar y revocar. El token EN CLARO no se guarda:
-- se guarda su SHA-256, igual que `api_keys` de PactStream.

alter table cae_expedientes
  add column importe_obra_eur numeric;

comment on column cae_expedientes.importe_obra_eur is
  'Importe de la obra en euros. Sirve para decirle al cliente CUÁNTO pierde de '
  'deducción, no solo que la pierde. Anulable: un expediente puede nacer antes '
  'de que haya oferta cerrada, y el aviso cualitativo funciona igual sin él.';

create table cae_enlaces_cliente (
  id                   uuid primary key default gen_random_uuid(),
  expediente_id        uuid not null references cae_expedientes(id) on delete cascade,
  token_sha256         text not null unique,
  creado_por           uuid references users(id),
  created_at           timestamptz not null default now(),
  expira_at            timestamptz not null,
  revocado_at          timestamptz,
  aperturas            integer not null default 0,
  primera_apertura_at  timestamptz,
  ultima_apertura_at   timestamptz
);

create index cae_enlaces_cliente_expediente_idx
  on cae_enlaces_cliente (expediente_id);

comment on table cae_enlaces_cliente is
  'Enlaces con los que el propietario ve su obra sin tener cuenta. Registrar la '
  'apertura no es telemetría: es la prueba de que la empresa informó al cliente '
  'y cuándo, y le sirve a ella el día que haya discusión.';

alter table cae_enlaces_cliente enable row level security;

-- Mismo predicado que `cae_exp_todo_miembro`, a través del expediente.
-- El rol `anon` NO tiene ninguna política aquí: entra por la función de la
-- tarea 2 y por ningún otro sitio.
create policy cae_enlaces_todo_miembro on cae_enlaces_cliente
  for all to authenticated
  using (exists (
    select 1 from cae_expedientes e
    where e.id = cae_enlaces_cliente.expediente_id
      and fn_is_org_active_member(e.organization_id)
  ))
  with check (exists (
    select 1 from cae_expedientes e
    where e.id = cae_enlaces_cliente.expediente_id
      and fn_is_org_active_member(e.organization_id)
  ));
