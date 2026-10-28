-- LA ÚNICA puerta pública del vertical.
--
-- El rol `anon` no gana acceso a ninguna tabla: solo puede llamar aquí, y aquí
-- se decide exactamente qué sale. Se descartaron un SELECT anónimo con
-- condición de token (un error en la política enseña todo) y leer con clave de
-- servicio (la app no tiene y no debe tener).
--
-- Devuelve NULL para token inexistente, caducado y revocado, sin distinguir:
-- distinguirlos permitiría sondear tokens.

create or replace function fn_cae_vista_cliente(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_enlace  cae_enlaces_cliente%rowtype;
  v_exp     cae_expedientes%rowtype;
  v_reqs    jsonb;
begin
  if p_token is null or length(p_token) < 20 then
    return null;
  end if;

  select * into v_enlace
  from cae_enlaces_cliente
  where token_sha256 = encode(extensions.digest(p_token, 'sha256'), 'hex');

  if not found
     or v_enlace.revocado_at is not null
     or v_enlace.expira_at <= now() then
    return null;
  end if;

  select * into v_exp from cae_expedientes where id = v_enlace.expediente_id;
  if not found then
    return null;
  end if;

  update cae_enlaces_cliente
     set aperturas           = aperturas + 1,
         primera_apertura_at = coalesce(primera_apertura_at, now()),
         ultima_apertura_at  = now()
   where id = v_enlace.id;

  select coalesce(jsonb_agg(jsonb_build_object('clave', r.clave, 'estado', r.estado)
                            order by r.clave), '[]'::jsonb)
    into v_reqs
    from cae_requisitos r
   where r.expediente_id = v_exp.id;

  -- Proyección FIJA. Fuera quedan, a propósito: organization_id, document_id,
  -- nota, actualizado_por, lote_id y pact_id. El cliente ve SU obra, no la
  -- trastienda de la empresa — y en particular no ve con qué otras obras
  -- comparte solicitud, que es información comercial de la empresa.
  return jsonb_build_object(
    'direccion',          v_exp.direccion,
    'comunidad_autonoma', v_exp.comunidad_autonoma,
    'anio_ejecucion',     v_exp.anio_ejecucion,
    'ficha_codigo',       v_exp.ficha_codigo,
    'ficha_version',      v_exp.ficha_version,
    'ahorro_kwh',         v_exp.ahorro_kwh,
    'estado',             v_exp.estado,
    'ayuda_fnee',         v_exp.ayuda_fnee,
    'importe_obra_eur',   v_exp.importe_obra_eur,
    'requisitos',         v_reqs
  );
end;
$$;

revoke all on function fn_cae_vista_cliente(text) from public;
grant execute on function fn_cae_vista_cliente(text) to anon, authenticated;
