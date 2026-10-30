-- NG-61 · Pruebas de 20261030120000_registro_publico_obra.sql
--
-- Se ejecuta contra una base LOCAL con la línea base y las migraciones
-- aplicadas (nunca contra dev ni prod):
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/registro_publico_obra.test.sql
-- Todo va dentro de una transacción que acaba en ROLLBACK.

begin;

create temp table _resultados (prueba text, ok boolean);

do $$
declare
  v_user   uuid := gen_random_uuid();
  v_pact   uuid := gen_random_uuid();
  v_hito   uuid := gen_random_uuid();
  v_anexo  uuid := gen_random_uuid();
  v_log    public.pact_modification_log%rowtype;
  v_reg    jsonb;
  v_falla  boolean;
begin
  insert into public.users (id, email, full_name, auth_provider_id)
  values (v_user, 'prueba-ng61@example.test', 'Persona De Prueba', 'auth-ng61');

  insert into public.pacts (id, display_id, title, obra_address_line, obra_city, obra_province,
                            total_amount_cents, created_by_user_id, is_demo_only)
  values (v_pact, 'PS-NG61-T', 'Obra de Persona De Prueba (texto interno)', 'Calle Ficticia 1', 'Madrid',
          'Madrid', 38000000, v_user, true);

  insert into public.pact_parties (pact_id, user_id, role) values (v_pact, v_user, 'promotor');

  insert into public.milestones (id, pact_id, display_id, ordinal, name, amount_cents)
  values (v_hito, v_pact, 'H-NG61-1', 1, 'Demoliciones y cubierta', 9500000);

  insert into public.milestone_evidences (milestone_id, uploaded_by_user_id, evidence_type, storage_path,
                                          sha256_hash, gps_latitude, gps_longitude)
  values (v_hito, v_user, 'photo', 'evidencias/privado/foto.jpg', repeat('a', 64), 40.4, -3.7);

  insert into public.milestone_validations (milestone_id, validator_user_id, decision)
  values (v_hito, v_user, 'approved');

  -- Un anexo firmado por promotor y técnico que pasa a activo.
  insert into public.pact_addendums (id, pact_id, display_id, ordinal, title, extra_amount_cents,
                                     extra_days, justification, proposed_by_user_id, proposed_by_role,
                                     detailed_doc_sha256, signed_at_promotor, signed_at_tecnico, state)
  values (v_anexo, v_pact, 'AX-NG61-1', 1, 'Refuerzo de forjado', 1250000, 15,
          'Aparece armadura corroída al levantar la cubierta', v_user, 'tecnico',
          upper(repeat('b', 64)), now(), now(), 'signing');
  update public.pact_addendums set state = 'active' where id = v_anexo;

  select * into v_log from public.pact_modification_log where pact_id = v_pact;
  insert into _resultados values
    ('anexo activo deja una entrada', v_log.id is not null),
    ('importe anterior = total antes del anexo', v_log.importe_anterior_cents = 38000000),
    ('importe posterior = total después', v_log.importe_posterior_cents = 39250000),
    ('motivo = justificación', v_log.motivo = 'Aparece armadura corroída al levantar la cubierta'),
    ('aprobado por los roles que firmaron', v_log.aprobado_por_roles = array['promotor','tecnico']::public.pact_party_role[]),
    ('hash del documento normalizado', v_log.documento_sha256 = repeat('b', 64)),
    ('ordinal 1', v_log.ordinal = 1);

  -- Append-only: UPDATE y DELETE rechazados.
  begin
    update public.pact_modification_log set motivo = 'reescrito' where id = v_log.id;
    v_falla := false;
  exception when restrict_violation then v_falla := true;
  end;
  insert into _resultados values ('UPDATE rechazado', v_falla);

  begin
    delete from public.pact_modification_log where id = v_log.id;
    v_falla := false;
  exception when restrict_violation then v_falla := true;
  end;
  insert into _resultados values ('DELETE rechazado', v_falla);

  begin
    truncate public.pact_modification_log;
    v_falla := false;
  -- Lo frena el disparador o, antes, la FK del motivo público: cualquiera vale.
  exception when others then v_falla := true;
  end;
  insert into _resultados values ('TRUNCATE rechazado', v_falla);

  -- Vista pública: nada si no está publicada.
  insert into public.obras_publicas (pact_id, slug, nombre_publico, organo_contratacion, importe_adjudicacion_cents, es_demo)
  values (v_pact, 'colegio-demo-ng61', 'Rehabilitación de un colegio público', 'Órgano de contratación de ejemplo', 38000000, true);
  insert into _resultados values ('sin publicar → NULL', public.registro_publico_obra('colegio-demo-ng61') is null);

  update public.obras_publicas set publicada = true where pact_id = v_pact;
  v_reg := public.registro_publico_obra('colegio-demo-ng61');
  insert into _resultados values
    ('esquema v0.1', v_reg ->> 'esquema' = 'cimbrium.registro-obra-publica/v0.1'),
    ('motivo NULL hasta redactar el público', v_reg #> '{modificaciones,0,motivo}' = 'null'::jsonb),
    ('la justificación interna no se publica', position('armadura corroída' in v_reg::text) = 0),
    ('el título interno del pacto no se publica', position('texto interno' in v_reg::text) = 0),
    ('base de importes sin IVA', (v_reg #>> '{obra,importes_sin_iva}')::boolean);

  insert into public.pact_modification_motivo_publico (modificacion_id, motivo_publico)
  values (v_log.id, 'Refuerzo del forjado de la planta primera.');
  insert into public.pact_modification_motivo_publico (modificacion_id, motivo_publico)
  values (v_log.id, 'Refuerzo del forjado de la planta primera por corrosión de armaduras.');
  v_reg := public.registro_publico_obra('colegio-demo-ng61');
  insert into _resultados values
    ('vale el último motivo público', v_reg #>> '{modificaciones,0,motivo}' = 'Refuerzo del forjado de la planta primera por corrosión de armaduras.');

  begin
    update public.pact_modification_motivo_publico set motivo_publico = 'x' where modificacion_id = v_log.id;
    v_falla := false;
  exception when restrict_violation then v_falla := true;
  end;
  insert into _resultados values ('motivo público: UPDATE rechazado', v_falla);

  -- Una nueva versión de un hito sustituye a la anterior en la vista pública.
  insert into public.milestones (pact_id, display_id, ordinal, name, amount_cents, previous_version_id)
  values (v_pact, 'H-NG61-1b', 2, 'Demoliciones y cubierta (versión 2)', 9500000, v_hito);
  v_reg := public.registro_publico_obra('colegio-demo-ng61');
  insert into _resultados values
    ('solo la versión vigente del hito', jsonb_array_length(v_reg -> 'hitos') = 1
       and v_reg #>> '{hitos,0,nombre}' = 'Demoliciones y cubierta (versión 2)');
  delete from public.milestones where display_id = 'H-NG61-1b';
  v_reg := public.registro_publico_obra('colegio-demo-ng61');

  -- Anexo con justificación y título en blanco: no bloquea la activación.
  insert into public.pact_addendums (pact_id, display_id, ordinal, title, extra_amount_cents,
                                     justification, proposed_by_user_id, proposed_by_role, state)
  values (v_pact, 'AX-NG61-2', 2, '   ', -100000, '  ', v_user, 'promotor', 'signing');
  update public.pact_addendums set state = 'active' where display_id = 'AX-NG61-2';
  insert into _resultados values
    ('motivo de respaldo si no hay texto', exists (select 1 from public.pact_modification_log
       where pact_id = v_pact and ordinal = 2 and motivo = 'Anexo n.º 2' and aprobado_por_roles = array['promotor']::public.pact_party_role[]));
  v_reg := public.registro_publico_obra('colegio-demo-ng61');
  insert into _resultados values
    ('publicada → devuelve la obra', v_reg #>> '{obra,nombre}' = 'Rehabilitación de un colegio público'),
    ('marca demo', (v_reg #>> '{obra,es_demo}')::boolean),
    ('importe vigente incluye los anexos', (v_reg #>> '{obra,importe_vigente_cents}')::bigint = 39150000),
    ('1 hito con 1 evidencia', jsonb_array_length(v_reg #> '{hitos,0,evidencias}') = 1),
    ('1 certificación', jsonb_array_length(v_reg #> '{hitos,0,certificaciones}') = 1),
    ('2 modificaciones', jsonb_array_length(v_reg -> 'modificaciones') = 2),
    ('sin nombre de persona', position('Persona De Prueba' in v_reg::text) = 0),
    ('sin correo', position('example.test' in v_reg::text) = 0),
    ('sin id de usuario', position(v_user::text in v_reg::text) = 0),
    ('sin ruta de Storage', position('evidencias/privado' in v_reg::text) = 0),
    ('sin coordenadas', position('40.4' in v_reg::text) = 0 and position('gps' in v_reg::text) = 0),
    ('slug inexistente → NULL', public.registro_publico_obra('no-existe') is null);
end;
$$;

-- Permisos: anon solo ejecuta la función; no lee las tablas.
insert into _resultados values
  ('anon ejecuta registro_publico_obra', has_function_privilege('anon', 'public.registro_publico_obra(text)', 'execute')),
  ('anon NO lee obras_publicas', not has_table_privilege('anon', 'public.obras_publicas', 'select')),
  ('anon NO lee pact_modification_log', not has_table_privilege('anon', 'public.pact_modification_log', 'select')),
  ('authenticated NO escribe en obras_publicas', not has_table_privilege('authenticated', 'public.obras_publicas', 'insert,update,delete')),
  ('authenticated NO inserta en el registro', not has_table_privilege('authenticated', 'public.pact_modification_log', 'insert')),
  ('authenticated NO actualiza el registro', not has_table_privilege('authenticated', 'public.pact_modification_log', 'update')),
  ('authenticated NO borra el registro', not has_table_privilege('authenticated', 'public.pact_modification_log', 'delete')),
  ('service_role NO actualiza ni borra el registro', not has_table_privilege('service_role', 'public.pact_modification_log', 'update,delete,truncate')),
  ('anon NO lee el motivo público directamente', not has_table_privilege('anon', 'public.pact_modification_motivo_publico', 'select')),
  ('nadie ejecuta el disparador de anexos', not has_function_privilege('authenticated', 'public.log_addendum_modification()', 'execute'));

select prueba, case when ok then 'OK' else 'FALLA' end as resultado from _resultados;

do $$
declare v_fallos int;
begin
  select count(*) into v_fallos from _resultados where not coalesce(ok, false);
  if v_fallos > 0 then
    raise exception '% prueba(s) fallaron', v_fallos;
  end if;
end;
$$;

rollback;
