-- 20261029010000_enlace_hito_certificacion_costpact.sql
-- Enlace hito ↔ certificación de CostPact (28-oct-2026).
-- Regla: factura CostPact y la factura nace de la certificación. En un pacto que
-- viene de un presupuesto de CostPact, el constructor indica qué certificación de
-- CostPact corresponde a cada hito; al aprobarse el hito, bridge-emit-invoice
-- pide a CostPact la factura DE ESA certificación (una por certificación; si ya
-- se emitió desde CostPact, devuelve la misma) y guarda aquí su número.
-- Sin enlace no se factura nada desde PactStream.

alter table public.milestones
  add column if not exists costpact_certificacion_id uuid,
  add column if not exists costpact_cert_numero integer;

comment on column public.milestones.costpact_certificacion_id is
  'Certificación de CostPact (otro proyecto Supabase: sin FK) que factura este hito.';

-- Una certificación de CostPact no puede facturar dos hitos del mismo pacto.
create unique index if not exists milestones_costpact_cert_uk
  on public.milestones (pact_id, costpact_certificacion_id)
  where costpact_certificacion_id is not null;

create or replace function public.sf_link_costpact_cert(
  p_milestone_id uuid, p_cert_id uuid, p_numero integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_m public.milestones%rowtype;
begin
  select * into v_m from public.milestones where id = p_milestone_id;
  if v_m.id is null then
    raise exception 'Certificación no encontrada' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.pact_parties pp join public.users u on u.id = pp.user_id
     where pp.pact_id = v_m.pact_id and pp.role = 'constructor'
       and u.auth_provider_id = auth.uid()::text and u.deleted_at is null) then
    raise exception 'Solo el constructor enlaza la certificación de CostPact' using errcode = '42501';
  end if;
  if not exists (select 1 from public.pact_metadata
                  where pact_id = v_m.pact_id and key = 'costpact_presupuesto_id'
                    and nullif(trim(value), '') is not null) then
    raise exception 'Este pacto no viene de un presupuesto de CostPact' using errcode = '55000';
  end if;
  -- Con la factura ya emitida, cambiar el enlace la dejaría huérfana.
  if nullif(trim(v_m.invoice_number), '') is not null then
    raise exception 'La certificación ya tiene factura: no se puede cambiar el enlace' using errcode = '55000';
  end if;

  update public.milestones
     set costpact_certificacion_id = p_cert_id,
         costpact_cert_numero = case when p_cert_id is null then null else p_numero end
   where id = p_milestone_id;

  insert into public.pact_events (pact_id, event_type, payload, actor_user_id)
  values (v_m.pact_id, 'costpact_cert_linked',
          jsonb_build_object('cert_id', p_milestone_id, 'costpact_certificacion_id', p_cert_id,
                             'numero', p_numero),
          public.current_user_id());
end;
$$;

revoke all on function public.sf_link_costpact_cert(uuid, uuid, integer) from public, anon;
grant execute on function public.sf_link_costpact_cert(uuid, uuid, integer) to authenticated, service_role;

CREATE OR REPLACE FUNCTION "public"."sf_get_milestone_detail"("p_milestone_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid; v_pact_id uuid;
  v_my_role text; v_via_org boolean; v_can_view_econ boolean;
  v_result jsonb;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT m.pact_id INTO v_pact_id
  FROM public.milestones m WHERE m.id = p_milestone_id;
  IF v_pact_id IS NULL THEN RAISE EXCEPTION 'Hito no encontrado'; END IF;

  IF NOT public.fn_user_can_act_on_pact(v_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No tienes acceso a este hito';
  END IF;

  -- Mi rol directo si lo tengo
  SELECT role::text INTO v_my_role
  FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;

  v_via_org := (v_my_role IS NULL);

  -- Si vengo via org, inferir rol según rol de la org
  IF v_via_org THEN
    SELECT pp.role::text INTO v_my_role
    FROM public.pact_parties pp
    JOIN public.organizations o ON o.owner_user_id = pp.user_id
      AND o.deleted_at IS NULL
    JOIN public.organization_members om ON om.organization_id = o.id
    WHERE pp.pact_id = v_pact_id
      AND om.user_id = v_user_id
      AND om.state = 'active'
    LIMIT 1;
  END IF;

  v_can_view_econ := public.fn_user_can_view_economics_on_pact(v_pact_id, v_user_id);

  SELECT jsonb_build_object(
    'milestone', jsonb_build_object(
      'id', m.id,
      'pact_id', m.pact_id,
      'pact_display_id', p.display_id,
      'pact_title', p.title,
      'pact_type', p.pact_type::text,
      'display_id', m.display_id,
      'ordinal', m.ordinal,
      'name', m.name,
      'description', m.description,
      -- Económicos sensibles
      'amount_cents', CASE WHEN v_can_view_econ THEN m.amount_cents ELSE NULL END,
      'target_date', m.target_date,
      'state', m.state::text,
      'state_updated_at', m.state_updated_at,
      'started_at', m.started_at,
      'submitted_at', m.submitted_at,
      'validated_at', m.validated_at,
      'approved_by_promotor_at', m.approved_by_promotor_at,
      'rejected_at', m.rejected_at,
      'paid_at', m.paid_at,
      -- Factura de la certificación (CostPact o sistema externo del constructor)
      'invoice_number', m.invoice_number,
      'invoice_storage_path', m.invoice_storage_path,
      -- Enlace con la certificación de CostPact que factura este hito
      'costpact_linked', EXISTS (SELECT 1 FROM public.pact_metadata pm
                                  WHERE pm.pact_id = m.pact_id AND pm.key = 'costpact_presupuesto_id'
                                    AND nullif(trim(pm.value), '') IS NOT NULL),
      'costpact_certificacion_id', m.costpact_certificacion_id,
      'costpact_cert_numero', m.costpact_cert_numero,
      'my_role', v_my_role,
      'is_member_via_org', v_via_org,
      'can_view_economics', v_can_view_econ,
      -- P1-4 · última validación registrada (rationale del técnico o
      -- del promotor). NULL si aún no hay validaciones.
      'last_validation_decision', lv.decision,
      'last_validation_rationale', lv.rationale,
      'last_validation_at', lv.decision_at,
      'last_validation_by_name', lv.validator_name
    ),
    'evidences', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', e.id,
        'evidence_type', e.evidence_type::text,
        'storage_path', e.storage_path,
        'file_size_bytes', e.file_size_bytes,
        'mime_type', e.mime_type,
        'description', e.description,
        'gps_latitude', e.gps_latitude,
        'gps_longitude', e.gps_longitude,
        'gps_accuracy_meters', e.gps_accuracy_meters,
        'client_timestamp', e.client_timestamp,
        'server_timestamp', e.server_timestamp,
        'sha256_hash', e.sha256_hash,
        'is_superseded', e.is_superseded,
        'uploaded_by_user_id', e.uploaded_by_user_id,
        'uploaded_by_name', uploader.full_name,
        'uploaded_by_email', uploader.email,
        -- Info de organización del uploader (si pertenece a una)
        'uploader_via_org_name', uploader_org.legal_name,
        'uploader_via_org_role',
          CASE
            WHEN uploader_om.role::text = 'owner' THEN 'owner'
            WHEN uploader_om.role::text = 'member' THEN 'member'
            ELSE NULL
          END,
        'is_mine', (e.uploaded_by_user_id = v_user_id)
      ) ORDER BY e.server_timestamp DESC)
      FROM public.milestone_evidences e
      LEFT JOIN public.users uploader ON uploader.id = e.uploaded_by_user_id
      -- Buscar si el uploader pertenece a una organización
      LEFT JOIN public.organization_members uploader_om
        ON uploader_om.user_id = uploader.id
        AND uploader_om.state = 'active'
      LEFT JOIN public.organizations uploader_org
        ON uploader_org.id = uploader_om.organization_id
        AND uploader_org.deleted_at IS NULL
      WHERE e.milestone_id = p_milestone_id
        AND NOT e.is_superseded
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  LEFT JOIN LATERAL (
    SELECT
      v.decision::text  AS decision,
      v.rationale       AS rationale,
      v.decision_at     AS decision_at,
      vu.full_name      AS validator_name
    FROM public.milestone_validations v
    LEFT JOIN public.users vu ON vu.id = v.validator_user_id
    WHERE v.milestone_id = m.id
    ORDER BY v.decision_at DESC
    LIMIT 1
  ) lv ON true
  WHERE m.id = p_milestone_id;

  RETURN v_result;
END;
$$;

