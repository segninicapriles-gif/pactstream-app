-- =====================================================================
-- LÍNEA BASE · esquema de PactStream dev (erqglsrnknhwqhfupckf) a 28-oct-2026
-- =====================================================================
-- Sustituye a las 96 migraciones anteriores (archivadas, sin tocar, en
-- supabase/migrations_archivo/). Motivo (auditoría de interconexión 27-oct,
-- punto d): aquellos ficheros NO reproducían dev —
--   * organizations definida dos veces (legal_name/cif vs name/vat_id); las
--     columnas owner_user_id, org_type y description solo existían en dev;
--   * 21 funciones cambiadas a mano en dev o sin fichero;
--   * migraciones aplicadas fuera de orden (seed antes que el esquema que usa,
--     GRANT antes que sus tablas) y dos seeds de demo que chocaban entre sí.
--
-- Contenido:
--   1. `supabase db dump --linked` del esquema (public y private, con RLS y
--      GRANT), tal cual.
--   2. Lo que vive fuera de public: trigger de alta en auth.users, buckets y
--      políticas de Storage, tarea pg_cron.
--   3. Datos de CONFIGURACIÓN (no demo): app_settings, ai_prompts,
--      ai_fixtures, ipc_indices. Los datos de demo NO van aquí.
--
-- En dev esta migración se marca como aplicada con `supabase migration
-- repair` (no se ejecuta). En una base nueva deja el mismo esquema que dev.
-- =====================================================================




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE SCHEMA IF NOT EXISTS "private";


ALTER SCHEMA "private" OWNER TO "postgres";




ALTER SCHEMA "public" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'Schema público de PactStream. Permisos: service_role bypassa RLS, authenticated filtrado por RLS.';



CREATE EXTENSION IF NOT EXISTS "citext" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."addendum_state" AS ENUM (
    'proposed',
    'signing',
    'active',
    'cancelled'
);


ALTER TYPE "public"."addendum_state" OWNER TO "postgres";


CREATE TYPE "public"."ai_fixture_type" AS ENUM (
    'vision',
    'assistant_intent',
    'assistant_fallback'
);


ALTER TYPE "public"."ai_fixture_type" OWNER TO "postgres";


CREATE TYPE "public"."ai_verdict" AS ENUM (
    'ok',
    'review_needed',
    'block'
);


ALTER TYPE "public"."ai_verdict" OWNER TO "postgres";


CREATE DOMAIN "public"."cae_comunidad" AS "text"
	CONSTRAINT "cae_comunidad_check" CHECK ((VALUE = ANY (ARRAY['Andalucía'::"text", 'Aragón'::"text", 'Asturias'::"text", 'Illes Balears'::"text", 'Canarias'::"text", 'Cantabria'::"text", 'Castilla-La Mancha'::"text", 'Castilla y León'::"text", 'Cataluña'::"text", 'Comunitat Valenciana'::"text", 'Extremadura'::"text", 'Galicia'::"text", 'La Rioja'::"text", 'Madrid'::"text", 'Murcia'::"text", 'Navarra'::"text", 'País Vasco'::"text", 'Ceuta'::"text", 'Melilla'::"text"])));


ALTER DOMAIN "public"."cae_comunidad" OWNER TO "postgres";


CREATE TYPE "public"."cae_estado_expediente" AS ENUM (
    'borrador',
    'en_ejecucion',
    'documentado',
    'en_lote',
    'entregado'
);


ALTER TYPE "public"."cae_estado_expediente" OWNER TO "postgres";


CREATE TYPE "public"."cae_estado_lote" AS ENUM (
    'abierto',
    'listo',
    'entregado'
);


ALTER TYPE "public"."cae_estado_lote" OWNER TO "postgres";


CREATE TYPE "public"."cae_estado_requisito" AS ENUM (
    'pendiente',
    'aportado',
    'verificado',
    'rechazado'
);


ALTER TYPE "public"."cae_estado_requisito" OWNER TO "postgres";


CREATE TYPE "public"."deposit_movement_type" AS ENUM (
    'initial_deposit',
    'replenishment',
    'automatic_execution',
    'addendum_replenishment',
    'refund',
    'reserve_deposit',
    'predeposit_for_cert',
    'surety_claim_payout',
    'final_reserve_release',
    'milestone_release'
);


ALTER TYPE "public"."deposit_movement_type" OWNER TO "postgres";


COMMENT ON TYPE "public"."deposit_movement_type" IS 'Movimientos del depósito de garantía. Entradas: initial_deposit, replenishment, addendum_replenishment. Salidas: milestone_release (ordinaria, al aprobar un hito), automatic_execution (forzosa por impago) y refund (devolución al promotor). El signo va en amount_cents: positivo entrada, negativo salida.';



CREATE TYPE "public"."dispute_outcome" AS ENUM (
    'release_full',
    'release_partial',
    'refund_full',
    'redo_milestone',
    'pending'
);


ALTER TYPE "public"."dispute_outcome" OWNER TO "postgres";


CREATE TYPE "public"."dispute_state" AS ENUM (
    'opened',
    'in_review',
    'proposal_sent',
    'resolved',
    'withdrawn',
    'escalated_to_arbitration'
);


ALTER TYPE "public"."dispute_state" OWNER TO "postgres";


CREATE TYPE "public"."document_type" AS ENUM (
    'master_contract',
    'milestone_certificate',
    'final_acta',
    'invoice',
    'budget',
    'deposit_receipt',
    'dispute_resolution',
    'libro_edificio_extract',
    'kyc_record',
    'attachment'
);


ALTER TYPE "public"."document_type" OWNER TO "postgres";


CREATE TYPE "public"."evidence_type" AS ENUM (
    'photo',
    'video',
    'audio',
    'document',
    'note'
);


ALTER TYPE "public"."evidence_type" OWNER TO "postgres";


CREATE TYPE "public"."evidence_verification" AS ENUM (
    'verified',
    'gps_outside_radius',
    'metadata_anomaly',
    'manual_override',
    'pending'
);


ALTER TYPE "public"."evidence_verification" OWNER TO "postgres";


CREATE TYPE "public"."kyc_status" AS ENUM (
    'not_started',
    'in_progress',
    'pending_review',
    'verified',
    'rejected',
    'expired'
);


ALTER TYPE "public"."kyc_status" OWNER TO "postgres";


CREATE TYPE "public"."legal_doc_type" AS ENUM (
    'terms_of_service',
    'privacy_policy',
    'escrow_terms',
    'cookies_policy',
    'biometric_consent'
);


ALTER TYPE "public"."legal_doc_type" OWNER TO "postgres";


CREATE TYPE "public"."milestone_state" AS ENUM (
    'pending',
    'in_execution',
    'ready_for_review',
    'in_validation',
    'info_requested',
    'approved_by_tech',
    'rejected_by_tech',
    'awaiting_promotor',
    'paid',
    'disputed',
    'pending_predeposit',
    'paused_no_predeposit'
);


ALTER TYPE "public"."milestone_state" OWNER TO "postgres";


CREATE TYPE "public"."notification_channel" AS ENUM (
    'push',
    'email',
    'sms',
    'in_app'
);


ALTER TYPE "public"."notification_channel" OWNER TO "postgres";


CREATE TYPE "public"."notification_priority" AS ENUM (
    'low',
    'normal',
    'high',
    'critical'
);


ALTER TYPE "public"."notification_priority" OWNER TO "postgres";


CREATE TYPE "public"."org_member_role" AS ENUM (
    'owner',
    'member'
);


ALTER TYPE "public"."org_member_role" OWNER TO "postgres";


CREATE TYPE "public"."org_member_state" AS ENUM (
    'invited',
    'active',
    'revoked'
);


ALTER TYPE "public"."org_member_state" OWNER TO "postgres";


CREATE TYPE "public"."org_type" AS ENUM (
    'constructor',
    'tecnico',
    'promotor',
    'mixed'
);


ALTER TYPE "public"."org_type" OWNER TO "postgres";


CREATE TYPE "public"."pact_party_role" AS ENUM (
    'promotor',
    'constructor',
    'tecnico'
);


ALTER TYPE "public"."pact_party_role" OWNER TO "postgres";


CREATE TYPE "public"."pact_state" AS ENUM (
    'draft',
    'inviting',
    'signing',
    'signed',
    'funded',
    'in_execution',
    'disputed',
    'suspended',
    'completed',
    'closed',
    'cancelled',
    'paused_pending_tech'
);


ALTER TYPE "public"."pact_state" OWNER TO "postgres";


CREATE TYPE "public"."pact_type" AS ENUM (
    'obra_mayor',
    'obra_menor'
);


ALTER TYPE "public"."pact_type" OWNER TO "postgres";


CREATE TYPE "public"."payment_state" AS ENUM (
    'created',
    'pending',
    'succeeded',
    'failed',
    'cancelled'
);


ALTER TYPE "public"."payment_state" OWNER TO "postgres";


CREATE TYPE "public"."payment_type" AS ENUM (
    'pay_in',
    'milestone_release',
    'partial_refund',
    'full_refund',
    'platform_fee',
    'reversal'
);


ALTER TYPE "public"."payment_type" OWNER TO "postgres";


CREATE TYPE "public"."signature_state" AS ENUM (
    'requested',
    'sent',
    'partially_signed',
    'signed',
    'expired',
    'cancelled'
);


ALTER TYPE "public"."signature_state" OWNER TO "postgres";


CREATE TYPE "public"."surety_policy_status" AS ENUM (
    'draft',
    'active',
    'claimed',
    'released',
    'cancelled'
);


ALTER TYPE "public"."surety_policy_status" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'promotor',
    'constructor',
    'tecnico',
    'admin'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."validation_decision" AS ENUM (
    'approved',
    'rejected',
    'info_requested'
);


ALTER TYPE "public"."validation_decision" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."score_to_tier"("p_score" smallint) RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_score >= 90 THEN 'elite'
    WHEN p_score >= 75 THEN 'platino'
    WHEN p_score >= 60 THEN 'oro'
    WHEN p_score >= 40 THEN 'plata'
    ELSE 'bronce'
  END;
$$;


ALTER FUNCTION "private"."score_to_tier"("p_score" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_enqueue_notification"("p_user_id" "uuid", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_channel" "public"."notification_channel", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_key" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.notifications (
    user_id, pact_id, milestone_id, notification_type,
    channel, priority, title, body, cta_url, idempotency_key
  ) VALUES (
    p_user_id, p_pact_id, p_milestone_id, p_type,
    p_channel,
    CASE
      WHEN p_type IN ('milestone_paid', 'milestone_disputed', 'pact_completed')
        THEN 'high'::notification_priority
      ELSE 'normal'::notification_priority
    END,
    p_title, p_body, p_cta_url, p_idempotency_key
  )
  ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."_enqueue_notification"("p_user_id" "uuid", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_channel" "public"."notification_channel", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_notify_users"("p_user_ids" "uuid"[], "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_prefix" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_uid uuid;
BEGIN
  FOREACH v_uid IN ARRAY p_user_ids LOOP
    PERFORM public._enqueue_notification(
      v_uid, p_pact_id, p_milestone_id, p_type,
      'email'::notification_channel,
      p_title, p_body, p_cta_url,
      p_idempotency_prefix || ':email:' || v_uid::text
    );
    PERFORM public._enqueue_notification(
      v_uid, p_pact_id, p_milestone_id, p_type,
      'in_app'::notification_channel,
      p_title, p_body, p_cta_url,
      p_idempotency_prefix || ':in_app:' || v_uid::text
    );
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."_notify_users"("p_user_ids" "uuid"[], "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_prefix" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_sf_milestone_release_ledger"("p_milestone_id" "uuid", "p_actor" "uuid", "p_transfer_id" "text", "p_via" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_pact_id       uuid;
  v_net_cents     bigint;
  v_deposit_cents bigint;
  v_constructor   uuid;
begin
  if p_via not in ('mock', 'mangopay') then
    raise exception 'Vía de release inválida: %', p_via;
  end if;

  select m.pact_id, coalesce(m.net_amount_cents, m.amount_cents)
    into v_pact_id, v_net_cents
  from public.milestones m where m.id = p_milestone_id;
  if v_pact_id is null then
    raise exception 'Hito no encontrado: %', p_milestone_id;
  end if;

  select user_id into v_constructor
    from public.pact_parties where pact_id = v_pact_id and role = 'constructor' limit 1;

  -- Guard de saldo (C3) con lock del pacto.
  select deposit_current_cents into v_deposit_cents
    from public.pacts where id = v_pact_id for update;
  if v_deposit_cents < v_net_cents then
    raise exception 'Saldo en custodia insuficiente para liberar el hito (custodia: % € / neto: % €)',
      translate(to_char(v_deposit_cents / 100.0, 'FM999,999,990.00'), ',.', '.,'),
      translate(to_char(v_net_cents / 100.0, 'FM999,999,990.00'), ',.', '.,');
  end if;

  update public.pacts
     set deposit_current_cents = deposit_current_cents - v_net_cents
   where id = v_pact_id;

  insert into public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    related_milestone_id, balance_before_cents, balance_after_cents,
    mangopay_transaction_id, notes
  ) values (
    v_pact_id, 'milestone_release', -v_net_cents, p_actor,
    p_milestone_id, v_deposit_cents, v_deposit_cents - v_net_cents,
    p_transfer_id,
    case when p_via = 'mangopay'
      then 'Release de hito confirmado por Mangopay (transfer ' || p_transfer_id || ')'
      else 'Release de hito (MOCK · sin movimiento real de fondos)' end
  );

  -- Hito 'paid' (dispara los triggers AFTER UPDATE: progreso de obra + póliza).
  update public.milestones
     set state = 'paid', approved_by_promotor_at = now(), paid_at = now()
   where id = p_milestone_id;

  insert into public.payments (
    pact_id, milestone_id, payment_type, amount_cents, state,
    destination_user_id, mangopay_transaction_id, idempotency_key, succeeded_at
  ) values (
    v_pact_id, p_milestone_id, 'milestone_release', v_net_cents, 'succeeded',
    v_constructor, p_transfer_id, 'release:' || p_milestone_id, now()
  );

  insert into public.pact_events (pact_id, event_type, payload, actor_user_id)
  values (v_pact_id, 'milestone_paid',
    jsonb_strip_nulls(jsonb_build_object('milestone_id', p_milestone_id, 'amount_cents', v_net_cents,
      'transfer_id', p_transfer_id, 'via', p_via,
      'note', case when p_via = 'mock' then 'MOCK release · Mangopay pendiente' end)),
    p_actor);

  return v_net_cents;
end;
$$;


ALTER FUNCTION "public"."_sf_milestone_release_ledger"("p_milestone_id" "uuid", "p_actor" "uuid", "p_transfer_id" "text", "p_via" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."_sf_milestone_release_ledger"("p_milestone_id" "uuid", "p_actor" "uuid", "p_transfer_id" "text", "p_via" "text") IS 'Interna. Libro único de liberación de un hito (guard de saldo, custodia, deposit_movements, paid, payments, evento). La llaman sf_milestone_promotor_decide (mock) y sf_milestone_confirm_release (Mangopay). El llamador valida estado y bloquea el hito.';



CREATE OR REPLACE FUNCTION "public"."check_kyc_verified"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_kyc_status text;
BEGIN
  SELECT kyc_status INTO v_kyc_status
  FROM users WHERE id = p_user_id;

  IF v_kyc_status IS NULL OR v_kyc_status != 'verified' THEN
    RAISE EXCEPTION 'KYC verification required. Current status: %', COALESCE(v_kyc_status, 'unknown');
  END IF;
END;
$$;


ALTER FUNCTION "public"."check_kyc_verified"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT u.id
  FROM public.users u
  WHERE u.auth_provider_id = (current_setting('request.jwt.claims', true)::json->>'sub')
    AND u.deleted_at IS NULL
  LIMIT 1
$$;


ALTER FUNCTION "public"."current_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_users_privileged_columns"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
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


ALTER FUNCTION "public"."enforce_users_privileged_columns"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."enforce_users_privileged_columns"() IS 'Auditoría 2026-07-13 C1: bloquea que un cliente directo (authenticated/anon) modifique columnas privilegiadas de public.users. RPC SECURITY DEFINER y service_role exentos.';



CREATE OR REPLACE FUNCTION "public"."fn_block_ai_verification_mutations"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'milestone_ai_verifications es append-only (DELETE bloqueado)';
  END IF;

  -- UPDATE solo permitido en campos de revisión humana
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.milestone_id IS DISTINCT FROM OLD.milestone_id
     OR NEW.pact_id IS DISTINCT FROM OLD.pact_id
     OR NEW.provider IS DISTINCT FROM OLD.provider
     OR NEW.model IS DISTINCT FROM OLD.model
     OR NEW.prompt_version IS DISTINCT FROM OLD.prompt_version
     OR NEW.input_hash_sha256 IS DISTINCT FROM OLD.input_hash_sha256
     OR NEW.evidences_count IS DISTINCT FROM OLD.evidences_count
     OR NEW.documents_count IS DISTINCT FROM OLD.documents_count
     OR NEW.score IS DISTINCT FROM OLD.score
     OR NEW.verdict IS DISTINCT FROM OLD.verdict
     OR NEW.summary IS DISTINCT FROM OLD.summary
     OR NEW.findings IS DISTINCT FROM OLD.findings
     OR NEW.checklist_match IS DISTINCT FROM OLD.checklist_match
     OR NEW.recommendation IS DISTINCT FROM OLD.recommendation
     OR NEW.input_tokens IS DISTINCT FROM OLD.input_tokens
     OR NEW.output_tokens IS DISTINCT FROM OLD.output_tokens
     OR NEW.cache_read_tokens IS DISTINCT FROM OLD.cache_read_tokens
     OR NEW.cost_cents IS DISTINCT FROM OLD.cost_cents
     OR NEW.duration_ms IS DISTINCT FROM OLD.duration_ms
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'milestone_ai_verifications · solo reviewed_by_user_id, reviewed_at y justifications son mutables';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_block_ai_verification_mutations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_cae_clave_certificado_previo"() RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$ SELECT 'certificado_energetico_previo'::text $$;


ALTER FUNCTION "public"."fn_cae_clave_certificado_previo"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_cae_clave_certificado_previo"() IS 'Clave del requisito que abre la puerta para salir de borrador. DEBE coincidir con CLAVE_CERTIFICADO_PREVIO de src/lib/cae/requisitos.ts en pactstream-cae. Si divergen, la puerta deja de bloquear y no avisa.';



CREATE OR REPLACE FUNCTION "public"."fn_cae_documento_exige_fichero"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_org  uuid;
  v_ruta text;
BEGIN
  v_org := public.fn_cae_org_de_ruta(NEW.storage_path);
  IF v_org IS NULL THEN
    RETURN NEW;   -- no es un documento CAE: no es asunto de este disparador
  END IF;

  -- `documents` guarda la ruta con el cubo delante; `storage.objects` sin él.
  v_ruta := regexp_replace(NEW.storage_path, '^cae-documentos/', '');

  IF NOT EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id = 'cae-documentos' AND o.name = v_ruta
  ) THEN
    RAISE EXCEPTION
      'No hay ningún fichero subido en esa ruta: un documento del expediente no '
      'puede existir sin el papel detrás.'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fn_cae_documento_exige_fichero"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_cae_documento_exige_fichero"() IS 'Impide inventar una fila de documento CAE sin objeto en Storage. SECURITY DEFINER porque storage.objects tiene su propia RLS y aquí solo se comprueba existencia, nunca se devuelve contenido.';



CREATE OR REPLACE FUNCTION "public"."fn_cae_expediente_entregado_es_terminal"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF OLD.estado = 'entregado' AND NEW.estado IS DISTINCT FROM 'entregado' THEN
    RAISE EXCEPTION
      'Un expediente entregado no vuelve atrás: lo que se entregó al delegado '
      'tiene que seguir siendo lo que se entregó.';
  END IF;
  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fn_cae_expediente_entregado_es_terminal"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_cae_expediente_inmutables"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    RAISE EXCEPTION 'La organización de un expediente no se cambia.';
  END IF;
  IF NEW.ficha_codigo IS DISTINCT FROM OLD.ficha_codigo THEN
    RAISE EXCEPTION 'La ficha de un expediente no se cambia: sus requisitos son los de la ficha con la que nació. Crea un expediente nuevo.';
  END IF;
  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fn_cae_expediente_inmutables"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_cae_lote_identidad_inmutable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.comunidad_autonoma IS DISTINCT FROM OLD.comunidad_autonoma
     OR NEW.anio IS DISTINCT FROM OLD.anio THEN
    RAISE EXCEPTION
      'La organización, la comunidad autónoma y el año de un lote no se cambian: '
      'son lo que define qué puede agruparse dentro (Orden TED/815/2023 art. 14.3). '
      'Crea otro lote.';
  END IF;

  IF OLD.estado = 'entregado' AND NEW.estado IS DISTINCT FROM 'entregado' THEN
    RAISE EXCEPTION
      'Un lote entregado no se reabre: se le podría cambiar la composición y '
      'volver a cerrarlo, falsificando lo que se presentó.';
  END IF;

  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fn_cae_lote_identidad_inmutable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_cae_org_de_ruta"("p_ruta" "text") RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
  select case
    when p_ruta ~ '^cae-documentos/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
      then split_part(p_ruta, '/', 2)::uuid
    else null
  end
$$;


ALTER FUNCTION "public"."fn_cae_org_de_ruta"("p_ruta" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_cae_org_de_ruta"("p_ruta" "text") IS 'Organización dueña de un documento CAE, deducida de su ruta (cae-documentos/<organización>/<expediente>/<clave>/<fichero>). NULL si la ruta no sigue el patrón, para que la política de RLS niegue en vez de romperse.';



CREATE OR REPLACE FUNCTION "public"."fn_cae_puerta_certificado_previo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE v_tiene boolean;
BEGIN
  -- Mientras siga en borrador no hay nada que exigir. Este atajo es seguro
  -- AHORA porque lo irreversible vive en su propio disparador, arriba.
  IF NEW.estado = 'borrador' THEN RETURN NEW; END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.estado IS NOT DISTINCT FROM NEW.estado THEN RETURN NEW; END IF;
    IF OLD.estado <> 'borrador' THEN RETURN NEW; END IF;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.cae_requisitos r
    WHERE r.expediente_id = NEW.id
      AND r.clave = public.fn_cae_clave_certificado_previo()
      AND r.estado IN ('aportado','verificado')
      AND r.document_id IS NOT NULL
  ) INTO v_tiene;

  IF NOT v_tiene THEN
    RAISE EXCEPTION
      'No puedes sacar esta obra de borrador: falta el certificado energético '
      'previo. No se puede emitir una vez empezada la obra, así que si arrancas '
      'sin él tu cliente pierde la deducción entera y de forma irreversible.'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fn_cae_puerta_certificado_previo"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_cae_valida_lote"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_lote        public.cae_lotes%ROWTYPE;
  v_lote_previo public.cae_lotes%ROWTYPE;
BEGIN
  -- ── Salir de un lote: solo se mira en UPDATE, y solo si había lote antes ──
  IF TG_OP = 'UPDATE' AND OLD.lote_id IS NOT NULL
     AND OLD.lote_id IS DISTINCT FROM NEW.lote_id THEN
    SELECT * INTO v_lote_previo FROM public.cae_lotes WHERE id = OLD.lote_id;
    IF v_lote_previo.estado = 'entregado' THEN
      RAISE EXCEPTION
        'Ese lote ya está entregado: no se le pueden sacar expedientes. Lo presentado '
        'tiene que seguir siendo lo que se presentó.';
    END IF;
  END IF;

  IF NEW.lote_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_lote FROM public.cae_lotes WHERE id = NEW.lote_id;

  IF v_lote.organization_id IS DISTINCT FROM NEW.organization_id THEN
    RAISE EXCEPTION 'El lote no existe o pertenece a otra organización.';
  END IF;

  IF v_lote.comunidad_autonoma IS DISTINCT FROM NEW.comunidad_autonoma THEN
    RAISE EXCEPTION
      'No se puede meter un expediente de % en un lote de %: la Orden TED/815/2023 '
      'art. 14.3 exige que todo lo agrupado sea de la misma comunidad autónoma.',
      NEW.comunidad_autonoma, v_lote.comunidad_autonoma;
  END IF;

  IF v_lote.anio IS DISTINCT FROM NEW.anio_ejecucion THEN
    RAISE EXCEPTION
      'No se puede meter un expediente de % en un lote de %: la Orden TED/815/2023 '
      'art. 14.3 exige que todo lo agrupado sea del mismo año.',
      NEW.anio_ejecucion, v_lote.anio;
  END IF;

  IF NEW.ayuda_fnee THEN
    RAISE EXCEPTION
      'Este expediente recibió ayuda del Fondo Nacional de Eficiencia Energética '
      'y no puede generar CAE (Orden TED/815/2023 art. 14.8): no puede entrar en un lote.';
  END IF;

  IF v_lote.estado = 'entregado'
     AND (TG_OP = 'INSERT' OR OLD.lote_id IS DISTINCT FROM NEW.lote_id) THEN
    RAISE EXCEPTION 'Ese lote ya está entregado: no admite cambios de composición.';
  END IF;

  RETURN NEW;
END $$;


ALTER FUNCTION "public"."fn_cae_valida_lote"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_cae_vista_cliente"("p_token" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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

  return jsonb_build_object(
    'direccion',          v_exp.direccion,
    'comunidad_autonoma', v_exp.comunidad_autonoma,
    'anio_ejecucion',     v_exp.anio_ejecucion,
    'ficha_codigo',       v_exp.ficha_codigo,
    'ficha_version',      v_exp.ficha_version,
    'ahorro_kwh',         v_exp.ahorro_kwh,
    'estado',             v_exp.estado,
    'obra_iniciada_at',   v_exp.obra_iniciada_at,
    'ayuda_fnee',         v_exp.ayuda_fnee,
    'importe_obra_eur',   v_exp.importe_obra_eur,
    'requisitos',         v_reqs
  );
end;
$$;


ALTER FUNCTION "public"."fn_cae_vista_cliente"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_create_notifications"("p_user_ids" "uuid"[], "p_notification_type" "text", "p_title" "text", "p_body" "text", "p_pact_id" "uuid" DEFAULT NULL::"uuid", "p_milestone_id" "uuid" DEFAULT NULL::"uuid", "p_cta_url" "text" DEFAULT NULL::"text", "p_priority" "text" DEFAULT 'normal'::"text", "p_idempotency_root" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id  uuid;
  v_inserted int := 0;
  v_key      text;
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  FOREACH v_user_id IN ARRAY p_user_ids LOOP
    v_key := coalesce(
      p_idempotency_root,
      p_notification_type || ':' || coalesce(p_pact_id::text, '-') || ':' ||
        coalesce(p_milestone_id::text, '-') || ':' ||
        to_char(now(), 'YYYYMMDDHH24MISS')
    ) || ':' || v_user_id::text;

    BEGIN
      INSERT INTO public.notifications (
        user_id, pact_id, milestone_id,
        notification_type, channel, priority,
        title, body, cta_url, sent_at, idempotency_key
      ) VALUES (
        v_user_id, p_pact_id, p_milestone_id,
        p_notification_type, 'in_app', p_priority::notification_priority,
        p_title, p_body, p_cta_url, now(), v_key
      );
      v_inserted := v_inserted + 1;
    EXCEPTION
      WHEN unique_violation THEN
        -- Idempotencia: ya enviada, la saltamos sin error
        NULL;
    END;
  END LOOP;

  RETURN v_inserted;
END;
$$;


ALTER FUNCTION "public"."fn_create_notifications"("p_user_ids" "uuid"[], "p_notification_type" "text", "p_title" "text", "p_body" "text", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_cta_url" "text", "p_priority" "text", "p_idempotency_root" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_create_notifications"("p_user_ids" "uuid"[], "p_notification_type" "text", "p_title" "text", "p_body" "text", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_cta_url" "text", "p_priority" "text", "p_idempotency_root" "text") IS 'Inserta notificaciones in-app para una lista de user_ids con idempotency_key derivada del evento. Devuelve cuántas se crearon.';



CREATE OR REPLACE FUNCTION "public"."fn_create_owner_member"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE v_email text; v_name text;
BEGIN
  SELECT email, full_name INTO v_email, v_name FROM public.users WHERE id = NEW.owner_user_id;
  INSERT INTO public.organization_members (
    organization_id, user_id, invited_email, full_name, role, can_view_economics, state,
    invited_by_user_id, invited_at, accepted_at
  ) VALUES (
    NEW.id, NEW.owner_user_id, coalesce(v_email, 'unknown@local'), v_name,
    'owner', true, 'active', NEW.owner_user_id, now(), now()
  );
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."fn_create_owner_member"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_dispute_escrow_auto_create"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_pact_id uuid;
  v_amount_cents bigint;
  v_escrow_pct numeric;
  v_escrow_min bigint;
  v_escrow_max bigint;
  v_escrow_cents bigint;
BEGIN
  IF NEW.state = 'disputed' AND (OLD.state IS DISTINCT FROM 'disputed') THEN
    v_pact_id := NEW.pact_id;
    v_amount_cents := NEW.amount_cents;

    -- Leer configuración
    SELECT coalesce((SELECT (value)::numeric FROM public.app_settings
      WHERE key = 'dispute_escrow_pct'), 10)
    INTO v_escrow_pct;

    SELECT coalesce((SELECT (value)::bigint FROM public.app_settings
      WHERE key = 'dispute_escrow_min_cents'), 50000)
    INTO v_escrow_min;

    SELECT coalesce((SELECT (value)::bigint FROM public.app_settings
      WHERE key = 'dispute_escrow_max_cents'), 500000)
    INTO v_escrow_max;

    -- Calcular importe
    v_escrow_cents := greatest(
      v_escrow_min,
      least(
        v_escrow_max,
        (v_amount_cents * v_escrow_pct / 100)::bigint
      )
    );

    -- Crear registro (idempotente con ON CONFLICT)
    INSERT INTO public.dispute_escrows (
      pact_id, milestone_id, dispute_amount_cents,
      escrow_amount_cents, escrow_pct_used, state
    ) VALUES (
      v_pact_id, NEW.id, v_amount_cents,
      v_escrow_cents, v_escrow_pct, 'pending_deposit'
    )
    ON CONFLICT (milestone_id) DO UPDATE
      SET state = 'pending_deposit',
          escrow_amount_cents = EXCLUDED.escrow_amount_cents,
          dispute_amount_cents = EXCLUDED.dispute_amount_cents;

    -- Evento
    INSERT INTO public.pact_events (pact_id, event_type, payload)
    VALUES (v_pact_id, 'dispute_escrow_required',
      jsonb_build_object(
        'milestone_id', NEW.id,
        'dispute_amount_cents', v_amount_cents,
        'escrow_required_cents', v_escrow_cents,
        'escrow_pct', v_escrow_pct
      ));
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_dispute_escrow_auto_create"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_is_org_active_member"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE v_auth_uid uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RETURN false; END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.organization_members om
    JOIN public.users u ON u.id = om.user_id
    WHERE om.organization_id = p_org_id AND om.state = 'active'
      AND u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL
  );
END; $$;


ALTER FUNCTION "public"."fn_is_org_active_member"("p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_milestone_quality_check"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NEW.state = 'paid' AND (OLD.state IS DISTINCT FROM 'paid') THEN
    SELECT public.sf_check_quality_holdback(NEW.id, NEW.pact_id, NEW.amount_cents)
    INTO v_result;

    -- Si hay retención, registrar evento
    IF (v_result->>'holdback')::boolean THEN
      INSERT INTO public.pact_events (pact_id, event_type, payload)
      VALUES (NEW.pact_id, 'quality_holdback_applied',
        jsonb_build_object(
          'milestone_id', NEW.id,
          'ai_score', v_result->>'ai_score',
          'holdback_cents', v_result->>'holdback_cents',
          'net_paid_cents', v_result->>'net_paid_cents'
        ));

      -- Recalcular salud del pacto
      PERFORM public.sf_recalc_pact_health(NEW.pact_id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_milestone_quality_check"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_notification_recipients"("p_pact_id" "uuid", "p_target_roles" "text"[] DEFAULT NULL::"text"[], "p_economic" boolean DEFAULT false, "p_exclude_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("user_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  -- Parties directos del pacto
  SELECT DISTINCT pp.user_id
  FROM public.pact_parties pp
  WHERE pp.pact_id = p_pact_id
    AND (p_target_roles IS NULL OR pp.role::text = ANY(p_target_roles))
    AND (p_exclude_user_id IS NULL OR pp.user_id <> p_exclude_user_id)
    AND pp.user_id IS NOT NULL

  UNION

  -- Miembros activos de las orgs de los parties (filtrando por toggles)
  SELECT DISTINCT om.user_id
  FROM public.pact_parties pp
  JOIN public.users u ON u.id = pp.user_id
  JOIN public.organization_members om
    ON om.organization_id = u.organization_id
   AND om.state = 'active'
   AND om.receive_notifications = true
   AND (NOT p_economic OR (om.can_view_economics AND om.receive_economic_notifications))
  WHERE pp.pact_id = p_pact_id
    AND (p_target_roles IS NULL OR pp.role::text = ANY(p_target_roles))
    AND om.user_id IS NOT NULL
    AND (p_exclude_user_id IS NULL OR om.user_id <> p_exclude_user_id);
$$;


ALTER FUNCTION "public"."fn_notification_recipients"("p_pact_id" "uuid", "p_target_roles" "text"[], "p_economic" boolean, "p_exclude_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_notification_recipients"("p_pact_id" "uuid", "p_target_roles" "text"[], "p_economic" boolean, "p_exclude_user_id" "uuid") IS 'Resuelve destinatarios de notificación para un pacto: parties directos + miembros activos de sus orgs, con filtros por rol, tipo de evento económico, y exclusión opcional del actor.';



CREATE OR REPLACE FUNCTION "public"."fn_notifications_from_event"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_recipients      uuid[];
  v_pact_title      text;
  v_milestone_id    uuid;
  v_milestone_name  text;
  v_milestone_amount bigint;
  v_amount_cents    bigint;
  v_decision        text;
  v_idem            text;
BEGIN
  IF NEW.event_type IN (
    'mock_funded',
    'evidence_uploaded',
    'milestone_submitted_for_review'
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW.event_type IN ('pact_finalized', 'all_parties_accepted') THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_pact_title FROM public.pacts WHERE id = NEW.pact_id;
  v_milestone_id := NULLIF(NEW.payload ->> 'milestone_id', '')::uuid;
  IF v_milestone_id IS NOT NULL THEN
    SELECT name, amount_cents INTO v_milestone_name, v_milestone_amount
      FROM public.milestones WHERE id = v_milestone_id;
  END IF;
  v_idem := 'event:' || NEW.id::text;

  CASE NEW.event_type

    WHEN 'contract_fully_signed' THEN
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(NEW.pact_id, NULL, false, NEW.actor_user_id);
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'contract_signed',
        p_title := 'Contrato firmado · ' || coalesce(v_pact_title, 'la obra'),
        p_body := 'Todas las partes han firmado. El promotor puede '
               || 'configurar ya el Hito 0 Asegurado.',
        p_pact_id := NEW.pact_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    WHEN 'milestone_tech_reviewed' THEN
      v_decision := NEW.payload ->> 'decision';
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id,
          CASE WHEN v_decision = 'approve'
               THEN ARRAY['constructor', 'promotor']
               ELSE ARRAY['constructor'] END,
          false, NEW.actor_user_id
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'milestone_tech_reviewed',
        p_title := CASE v_decision
          WHEN 'approve'        THEN 'Técnico validó el hito · '
          WHEN 'reject'         THEN 'Técnico pide correcciones · '
          WHEN 'info_requested' THEN 'Técnico pide más información · '
          ELSE                       'Decisión del técnico · '
        END || coalesce(v_milestone_name, 'Sin nombre'),
        p_body := CASE v_decision
          WHEN 'approve'
            THEN 'El técnico ha validado el hito. Ahora le toca al promotor aprobar el pago.'
          WHEN 'reject'
            THEN 'El técnico ha rechazado el hito. Revisa el motivo y aporta las correcciones.'
          WHEN 'info_requested'
            THEN 'El técnico necesita más información antes de validar. Revisa qué falta.'
          ELSE 'El técnico ha registrado su decisión sobre el hito.'
        END,
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text
                  || '/milestones/' || v_milestone_id::text,
        p_priority := CASE WHEN v_decision = 'approve' THEN 'normal' ELSE 'high' END,
        p_idempotency_root := v_idem
      );

    WHEN 'milestone_paid' THEN
      v_amount_cents := coalesce(
        NULLIF(NEW.payload ->> 'amount_cents', '')::bigint,
        v_milestone_amount
      );
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['constructor'], true, NULL
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'milestone_paid',
        p_title := 'Cobrado ·  '
          || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
          || ' €',
        p_body := 'Se ha liberado el pago del hito "'
               || coalesce(v_milestone_name, 'sin nombre')
               || '" de ' || coalesce(v_pact_title, 'la obra') || '.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text
                  || '/milestones/' || v_milestone_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    WHEN 'cert_v21_created' THEN
      v_amount_cents := NULLIF(NEW.payload ->> 'gross_cents', '')::bigint;
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['promotor'], true, NEW.actor_user_id
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'cert_created',
        p_title := 'Nueva certificación · ' || coalesce(v_pact_title, 'la obra'),
        p_body := 'El constructor ha emitido una certificación de '
               || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
               || ' €. Revisa y aprueba el pre-depósito.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    WHEN 'deposit_replenished' THEN
      v_amount_cents := NULLIF(NEW.payload ->> 'amount_cents', '')::bigint;
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['constructor', 'tecnico'], false, NEW.actor_user_id
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'deposit_replenished',
        p_title := 'Depósito repuesto · ' || coalesce(v_pact_title, 'la obra'),
        p_body := 'El promotor ha añadido '
               || to_char(coalesce(v_amount_cents, 0) / 100.0, 'FM999G999G990D00')
               || ' € al depósito de la obra. Puedes continuar con el siguiente hito.',
        p_pact_id := NEW.pact_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'normal',
        p_idempotency_root := v_idem
      );

    WHEN 'pact_completed' THEN
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(NEW.pact_id, NULL, false, NULL);
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'pact_completed',
        p_title := 'Obra finalizada · ' || coalesce(v_pact_title, ''),
        p_body := 'Todos los hitos han quedado certificados y pagados. ¡Enhorabuena!',
        p_pact_id := NEW.pact_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'normal',
        p_idempotency_root := v_idem
      );

    WHEN 'milestone_paused_by_cron' THEN
      SELECT array_agg(user_id) INTO v_recipients
        FROM public.fn_notification_recipients(
          NEW.pact_id, ARRAY['promotor'], true, NULL
        );
      PERFORM public.fn_create_notifications(
        p_user_ids := v_recipients,
        p_notification_type := 'milestone_paused',
        p_title := 'Hito pausado · ' || coalesce(v_milestone_name, ''),
        p_body := 'El hito se ha pausado automáticamente porque venció el '
               || 'plazo del pre-depósito. Repón el depósito para reactivar la obra.',
        p_pact_id := NEW.pact_id,
        p_milestone_id := v_milestone_id,
        p_cta_url := '/pacts/' || NEW.pact_id::text,
        p_priority := 'high',
        p_idempotency_root := v_idem
      );

    -- NUEVO F2.4b · mensaje de chat enviado
    WHEN 'pact_message_sent' THEN
      PERFORM public.fn_notify_pact_message(
        NEW.pact_id,
        NEW.actor_user_id,
        NULLIF(NEW.payload ->> 'message_id', '')::uuid,
        NEW.payload ->> 'preview',
        NEW.id
      );

    ELSE
      NULL;
  END CASE;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'fn_notifications_from_event failed for event %: %',
      NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_notifications_from_event"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_notifications_from_event"() IS 'Auditoría 16-jul F2.4 + F2.4b: notifica 8 event_types del ciclo del pacto (incluye pact_message_sent del chat).';



CREATE OR REPLACE FUNCTION "public"."fn_notify_pact_message"("p_pact_id" "uuid", "p_sender_id" "uuid", "p_message_id" "uuid", "p_preview" "text", "p_event_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_recipients uuid[];
  v_sender_name text;
  v_pact_title  text;
BEGIN
  SELECT full_name INTO v_sender_name FROM public.users WHERE id = p_sender_id;
  SELECT title     INTO v_pact_title  FROM public.pacts WHERE id = p_pact_id;

  SELECT array_agg(user_id) INTO v_recipients
    FROM public.fn_notification_recipients(p_pact_id, NULL, false, p_sender_id);

  PERFORM public.fn_create_notifications(
    p_user_ids          := v_recipients,
    p_notification_type := 'pact_message',
    p_title             := 'Mensaje en ' || coalesce(v_pact_title, 'la obra'),
    p_body              := coalesce(v_sender_name, 'Alguien') || ': ' ||
                           coalesce(p_preview, ''),
    p_pact_id           := p_pact_id,
    p_cta_url           := '/pacts/' || p_pact_id::text || '/chat',
    p_priority          := 'normal',
    p_idempotency_root  := 'event:' || p_event_id::text
  );
END;
$$;


ALTER FUNCTION "public"."fn_notify_pact_message"("p_pact_id" "uuid", "p_sender_id" "uuid", "p_message_id" "uuid", "p_preview" "text", "p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_user_acts_as_constructor_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id
      AND pp.user_id = p_user_id
      AND pp.role::text = 'constructor'
  ) OR EXISTS (
    SELECT 1
    FROM public.pact_parties pp
    JOIN public.organizations o ON o.owner_user_id = pp.user_id
      AND o.deleted_at IS NULL
    JOIN public.organization_members om ON om.organization_id = o.id
    WHERE pp.pact_id = p_pact_id
      AND pp.role::text = 'constructor'
      AND om.user_id = p_user_id
      AND om.state = 'active'
  );
END;
$$;


ALTER FUNCTION "public"."fn_user_acts_as_constructor_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_user_acts_as_constructor_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") IS 'Sprint 6 · True si el user es constructor directo o miembro activo de la org constructora.';



CREATE OR REPLACE FUNCTION "public"."fn_user_can_act_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id AND pp.user_id = p_user_id
  ) OR EXISTS (
    SELECT 1
    FROM public.pact_parties pp
    JOIN public.organizations o ON o.owner_user_id = pp.user_id
      AND o.deleted_at IS NULL
    JOIN public.organization_members om ON om.organization_id = o.id
    WHERE pp.pact_id = p_pact_id
      AND om.user_id = p_user_id
      AND om.state = 'active'
      AND pp.role::text IN ('constructor', 'tecnico')
  );
END;
$$;


ALTER FUNCTION "public"."fn_user_can_act_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_user_can_act_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") IS 'Sprint 6 · True si el user es parte directa o miembro activo de la org constructora/tecnica.';



CREATE OR REPLACE FUNCTION "public"."fn_user_can_move_money"("p_pact_id" "uuid", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id AND pp.user_id = p_user_id
  );
END;
$$;


ALTER FUNCTION "public"."fn_user_can_move_money"("p_pact_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_user_can_move_money"("p_pact_id" "uuid", "p_user_id" "uuid") IS 'Sprint 6 · True solo si es parte directa (los miembros nunca mueven dinero).';



CREATE OR REPLACE FUNCTION "public"."fn_user_can_view_economics_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id AND pp.user_id = p_user_id
  ) OR EXISTS (
    SELECT 1
    FROM public.pact_parties pp
    JOIN public.organizations o ON o.owner_user_id = pp.user_id
      AND o.deleted_at IS NULL
    JOIN public.organization_members om ON om.organization_id = o.id
    WHERE pp.pact_id = p_pact_id
      AND om.user_id = p_user_id
      AND om.state = 'active'
      AND om.can_view_economics = true
      AND pp.role::text IN ('constructor', 'tecnico')
  );
END;
$$;


ALTER FUNCTION "public"."fn_user_can_view_economics_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fn_user_can_view_economics_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") IS 'Sprint 6 · True si es parte directa o miembro con can_view_economics=true.';



CREATE OR REPLACE FUNCTION "public"."fn_user_in_pact"("p_pact_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.pact_parties pp
    JOIN public.users u ON u.id = pp.user_id
    WHERE pp.pact_id = p_pact_id
      AND u.auth_provider_id = auth.uid()::text
      AND u.deleted_at IS NULL
  );
$$;


ALTER FUNCTION "public"."fn_user_in_pact"("p_pact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_validate_org_single_owner"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.role = 'owner' AND NEW.state = 'active' THEN
    IF EXISTS (
      SELECT 1 FROM public.organization_members
      WHERE organization_id = NEW.organization_id AND role = 'owner' AND state = 'active'
        AND id != coalesce(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) THEN
      RAISE EXCEPTION 'Ya existe un owner activo en la organización %', NEW.organization_id;
    END IF;
  END IF;
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."fn_validate_org_single_owner"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_reputation"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_public_user_id uuid;
BEGIN
  -- Buscar public.users.id usando el auth.uid() de la sesión actual
  SELECT id
    INTO v_public_user_id
    FROM public.users
   WHERE auth_provider_id = auth.uid()::text
     AND deleted_at IS NULL
   LIMIT 1;

  -- Si no existe perfil devolvemos un stub con score 0
  IF v_public_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'user_id',       null,
      'role',          null,
      'score',         0,
      'tier',          'nuevo',
      'components',    '{}'::jsonb,
      'shields_filled', 0,
      'is_stale',      false
    );
  END IF;

  -- Delegar en get_user_reputation con el ID correcto
  RETURN public.get_user_reputation(v_public_user_id);
END;
$$;


ALTER FUNCTION "public"."get_my_reputation"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_my_reputation"() IS 'Sprint 8 · Devuelve el último snapshot de reputación del usuario autenticado. Resuelve internamente public.users.id desde auth.uid(). Llama a sf_recalc_user_reputation si no existe snapshot todavía.';



CREATE OR REPLACE FUNCTION "public"."get_notification_target"("p_notification_id" "uuid") RETURNS TABLE("email" "text", "full_name" "text", "user_id" "uuid", "has_account" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT u.email::text, u.full_name, u.id, true
  FROM public.notifications n
  JOIN public.users u ON u.id = n.user_id
  WHERE n.id = p_notification_id AND u.deleted_at IS NULL AND u.email IS NOT NULL;
END;
$$;


ALTER FUNCTION "public"."get_notification_target"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pact_health"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE v_row pact_health_scores;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.pact_parties pp
    JOIN public.users u ON u.id = pp.user_id
    WHERE pp.pact_id = p_pact_id AND u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL
  ) THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE = 'insufficient_privilege'; END IF;

  SELECT * INTO v_row FROM public.pact_health_scores
  WHERE pact_id = p_pact_id ORDER BY calculated_at DESC LIMIT 1;

  IF NOT FOUND THEN
    PERFORM public.sf_recalc_pact_health(p_pact_id);
    SELECT * INTO v_row FROM public.pact_health_scores
    WHERE pact_id = p_pact_id ORDER BY calculated_at DESC LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id, 'pact_id', v_row.pact_id, 'score', v_row.score,
    'milestone_compliance_pct', v_row.milestone_compliance_pct,
    'evidence_validity_pct', v_row.evidence_validity_pct,
    'validation_speed_pct', v_row.validation_speed_pct,
    'no_disputes_pct', v_row.no_disputes_pct,
    'ia_evidence_score', v_row.ia_evidence_score,
    'calculated_at', v_row.calculated_at
  );
END;
$$;


ALTER FUNCTION "public"."get_pact_health"("p_pact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_reputation"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE v_row user_reputations;
BEGIN
  -- ── Control de acceso (auditoría 2026-07-13 A3) ──────────────────
  -- Permitido solo si el llamante es el propio usuario consultado o si
  -- comparte al menos un pacto con él (mismo criterio que get_pact_health).
  IF NOT EXISTS (
    -- (i) el propio usuario
    SELECT 1 FROM public.users u
    WHERE u.id = p_user_id
      AND u.auth_provider_id = auth.uid()::text
      AND u.deleted_at IS NULL
    UNION
    -- (ii) contraparte en algún pacto compartido
    SELECT 1
    FROM public.pact_parties pp_self
    JOIN public.users u_self ON u_self.id = pp_self.user_id
    JOIN public.pact_parties pp_target ON pp_target.pact_id = pp_self.pact_id
    WHERE u_self.auth_provider_id = auth.uid()::text
      AND u_self.deleted_at IS NULL
      AND pp_target.user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_row FROM public.user_reputations
  WHERE user_id = p_user_id ORDER BY calculated_at DESC LIMIT 1;

  IF NOT FOUND THEN
    PERFORM public.sf_recalc_user_reputation(p_user_id);
    SELECT * INTO v_row FROM public.user_reputations
    WHERE user_id = p_user_id ORDER BY calculated_at DESC LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id, 'user_id', v_row.user_id, 'role', v_row.role,
    'score', v_row.score, 'tier', v_row.tier, 'components', v_row.components,
    'pacts_total', v_row.pacts_total, 'pacts_completed', v_row.pacts_completed,
    'pacts_disputed', v_row.pacts_disputed, 'calculated_at', v_row.calculated_at
  );
END;
$$;


ALTER FUNCTION "public"."get_user_reputation"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_addendum_active"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_old_total bigint;
  v_new_total bigint;
BEGIN
  IF NEW.state != 'active' OR OLD.state = 'active' THEN
    RETURN NEW;
  END IF;
  SELECT total_amount_cents INTO v_old_total FROM public.pacts WHERE id = NEW.pact_id;
  v_new_total := v_old_total + NEW.extra_amount_cents;
  IF v_new_total < 0 THEN
    RAISE EXCEPTION 'El anexo deja el presupuesto en negativo (%). Operación denegada.', v_new_total;
  END IF;
  UPDATE public.pacts SET total_amount_cents = v_new_total WHERE id = NEW.pact_id;
  NEW.finalized_at := now();
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (NEW.pact_id, 'addendum_activated',
    jsonb_build_object('addendum_id', NEW.id, 'ordinal', NEW.ordinal,
      'extra_amount_cents', NEW.extra_amount_cents,
      'old_total_cents', v_old_total, 'new_total_cents', v_new_total),
    NEW.proposed_by_user_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_addendum_active"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_deposit_low_alert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_required_cents bigint;
  v_threshold_cents bigint;
  v_promotor_user_id uuid;
  v_idem text;
BEGIN
  IF NEW.deposit_current_cents >= OLD.deposit_current_cents THEN
    RETURN NEW;
  END IF;
  v_required_cents := (NEW.total_amount_cents * NEW.deposit_required_pct / 100)::bigint;
  v_threshold_cents := v_required_cents / 2;
  IF OLD.deposit_current_cents >= v_threshold_cents
     AND NEW.deposit_current_cents < v_threshold_cents THEN
    SELECT user_id INTO v_promotor_user_id
    FROM public.pact_parties
    WHERE pact_id = NEW.id AND role = 'promotor'
    LIMIT 1;
    IF v_promotor_user_id IS NOT NULL THEN
      v_idem := 'deposit_low:' || NEW.id::text || ':' || extract(epoch from now())::bigint::text;
      INSERT INTO public.notifications (
        user_id, pact_id, notification_type, channel, priority,
        title, body, cta_url, idempotency_key
      ) VALUES
        (v_promotor_user_id, NEW.id, 'deposit_low',
         'email'::notification_channel, 'high'::notification_priority,
         'Depósito de garantía bajo · ' || NEW.title,
         'El depósito del pacto ' || NEW.display_id || ' ha bajado al 50% del mínimo pactado (' ||
         NEW.deposit_required_pct || '%). Reponlo cuanto antes para evitar paralización del pacto.',
         '/pacts/' || NEW.id, v_idem || ':email'),
        (v_promotor_user_id, NEW.id, 'deposit_low',
         'in_app'::notification_channel, 'high'::notification_priority,
         'Depósito de garantía bajo',
         'El depósito ha bajado al 50% del mínimo pactado. Repón cuanto antes.',
         '/pacts/' || NEW.id, v_idem || ':in_app');
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_deposit_low_alert error: %', SQLERRM;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_deposit_low_alert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_link_pending_invitations"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.email IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.pact_parties
  SET user_id = NEW.id
  WHERE user_id IS NULL
    AND lower(snapshot_email) = lower(NEW.email::text);

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_link_pending_invitations"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_link_pending_invitations"() IS 'Trigger AFTER INSERT users: vincula pact_parties huérfanos con snapshot_email coincidente.';



CREATE OR REPLACE FUNCTION "public"."handle_milestone_paid_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_next_milestone_id uuid; v_remaining_unpaid int;
BEGIN
  IF OLD.state = NEW.state OR NEW.state != 'paid' THEN RETURN NEW; END IF;
  SELECT id INTO v_next_milestone_id FROM public.milestones
  WHERE pact_id = NEW.pact_id AND state = 'pending' AND ordinal > NEW.ordinal
  ORDER BY ordinal LIMIT 1;
  IF v_next_milestone_id IS NOT NULL THEN
    UPDATE public.milestones SET state = 'in_execution', started_at = now() WHERE id = v_next_milestone_id;
    INSERT INTO public.pact_events (pact_id, event_type, payload)
    VALUES (NEW.pact_id, 'next_milestone_started',
      jsonb_build_object('previous_milestone_id', NEW.id, 'next_milestone_id', v_next_milestone_id));
  ELSE
    SELECT count(*) INTO v_remaining_unpaid FROM public.milestones
    WHERE pact_id = NEW.pact_id AND state != 'paid';
    IF v_remaining_unpaid = 0 THEN
      UPDATE public.pacts SET state = 'completed', closed_at = now()
      WHERE id = NEW.pact_id AND state = 'in_execution';
      INSERT INTO public.pact_events (pact_id, event_type, payload)
      VALUES (NEW.pact_id, 'pact_completed', jsonb_build_object('total_milestones_paid', NEW.ordinal));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_milestone_paid_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_milestone_paid_surety_decrement"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_amortization bigint;
BEGIN
  -- Solo aplica al transicionar a 'paid'
  IF NEW.state = 'paid' AND (OLD.state IS DISTINCT FROM 'paid') THEN
    v_amortization := NEW.advance_amortization_cents;

    IF v_amortization > 0 THEN
      -- Actualizar advance_outstanding del pacto
      UPDATE public.pacts
      SET advance_outstanding_cents = greatest(0, advance_outstanding_cents - v_amortization)
      WHERE id = NEW.pact_id;

      -- Actualizar cobertura de la póliza activa (si existe)
      UPDATE public.surety_policies
      SET current_coverage_cents = greatest(0, current_coverage_cents - v_amortization),
          updated_at = now()
      WHERE pact_id = NEW.pact_id
        AND status = 'active';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_milestone_paid_surety_decrement"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_milestone_state_recalc_health"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Solo en cambios de estado real
  IF NEW.state IS DISTINCT FROM OLD.state THEN
    PERFORM public.sf_recalc_pact_health(NEW.pact_id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_milestone_state_recalc_health"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_meta             jsonb;
  v_user_id          uuid;
  v_org_id           uuid;
  v_role             text;
  v_invitation_token uuid;
  v_locale           text;
  v_country          char(2);
BEGIN
  v_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  v_role := v_meta->>'primary_role';

  -- Idioma elegido en el paso 1 del wizard. Se valida aquí y no se confía en
  -- el cliente: cualquier valor no soportado cae a español en vez de violar
  -- el CHECK y tumbar el alta entera.
  -- `lower()` normaliza 'ES-419' → 'es-419'. El guion se conserva: es una
  -- subetiqueta de región BCP 47, no un separador nuestro.
  v_locale := lower(COALESCE(v_meta->>'locale', 'es'));
  IF v_locale NOT IN ('es', 'es-419', 'en') THEN
    v_locale := 'es';
  END IF;

  -- País del selector. Mismo criterio defensivo: default 'ES' si no viene o
  -- no es un alpha-2.
  v_country := upper(COALESCE(NULLIF(v_meta->>'country_iso', ''), 'ES'))::char(2);

  BEGIN
    v_invitation_token := (v_meta->>'invitation_token')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_invitation_token := NULL;
  END;

  IF v_invitation_token IS NOT NULL THEN
    INSERT INTO public.users (
      auth_provider_id,
      full_name,
      email,
      phone_e164,
      primary_role,
      organization_id,
      kyc_status,
      locale,
      country_iso
    ) VALUES (
      NEW.id::text,
      COALESCE(v_meta->>'full_name', NEW.email),
      NEW.email,
      v_meta->>'phone_e164',
      NULL,
      NULL,
      'not_started',
      v_locale,
      v_country
    )
    RETURNING id INTO v_user_id;

    INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
    VALUES
      (v_user_id, 'terms_of_service',
       COALESCE(v_meta->>'terms_version', '1.0'),
       'sha256_placeholder_terms'),
      (v_user_id, 'privacy_policy',
       COALESCE(v_meta->>'privacy_version', '1.0'),
       'sha256_placeholder_privacy');

    INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
    VALUES (v_user_id, 'user_registered_via_invite', 'user', v_user_id,
      jsonb_build_object('invitation_token', v_invitation_token));

    RETURN NEW;
  END IF;

  IF v_role IS NULL OR v_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RETURN NEW;
  END IF;

  IF v_role = 'constructor' AND COALESCE(v_meta->>'organization_name', '') <> '' THEN
    INSERT INTO public.organizations (legal_name, cif, province)
    VALUES (
      v_meta->>'organization_name',
      v_meta->>'cif_or_nif',
      v_meta->>'province'
    )
    RETURNING id INTO v_org_id;
  END IF;

  INSERT INTO public.users (
    auth_provider_id,
    full_name,
    email,
    phone_e164,
    national_id,
    province,
    primary_role,
    profession,
    colegio,
    num_colegiacion,
    organization_id,
    kyc_status,
    locale,
    country_iso
  ) VALUES (
    NEW.id::text,
    COALESCE(v_meta->>'full_name', NEW.email),
    NEW.email,
    v_meta->>'phone_e164',
    CASE WHEN v_role IN ('promotor', 'tecnico') THEN v_meta->>'cif_or_nif' END,
    v_meta->>'province',
    v_role::user_role,
    v_meta->>'profession',
    v_meta->>'colegio',
    v_meta->>'num_colegiacion',
    v_org_id,
    'not_started',
    v_locale,
    v_country
  )
  RETURNING id INTO v_user_id;

  INSERT INTO public.legal_consents (user_id, doc_type, doc_version, doc_hash)
  VALUES
    (v_user_id, 'terms_of_service',
     COALESCE(v_meta->>'terms_version', '1.0'),
     'sha256_placeholder_terms'),
    (v_user_id, 'privacy_policy',
     COALESCE(v_meta->>'privacy_version', '1.0'),
     'sha256_placeholder_privacy');

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_user_id, 'user_registered', 'user', v_user_id);

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_new_auth_user"() IS 'Sprint 1: completa el registro automáticamente al crear auth.users. Lee raw_user_meta_data del signUp.';



CREATE OR REPLACE FUNCTION "public"."handle_pact_event_notify"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_pact public.pacts%ROWTYPE;
  v_milestone_id uuid;
  v_milestone_name text;
  v_amount_cents bigint;
  v_constructor_user uuid;
  v_promotor_user uuid;
  v_tecnico_user uuid;
  v_all_users uuid[];
  v_idem text;
BEGIN
  SELECT * INTO v_pact FROM public.pacts WHERE id = NEW.pact_id;
  IF v_pact.id IS NULL THEN RETURN NEW; END IF;

  SELECT user_id INTO v_promotor_user FROM public.pact_parties
    WHERE pact_id = NEW.pact_id AND role = 'promotor';
  SELECT user_id INTO v_constructor_user FROM public.pact_parties
    WHERE pact_id = NEW.pact_id AND role = 'constructor';
  SELECT user_id INTO v_tecnico_user FROM public.pact_parties
    WHERE pact_id = NEW.pact_id AND role = 'tecnico';

  SELECT array_agg(user_id) INTO v_all_users
  FROM public.pact_parties
  WHERE pact_id = NEW.pact_id AND user_id IS NOT NULL;

  v_idem := 'evt:' || NEW.id::text;
  v_milestone_id := (NEW.payload->>'milestone_id')::uuid;
  IF v_milestone_id IS NOT NULL THEN
    SELECT name, amount_cents INTO v_milestone_name, v_amount_cents
    FROM public.milestones WHERE id = v_milestone_id;
  END IF;

  CASE NEW.event_type
    WHEN 'all_parties_accepted' THEN
      PERFORM public._notify_users(v_all_users, v_pact.id, NULL, 'all_parties_accepted',
        'Listos para firmar · ' || v_pact.title,
        'Todas las partes han aceptado la invitación. Es momento de firmar el contrato del pacto ' || v_pact.display_id || '.',
        '/pacts/' || v_pact.id || '/sign', v_idem);
    WHEN 'contract_fully_signed' THEN
      PERFORM public._notify_users(v_all_users, v_pact.id, NULL, 'contract_fully_signed',
        'Contrato firmado · ' || v_pact.title,
        'Todas las partes han firmado el contrato del pacto ' || v_pact.display_id || '. El pacto está listo para activar la custodia.',
        '/pacts/' || v_pact.id, v_idem);
    WHEN 'mock_funded' THEN
      IF v_constructor_user IS NOT NULL THEN
        PERFORM public._notify_users(ARRAY[v_constructor_user], v_pact.id, v_milestone_id, 'pact_funded',
          'Obra activada · primer hito en ejecución',
          'El promotor ha activado la custodia del pacto ' || v_pact.display_id || '. Ya puedes empezar a subir evidencias del primer hito.',
          '/pacts/' || v_pact.id, v_idem);
      END IF;
    WHEN 'milestone_submitted_for_review' THEN
      IF v_pact.pact_type = 'obra_mayor' AND v_tecnico_user IS NOT NULL THEN
        PERFORM public._notify_users(ARRAY[v_tecnico_user], v_pact.id, v_milestone_id, 'milestone_pending_tech_review',
          'Hito pendiente de validación técnica',
          'El constructor ha completado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '. Revisa las evidencias y valida.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id, v_idem);
      ELSIF v_pact.pact_type = 'obra_menor' AND v_promotor_user IS NOT NULL THEN
        PERFORM public._notify_users(ARRAY[v_promotor_user], v_pact.id, v_milestone_id, 'milestone_pending_promotor',
          'Hito pendiente de tu validación',
          'En tu obra menor "' || v_pact.title || '", el constructor ha completado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '". Revisa las evidencias.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id, v_idem);
      END IF;
    WHEN 'milestone_tech_reviewed' THEN
      IF (NEW.payload->>'decision') = 'approve' AND v_promotor_user IS NOT NULL THEN
        PERFORM public._notify_users(ARRAY[v_promotor_user], v_pact.id, v_milestone_id, 'milestone_pending_promotor',
          'Hito aprobado por el técnico · te toca',
          'El técnico ha aprobado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '. Aprueba para liberar el pago.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id, v_idem);
      ELSIF (NEW.payload->>'decision') IN ('reject', 'request_info') AND v_constructor_user IS NOT NULL THEN
        PERFORM public._notify_users(ARRAY[v_constructor_user], v_pact.id, v_milestone_id, 'milestone_needs_rework',
          CASE WHEN (NEW.payload->>'decision') = 'reject' THEN 'Hito rechazado por el técnico' ELSE 'El técnico solicita más información' END,
          'Revisa los comentarios del técnico para el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id, v_idem);
      END IF;
    WHEN 'milestone_paid' THEN
      IF v_constructor_user IS NOT NULL THEN
        PERFORM public._notify_users(ARRAY[v_constructor_user], v_pact.id, v_milestone_id, 'milestone_paid',
          'Pago liberado · ' || COALESCE(v_milestone_name, 'hito'),
          'Se han liberado ' || (v_amount_cents::numeric / 100) || ' € a tu cuenta por el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '.',
          '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id, v_idem);
      END IF;
      IF v_tecnico_user IS NOT NULL THEN
        PERFORM public._enqueue_notification(v_tecnico_user, v_pact.id, v_milestone_id, 'milestone_paid',
          'in_app'::notification_channel, 'Hito pagado',
          'El hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || ' se ha pagado al constructor.',
          '/pacts/' || v_pact.id, v_idem || ':tec_inapp');
      END IF;
    WHEN 'milestone_disputed' THEN
      PERFORM public._notify_users(v_all_users, v_pact.id, v_milestone_id, 'milestone_disputed',
        'Hito en disputa · acción requerida',
        'El promotor ha objetado el hito "' || COALESCE(v_milestone_name, 'sin nombre') || '" del pacto ' || v_pact.display_id || '. Las partes deben resolver la disputa.',
        '/pacts/' || v_pact.id || '/milestones/' || v_milestone_id, v_idem);
    WHEN 'pact_completed' THEN
      PERFORM public._notify_users(v_all_users, v_pact.id, NULL, 'pact_completed',
        'Obra completada · ' || v_pact.title,
        'Todos los hitos del pacto ' || v_pact.display_id || ' se han pagado. La obra queda cerrada en PactStream.',
        '/pacts/' || v_pact.id, v_idem);
    ELSE NULL;
  END CASE;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_pact_event_notify error for event % (%): %', NEW.id, NEW.event_type, SQLERRM;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_pact_event_notify"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_party_invited_notify"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_pact public.pacts%ROWTYPE;
  v_creator_name text;
BEGIN
  IF NEW.user_id IS NULL AND NEW.snapshot_email IS NULL THEN RETURN NEW; END IF;
  SELECT * INTO v_pact FROM public.pacts WHERE id = NEW.pact_id;
  SELECT full_name INTO v_creator_name FROM public.users WHERE id = v_pact.created_by_user_id;

  IF NEW.user_id IS NOT NULL THEN
    PERFORM public._notify_users(ARRAY[NEW.user_id], NEW.pact_id, NULL, 'pact_invitation',
      'Te han invitado a un pacto · ' || v_pact.title,
      COALESCE(v_creator_name, 'Alguien') || ' te ha invitado como ' || NEW.role::text ||
      ' al pacto ' || v_pact.display_id || ' (' || v_pact.title || ').',
      '/pacts/' || NEW.pact_id, 'invite:' || NEW.id::text);
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_party_invited_notify error for party %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_party_invited_notify"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notification_failed"("p_notification_id" "uuid", "p_reason" "text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$ UPDATE public.notifications SET failed_at = now(), failure_reason = p_reason WHERE id = p_notification_id; $$;


ALTER FUNCTION "public"."mark_notification_failed"("p_notification_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notification_sent"("p_notification_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$ UPDATE public.notifications SET sent_at = now() WHERE id = p_notification_id AND sent_at IS NULL; $$;


ALTER FUNCTION "public"."mark_notification_sent"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_deposit_movement_modification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Los movimientos del depósito son append-only. DELETE no permitido.';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Los movimientos del depósito son append-only. UPDATE no permitido.';
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."prevent_deposit_movement_modification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_event_modification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RAISE EXCEPTION 'pact_events es append-only.';
END;
$$;


ALTER FUNCTION "public"."prevent_event_modification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_evidence_modification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Las evidencias son append-only. No se permiten DELETE.';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Datos forenses: identidad de la fila, del fichero y del acto de captura.
    IF NEW.id                  IS DISTINCT FROM OLD.id
       OR NEW.milestone_id        IS DISTINCT FROM OLD.milestone_id
       OR NEW.uploaded_by_user_id IS DISTINCT FROM OLD.uploaded_by_user_id
       OR NEW.storage_path        IS DISTINCT FROM OLD.storage_path
       OR NEW.sha256_hash         IS DISTINCT FROM OLD.sha256_hash
       OR NEW.server_timestamp    IS DISTINCT FROM OLD.server_timestamp
       OR NEW.client_timestamp    IS DISTINCT FROM OLD.client_timestamp
       OR NEW.gps_latitude        IS DISTINCT FROM OLD.gps_latitude
       OR NEW.gps_longitude       IS DISTINCT FROM OLD.gps_longitude
       OR NEW.exif_metadata       IS DISTINCT FROM OLD.exif_metadata
    THEN
      RAISE EXCEPTION 'Los datos forenses de la evidencia son inmutables.';
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."prevent_evidence_modification"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."prevent_evidence_modification"() IS 'Append-only de milestone_evidences. DELETE siempre bloqueado. UPDATE bloqueado si cambia cualquier dato forense: identidad de la fila, ruta y hash del fichero, horas de cliente y servidor, GPS o EXIF. Solo quedan editables is_superseded, superseded_by_id, el texto libre y los campos que rellenará la verificación geográfica.';



CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_accept_invitation"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_party    public.pact_parties%ROWTYPE;
  v_pact_state pact_state;
  v_total_parties int;
  v_accepted_parties int;
  v_new_state pact_state;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT * INTO v_party
  FROM public.pact_parties pp
  WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id;

  IF v_party.id IS NULL THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  IF v_party.accepted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Ya aceptaste esta invitación';
  END IF;

  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state NOT IN ('inviting', 'signing') THEN
    RAISE EXCEPTION 'No se puede aceptar invitación en estado: %', v_pact_state;
  END IF;

  UPDATE public.pact_parties
  SET accepted_at = now()
  WHERE id = v_party.id;

  SELECT count(*), count(*) FILTER (WHERE accepted_at IS NOT NULL)
  INTO v_total_parties, v_accepted_parties
  FROM public.pact_parties WHERE pact_id = p_pact_id;

  v_new_state := v_pact_state;

  IF v_pact_state = 'inviting' AND v_accepted_parties = v_total_parties THEN
    UPDATE public.pacts SET state = 'signing' WHERE id = p_pact_id;
    v_new_state := 'signing';

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (p_pact_id, 'all_parties_accepted',
      jsonb_build_object('parties_count', v_total_parties),
      v_user_id);
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'invitation_accepted', 'pact', p_pact_id,
    jsonb_build_object('role', v_party.role::text));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', v_new_state::text,
    'all_accepted', v_accepted_parties = v_total_parties
  );
END;
$$;


ALTER FUNCTION "public"."sf_accept_invitation"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_accept_invitation"("p_pact_id" "uuid") IS 'El caller acepta su parte del pacto. Cuando todos aceptan, pact pasa inviting → signing.';



CREATE OR REPLACE FUNCTION "public"."sf_accept_org_invite"("p_invitation_token" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid; v_user_id uuid; v_user_email text;
  v_member public.organization_members%ROWTYPE;
  v_org public.organizations%ROWTYPE;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id, lower(u.email) INTO v_user_id, v_user_email FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_member FROM public.organization_members
  WHERE invitation_token = p_invitation_token;
  IF v_member.id IS NULL THEN
    RAISE EXCEPTION 'Token de invitación no encontrado o ya consumido';
  END IF;
  IF v_member.state != 'invited' THEN
    RAISE EXCEPTION 'La invitación ya fue procesada (estado: %)', v_member.state;
  END IF;
  IF lower(v_member.invited_email) != v_user_email THEN
    RAISE EXCEPTION 'Esta invitación fue enviada a otro email. Inicia sesión con la cuenta correcta.';
  END IF;

  SELECT * INTO v_org FROM public.organizations WHERE id = v_member.organization_id;
  IF v_org.id IS NULL THEN RAISE EXCEPTION 'La organización ya no existe'; END IF;

  UPDATE public.organization_members
  SET state = 'active', user_id = v_user_id, accepted_at = now(),
      invitation_token = gen_random_uuid()
  WHERE id = v_member.id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_accepted', 'organization_member', v_member.id,
    jsonb_build_object('org_id', v_org.id, 'legal_name', v_org.legal_name));

  RETURN jsonb_build_object(
    'success', true,
    'organization', jsonb_build_object(
      'id', v_org.id, 'legal_name', v_org.legal_name, 'org_type', v_org.org_type::text
    ),
    'member', jsonb_build_object(
      'id', v_member.id, 'role', v_member.role::text,
      'can_view_economics', v_member.can_view_economics
    )
  );
END; $$;


ALTER FUNCTION "public"."sf_accept_org_invite"("p_invitation_token" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_add_milestone"("p_pact_id" "uuid", "p_ordinal" smallint, "p_name" "text", "p_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text", "p_target_date" "date" DEFAULT NULL::"date") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_milestone_id uuid;
  v_pact_state pact_state;
  v_creator_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
BEGIN
  v_auth_uid := auth.uid();
  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT state, created_by_user_id INTO v_pact_state, v_creator_id
  FROM public.pacts WHERE id = p_pact_id;

  IF v_pact_state IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact_state != 'draft' THEN
    RAISE EXCEPTION 'Solo puedes añadir hitos en estado draft';
  END IF;
  IF v_creator_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede añadir hitos';
  END IF;

  IF p_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El importe mínimo por hito es 500 €';
  END IF;

  LOOP
    v_display_id := 'PS-HIT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');

    SELECT EXISTS(
      SELECT 1 FROM public.milestones WHERE display_id = v_display_id
    ) INTO v_exists;

    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único para hito';
    END IF;
  END LOOP;

  INSERT INTO public.milestones (
    pact_id, display_id, ordinal, name, description,
    amount_cents, target_date, state
  ) VALUES (
    p_pact_id, v_display_id, p_ordinal, p_name, p_description,
    p_amount_cents, p_target_date, 'pending'
  )
  RETURNING id INTO v_milestone_id;

  RETURN v_milestone_id;
END;
$$;


ALTER FUNCTION "public"."sf_add_milestone"("p_pact_id" "uuid", "p_ordinal" smallint, "p_name" "text", "p_amount_cents" bigint, "p_description" "text", "p_target_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_addendum_create"("p_pact_id" "uuid", "p_title" "text", "p_extra_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text", "p_extra_days" smallint DEFAULT 0, "p_justification" "text" DEFAULT NULL::"text", "p_detailed_doc_storage_path" "text" DEFAULT NULL::"text", "p_detailed_doc_sha256" "text" DEFAULT NULL::"text", "p_detailed_doc_mime_type" "text" DEFAULT NULL::"text", "p_detailed_doc_size_bytes" bigint DEFAULT NULL::bigint) RETURNS TABLE("out_addendum_id" "uuid", "out_display_id" "text", "out_ordinal" smallint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_addendum_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
  v_next_ordinal smallint;
  v_new_total bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'Los anexos solo aplican a pacts v2';
  END IF;
  IF v_pact.state NOT IN ('in_execution', 'paused_pending_tech') THEN
    RAISE EXCEPTION 'Solo se pueden crear anexos con el pacto en ejecución';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No formas parte del pacto';
  END IF;

  -- Validar que el nuevo presupuesto no sea negativo
  v_new_total := v_pact.total_amount_cents + p_extra_amount_cents;
  IF v_new_total < 0 THEN
    RAISE EXCEPTION 'El anexo dejaría el presupuesto en negativo';
  END IF;

  -- Documento detallado obligatorio si extra > 10.000€
  IF abs(p_extra_amount_cents) > 1000000 AND p_detailed_doc_storage_path IS NULL THEN
    RAISE EXCEPTION 'Para anexos > 10.000 € es obligatorio adjuntar documento detallado';
  END IF;

  -- Calcular ordinal
  SELECT coalesce(max(ordinal), 0) + 1 INTO v_next_ordinal
  FROM public.pact_addendums WHERE pact_id = p_pact_id;

  -- Generar display_id
  LOOP
    v_display_id := 'PS-ANX-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.pact_addendums WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.pact_addendums (
    pact_id, display_id, ordinal,
    title, description, extra_amount_cents, extra_days, justification,
    detailed_doc_storage_path, detailed_doc_sha256, detailed_doc_mime_type, detailed_doc_size_bytes,
    proposed_by_user_id, proposed_by_role, state
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal,
    p_title, p_description, p_extra_amount_cents, p_extra_days, p_justification,
    p_detailed_doc_storage_path, p_detailed_doc_sha256, p_detailed_doc_mime_type, p_detailed_doc_size_bytes,
    v_user_id, v_user_role, 'proposed'
  )
  RETURNING id INTO v_addendum_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'addendum_proposed',
    jsonb_build_object(
      'addendum_id', v_addendum_id,
      'ordinal', v_next_ordinal,
      'extra_amount_cents', p_extra_amount_cents,
      'proposed_by_role', v_user_role::text
    ),
    v_user_id);

  out_addendum_id := v_addendum_id;
  out_display_id := v_display_id;
  out_ordinal := v_next_ordinal;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."sf_addendum_create"("p_pact_id" "uuid", "p_title" "text", "p_extra_amount_cents" bigint, "p_description" "text", "p_extra_days" smallint, "p_justification" "text", "p_detailed_doc_storage_path" "text", "p_detailed_doc_sha256" "text", "p_detailed_doc_mime_type" "text", "p_detailed_doc_size_bytes" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_addendum_create"("p_pact_id" "uuid", "p_title" "text", "p_extra_amount_cents" bigint, "p_description" "text", "p_extra_days" smallint, "p_justification" "text", "p_detailed_doc_storage_path" "text", "p_detailed_doc_sha256" "text", "p_detailed_doc_mime_type" "text", "p_detailed_doc_size_bytes" bigint) IS 'Sprint 4 · Propone anexo al pacto. Doc detallado obligatorio si extra > 10.000€.';



CREATE OR REPLACE FUNCTION "public"."sf_addendum_sign"("p_addendum_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_addendum public.pact_addendums%ROWTYPE;
  v_pact_type pact_type;
  v_required_sigs int;
  v_actual_sigs int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_addendum FROM public.pact_addendums WHERE id = p_addendum_id;
  IF v_addendum.id IS NULL THEN RAISE EXCEPTION 'Anexo no encontrado'; END IF;
  IF v_addendum.state = 'active' THEN
    RAISE EXCEPTION 'El anexo ya está activo';
  END IF;
  IF v_addendum.state = 'cancelled' THEN
    RAISE EXCEPTION 'El anexo está cancelado';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_addendum.pact_id AND user_id = v_user_id;
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'No formas parte del pacto';
  END IF;

  -- Marcar firma según rol del caller
  IF v_user_role = 'promotor' THEN
    IF v_addendum.signed_at_promotor IS NOT NULL THEN
      RAISE EXCEPTION 'Ya firmaste este anexo';
    END IF;
    UPDATE public.pact_addendums SET signed_at_promotor = now(), state = 'signing'
    WHERE id = p_addendum_id;
  ELSIF v_user_role = 'constructor' THEN
    IF v_addendum.signed_at_constructor IS NOT NULL THEN
      RAISE EXCEPTION 'Ya firmaste este anexo';
    END IF;
    UPDATE public.pact_addendums SET signed_at_constructor = now(), state = 'signing'
    WHERE id = p_addendum_id;
  ELSIF v_user_role = 'tecnico' THEN
    IF v_addendum.signed_at_tecnico IS NOT NULL THEN
      RAISE EXCEPTION 'Ya firmaste este anexo';
    END IF;
    UPDATE public.pact_addendums SET signed_at_tecnico = now(), state = 'signing'
    WHERE id = p_addendum_id;
  END IF;

  -- Comprobar si todas las partes han firmado
  SELECT pact_type INTO v_pact_type FROM public.pacts WHERE id = v_addendum.pact_id;
  v_required_sigs := CASE WHEN v_pact_type = 'obra_mayor' THEN 3 ELSE 2 END;

  SELECT
    (CASE WHEN signed_at_promotor IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN signed_at_constructor IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN signed_at_tecnico IS NOT NULL THEN 1 ELSE 0 END)
  INTO v_actual_sigs
  FROM public.pact_addendums WHERE id = p_addendum_id;

  IF v_actual_sigs >= v_required_sigs THEN
    -- Todos firmaron → activar (el trigger handle_addendum_active actualiza el total)
    UPDATE public.pact_addendums SET state = 'active' WHERE id = p_addendum_id;
  END IF;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_addendum.pact_id, 'addendum_signed',
    jsonb_build_object(
      'addendum_id', p_addendum_id,
      'signed_by_role', v_user_role::text,
      'sigs', v_actual_sigs,
      'required', v_required_sigs
    ),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'sigs', v_actual_sigs,
    'required', v_required_sigs,
    'active', v_actual_sigs >= v_required_sigs
  );
END;
$$;


ALTER FUNCTION "public"."sf_addendum_sign"("p_addendum_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_addendum_sign"("p_addendum_id" "uuid") IS 'Sprint 4 · Firma anexo por parte del caller. Cuando todas firman, anexo → active (trigger actualiza total).';



CREATE OR REPLACE FUNCTION "public"."sf_ai_month_cost_cents"() RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$SELECT coalesce(sum(cost_cents), 0) FROM public.ai_runs WHERE created_at >= date_trunc('month', now()) AND provider = 'live'$$;


ALTER FUNCTION "public"."sf_ai_month_cost_cents"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_ai_today_cost_cents"() RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT coalesce(sum(cost_cents), 0)
  FROM public.ai_runs
  WHERE created_at >= date_trunc('day', now())
    AND provider = 'live';
$$;


ALTER FUNCTION "public"."sf_ai_today_cost_cents"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_apply_ipc_to_milestone"("p_milestone_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_milestone record;
  v_pact record;
  v_adjustment jsonb;
  v_new_amount bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT m.*, p.ipc_enabled, p.ipc_base_month, p.ipc_base_value
  INTO v_milestone
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_milestone IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  IF NOT v_milestone.ipc_enabled THEN
    RAISE EXCEPTION 'El pacto no tiene cláusula IPC activa';
  END IF;

  IF v_milestone.state NOT IN ('pending', 'in_execution') THEN
    RAISE EXCEPTION 'Solo se puede ajustar IPC en hitos pendientes o en ejecución';
  END IF;

  -- Calcular ajuste
  v_adjustment := public.sf_calc_ipc_adjustment(
    v_milestone.ipc_base_month,
    to_char(now(), 'YYYY-MM'),
    coalesce(v_milestone.original_amount_cents, v_milestone.amount_cents)
  );

  IF v_adjustment->>'error' IS NOT NULL THEN
    RETURN v_adjustment;
  END IF;

  v_new_amount := (v_adjustment->>'adjusted_cents')::bigint;

  -- Aplicar
  UPDATE public.milestones
  SET original_amount_cents = coalesce(original_amount_cents, amount_cents),
      amount_cents = v_new_amount,
      ipc_adjustment_pct = (v_adjustment->>'variation_pct')::numeric,
      ipc_applied_month = to_char(now(), 'YYYY-MM')
  WHERE id = p_milestone_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_milestone.pact_id, 'ipc_adjustment_applied',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'original_cents', coalesce(v_milestone.original_amount_cents, v_milestone.amount_cents),
      'adjusted_cents', v_new_amount,
      'variation_pct', v_adjustment->>'variation_pct',
      'base_month', v_milestone.ipc_base_month
    ),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'milestone_id', p_milestone_id,
    'original_cents', coalesce(v_milestone.original_amount_cents, v_milestone.amount_cents),
    'adjusted_cents', v_new_amount,
    'variation_pct', (v_adjustment->>'variation_pct')::numeric
  );
END;
$$;


ALTER FUNCTION "public"."sf_apply_ipc_to_milestone"("p_milestone_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_attach_cert_doc"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_mime_type" "text", "p_size_bytes" bigint DEFAULT NULL::bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_cert public.milestones%ROWTYPE;
  v_user_role pact_party_role;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_cert FROM public.milestones WHERE id = p_cert_id;
  IF v_cert.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_cert.pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede adjuntar documento';
  END IF;

  IF v_cert.state NOT IN ('in_execution', 'ready_for_review', 'rejected_by_tech', 'info_requested') THEN
    RAISE EXCEPTION 'No se puede adjuntar documento en estado %', v_cert.state;
  END IF;

  UPDATE public.milestones
  SET detailed_doc_storage_path = p_storage_path,
      detailed_doc_sha256 = p_sha256,
      detailed_doc_mime_type = p_mime_type,
      detailed_doc_size_bytes = p_size_bytes
  WHERE id = p_cert_id;
END;
$$;


ALTER FUNCTION "public"."sf_attach_cert_doc"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_mime_type" "text", "p_size_bytes" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_attach_cert_invoice"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_invoice_number" "text", "p_size_bytes" bigint DEFAULT NULL::bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_cert public.milestones%ROWTYPE;
  v_user_role pact_party_role;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_cert FROM public.milestones WHERE id = p_cert_id;
  IF v_cert.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_cert.pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede adjuntar la factura';
  END IF;

  IF v_cert.state NOT IN ('in_execution', 'ready_for_review', 'rejected_by_tech', 'info_requested') THEN
    RAISE EXCEPTION 'No se puede adjuntar factura en estado %', v_cert.state;
  END IF;

  UPDATE public.milestones
  SET invoice_storage_path = p_storage_path,
      invoice_sha256 = p_sha256,
      invoice_number = p_invoice_number,
      invoice_size_bytes = p_size_bytes
  WHERE id = p_cert_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_cert.pact_id, 'invoice_attached',
    jsonb_build_object(
      'cert_id', p_cert_id,
      'invoice_number', p_invoice_number,
      'sha256', p_sha256
    ),
    v_user_id);
END;
$$;


ALTER FUNCTION "public"."sf_attach_cert_invoice"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_invoice_number" "text", "p_size_bytes" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_attach_cert_invoice"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_invoice_number" "text", "p_size_bytes" bigint) IS 'Sprint 4 · Adjunta factura del constructor (obligatoria desde v2.0).';



CREATE OR REPLACE FUNCTION "public"."sf_calc_ipc_adjustment"("p_base_month" "text", "p_current_month" "text" DEFAULT NULL::"text", "p_amount_cents" bigint DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_base_value numeric;
  v_current_value numeric;
  v_current_month text;
  v_variation_pct numeric;
  v_adjusted_cents bigint;
BEGIN
  v_current_month := coalesce(p_current_month, to_char(now(), 'YYYY-MM'));

  -- Obtener valor base
  SELECT index_value INTO v_base_value
  FROM public.ipc_indices WHERE year_month = p_base_month;

  IF v_base_value IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'IPC base not found for ' || p_base_month,
      'adjustment_pct', 0,
      'adjusted_cents', p_amount_cents
    );
  END IF;

  -- Obtener valor actual (buscar el más reciente si el mes actual no existe)
  SELECT index_value INTO v_current_value
  FROM public.ipc_indices
  WHERE year_month <= v_current_month
  ORDER BY year_month DESC
  LIMIT 1;

  IF v_current_value IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'No IPC data available',
      'adjustment_pct', 0,
      'adjusted_cents', p_amount_cents
    );
  END IF;

  -- Calcular variación
  v_variation_pct := round(((v_current_value - v_base_value) / v_base_value) * 100, 3);
  v_adjusted_cents := round(p_amount_cents * (1 + v_variation_pct / 100));

  RETURN jsonb_build_object(
    'base_month', p_base_month,
    'base_value', v_base_value,
    'current_month', v_current_month,
    'current_value', v_current_value,
    'variation_pct', v_variation_pct,
    'original_cents', p_amount_cents,
    'adjusted_cents', v_adjusted_cents
  );
END;
$$;


ALTER FUNCTION "public"."sf_calc_ipc_adjustment"("p_base_month" "text", "p_current_month" "text", "p_amount_cents" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_check_predeposit_deadlines"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_milestone   record;
  v_paused_ids  uuid[] := ARRAY[]::uuid[];
  v_recipients  uuid[];
  v_pact_title  text;
  v_actor_user  uuid;
BEGIN
  -- Buscamos certificaciones vencidas. predeposit_deadline_at lo escribe
  -- sf_create_certification_v21 (deadline = now() + 3 días por defecto).
  FOR v_milestone IN
    SELECT m.id, m.name, m.pact_id, m.predeposit_deadline_at,
           m.predeposit_received_cents, m.net_amount_cents,
           p.title AS pact_title, p.created_by_user_id
    FROM public.milestones m
    JOIN public.pacts p ON p.id = m.pact_id
    WHERE m.state = 'pending_predeposit'
      AND m.predeposit_deadline_at IS NOT NULL
      AND m.predeposit_deadline_at < now()
  LOOP
    -- Pasar a paused_no_predeposit (el trigger v2.1-aware ya acepta
    -- esta transición tras los quick wins).
    UPDATE public.milestones
    SET state = 'paused_no_predeposit',
        state_updated_at = now()
    WHERE id = v_milestone.id;

    v_paused_ids := array_append(v_paused_ids, v_milestone.id);
    v_actor_user := v_milestone.created_by_user_id;

    -- Evento + audit
    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_milestone.pact_id, 'milestone_paused_by_cron',
      jsonb_build_object(
        'milestone_id', v_milestone.id,
        'deadline', v_milestone.predeposit_deadline_at,
        'predeposit_received_cents', v_milestone.predeposit_received_cents,
        'net_amount_cents', v_milestone.net_amount_cents,
        'reason', 'predeposit_deadline_expired'
      ),
      v_actor_user);

    INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
    VALUES (v_actor_user, 'milestone_paused_by_cron', 'milestone', v_milestone.id,
      jsonb_build_object('deadline', v_milestone.predeposit_deadline_at));

    -- Notificación a TODAS las partes + miembros con notificaciones
    -- económicas (la paralización tiene impacto operativo y financiero).
    SELECT array_agg(user_id) INTO v_recipients
    FROM public.fn_notification_recipients(
      v_milestone.pact_id, NULL, true, NULL
    );

    PERFORM public.fn_create_notifications(
      p_user_ids        := v_recipients,
      p_notification_type := 'milestone_paused_no_predeposit',
      p_title           := 'Obra paralizada · ' || coalesce(v_milestone.name, 'Hito'),
      p_body            := 'La certificación de "' ||
                           coalesce(v_milestone.pact_title, 'la obra') ||
                           '" quedó paralizada porque el pre-depósito no se completó en plazo. ' ||
                           'El promotor puede reanudarla aportando el importe pendiente.',
      p_pact_id         := v_milestone.pact_id,
      p_milestone_id    := v_milestone.id,
      p_cta_url         := '/pacts/' || v_milestone.pact_id::text ||
                           '/milestones/' || v_milestone.id::text,
      p_priority        := 'high',
      p_idempotency_root := 'paused_no_predeposit:' || v_milestone.id::text
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'paused_count', array_length(v_paused_ids, 1),
    'paused_ids', coalesce(to_jsonb(v_paused_ids), '[]'::jsonb),
    'checked_at', now()
  );
END;
$$;


ALTER FUNCTION "public"."sf_check_predeposit_deadlines"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_check_predeposit_deadlines"() IS 'Sprint 5 chunk 6 · Job de paralización automática. Detecta hitos v2.1 con pre-depósito vencido y los pasa a paused_no_predeposit, notificando a las partes. Llamado por Edge Function periódica.';



CREATE OR REPLACE FUNCTION "public"."sf_check_quality_holdback"("p_milestone_id" "uuid", "p_pact_id" "uuid", "p_amount_cents" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_threshold    smallint;
  v_holdback_pct smallint;
  v_ai_score     smallint;
  v_holdback_amt bigint;
BEGIN
  -- Leer configuración
  SELECT (value)::smallint INTO v_threshold
  FROM public.app_settings WHERE key = 'quality_holdback_threshold';
  v_threshold := coalesce(v_threshold, 75);

  SELECT (value)::smallint INTO v_holdback_pct
  FROM public.app_settings WHERE key = 'quality_holdback_pct';
  v_holdback_pct := coalesce(v_holdback_pct, 15);

  -- Obtener último score IA del hito
  SELECT (ar.metadata->>'score_numeric')::smallint
  INTO v_ai_score
  FROM public.ai_runs ar
  WHERE ar.pact_id = p_pact_id
    AND ar.run_type = 'vision'
    AND ar.success = true
    AND ar.metadata->>'score_numeric' IS NOT NULL
    AND (ar.metadata->>'milestone_id') = p_milestone_id::text
  ORDER BY ar.created_at DESC
  LIMIT 1;

  -- Si no hay verificación IA, buscar en milestone_ai_verifications
  IF v_ai_score IS NULL THEN
    SELECT score INTO v_ai_score
    FROM public.milestone_ai_verifications
    WHERE milestone_id = p_milestone_id
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  -- Sin score IA → no retener (dar el beneficio de la duda)
  IF v_ai_score IS NULL THEN
    RETURN jsonb_build_object(
      'holdback', false,
      'reason', 'no_ai_score',
      'ai_score', NULL
    );
  END IF;

  -- Score >= umbral → pago completo
  IF v_ai_score >= v_threshold THEN
    RETURN jsonb_build_object(
      'holdback', false,
      'ai_score', v_ai_score,
      'threshold', v_threshold
    );
  END IF;

  -- Score < umbral → retener
  v_holdback_amt := (p_amount_cents * v_holdback_pct / 100);

  -- Registrar retención
  INSERT INTO public.quality_holdbacks (
    pact_id, milestone_id, amount_cents, ai_score,
    threshold_used, holdback_pct_used, state
  ) VALUES (
    p_pact_id, p_milestone_id, v_holdback_amt, v_ai_score,
    v_threshold, v_holdback_pct, 'held'
  )
  ON CONFLICT (milestone_id) DO UPDATE
    SET amount_cents = EXCLUDED.amount_cents,
        ai_score = EXCLUDED.ai_score,
        state = 'held';

  -- Actualizar hito
  UPDATE public.milestones
  SET quality_holdback_cents = v_holdback_amt,
      net_paid_cents = p_amount_cents - v_holdback_amt
  WHERE id = p_milestone_id;

  -- Acumular en pacto
  UPDATE public.pacts
  SET total_quality_holdback_cents = total_quality_holdback_cents + v_holdback_amt
  WHERE id = p_pact_id;

  RETURN jsonb_build_object(
    'holdback', true,
    'ai_score', v_ai_score,
    'threshold', v_threshold,
    'holdback_pct', v_holdback_pct,
    'holdback_cents', v_holdback_amt,
    'net_paid_cents', p_amount_cents - v_holdback_amt
  );
END;
$$;


ALTER FUNCTION "public"."sf_check_quality_holdback"("p_milestone_id" "uuid", "p_pact_id" "uuid", "p_amount_cents" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_constructor_create_cert"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text") RETURNS TABLE("out_cert_id" "uuid", "out_display_id" "text", "out_ordinal" smallint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_cert_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
  v_next_ordinal smallint;
  v_remaining_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'Esta RPC solo aplica a pacts v2';
  END IF;
  IF v_pact.state != 'in_execution' THEN
    RAISE EXCEPTION 'El pacto no está en ejecución (estado: %)', v_pact.state;
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede crear certificaciones';
  END IF;

  IF p_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El importe mínimo de una certificación es 500 €';
  END IF;

  -- Validar techo de presupuesto: lo certificable es total - ya pagado - ya en curso
  SELECT v_pact.total_amount_cents - v_pact.budget_consumed_cents -
    coalesce((SELECT sum(amount_cents) FROM public.milestones
              WHERE pact_id = p_pact_id AND state NOT IN ('paid')), 0)
  INTO v_remaining_cents;

  IF p_amount_cents > v_remaining_cents THEN
    RAISE EXCEPTION 'La certificación excede el presupuesto disponible (% €)', v_remaining_cents / 100;
  END IF;

  -- Calcular próximo ordinal
  SELECT coalesce(max(ordinal), 0) + 1 INTO v_next_ordinal
  FROM public.milestones WHERE pact_id = p_pact_id;

  -- Generar display_id único
  LOOP
    v_display_id := 'PS-CERT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.milestones WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.milestones (
    pact_id, display_id, ordinal, name, description,
    amount_cents, state, version, started_at
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal, p_name, p_description,
    p_amount_cents, 'in_execution', 1, now()
  )
  RETURNING id INTO v_cert_id;

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'certification_created',
    jsonb_build_object(
      'cert_id', v_cert_id,
      'ordinal', v_next_ordinal,
      'amount_cents', p_amount_cents,
      'name', p_name
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'certification_created', 'milestone', v_cert_id,
    jsonb_build_object('ordinal', v_next_ordinal, 'amount_cents', p_amount_cents));

  out_cert_id := v_cert_id;
  out_display_id := v_display_id;
  out_ordinal := v_next_ordinal;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."sf_constructor_create_cert"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_constructor_create_cert"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") IS 'Sprint 4 · Constructor crea certificación con ordinal correlativo. Valida techo de presupuesto disponible.';



CREATE OR REPLACE FUNCTION "public"."sf_constructor_create_cert_v21"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text") RETURNS TABLE("out_cert_id" "uuid", "out_display_id" "text", "out_ordinal" smallint, "out_amortization_cents" bigint, "out_net_amount_cents" bigint, "out_predeposit_deadline_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_cert_id uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
  v_next_ordinal smallint;
  v_remaining_cents bigint;
  v_amortization bigint;
  v_net bigint;
  v_deadline timestamptz;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;
  IF v_pact.model_version != 'v2.1' THEN
    RAISE EXCEPTION 'Esta RPC solo aplica a pacts v2.1';
  END IF;
  IF v_pact.state != 'in_execution' THEN
    RAISE EXCEPTION 'El pacto no está en ejecución (estado: %)', v_pact.state;
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede crear certificaciones';
  END IF;

  IF p_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El importe mínimo de una certificación es 500 €';
  END IF;

  SELECT v_pact.total_amount_cents - v_pact.budget_consumed_cents -
    coalesce((SELECT sum(amount_cents) FROM public.milestones
              WHERE pact_id = p_pact_id AND state NOT IN ('paid')), 0)
  INTO v_remaining_cents;

  IF p_amount_cents > v_remaining_cents THEN
    RAISE EXCEPTION 'La certificación excede el presupuesto disponible (% €)',
      v_remaining_cents / 100;
  END IF;

  v_amortization := (p_amount_cents * v_pact.deposit_required_pct / 100)::bigint;
  v_net := p_amount_cents - v_amortization;
  v_deadline := now() + interval '3 days';

  SELECT coalesce(max(ordinal), 0) + 1 INTO v_next_ordinal
  FROM public.milestones WHERE pact_id = p_pact_id;

  LOOP
    v_display_id := 'PS-CERT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.milestones WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.milestones (
    pact_id, display_id, ordinal, name, description,
    amount_cents, advance_amortization_cents,
    predeposit_deadline_at,
    state, version
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal, p_name, p_description,
    p_amount_cents, v_amortization,
    v_deadline,
    'pending_predeposit', 1
  )
  RETURNING id INTO v_cert_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'cert_v21_created',
    jsonb_build_object(
      'cert_id', v_cert_id,
      'ordinal', v_next_ordinal,
      'gross_cents', p_amount_cents,
      'amortization_cents', v_amortization,
      'net_cents', v_net,
      'predeposit_deadline_at', v_deadline
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'cert_v21_created', 'milestone', v_cert_id,
    jsonb_build_object('ordinal', v_next_ordinal, 'gross_cents', p_amount_cents));

  out_cert_id := v_cert_id;
  out_display_id := v_display_id;
  out_ordinal := v_next_ordinal;
  out_amortization_cents := v_amortization;
  out_net_amount_cents := v_net;
  out_predeposit_deadline_at := v_deadline;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."sf_constructor_create_cert_v21"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_constructor_create_cert_v21"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") IS 'v2.1 · Crea cert en pending_predeposit con reloj de 3 días. Calcula amortización del adelanto.';



CREATE OR REPLACE FUNCTION "public"."sf_constructor_edit_cert"("p_cert_id" "uuid", "p_name" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_amount_cents" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_cert public.milestones%ROWTYPE;
  v_user_role pact_party_role;
  v_snapshot jsonb;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_cert FROM public.milestones WHERE id = p_cert_id;
  IF v_cert.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_cert.pact_id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede editar la certificación';
  END IF;

  IF v_cert.state NOT IN ('rejected_by_tech', 'info_requested', 'in_execution') THEN
    RAISE EXCEPTION 'No se puede editar una certificación en estado %', v_cert.state;
  END IF;

  -- Snapshot de la versión actual en pact_events ANTES de modificar
  v_snapshot := jsonb_build_object(
    'cert_id', v_cert.id,
    'version_before', v_cert.version,
    'name_before', v_cert.name,
    'description_before', v_cert.description,
    'amount_cents_before', v_cert.amount_cents
  );

  -- Aplicar cambios
  UPDATE public.milestones
  SET
    name = coalesce(p_name, name),
    description = coalesce(p_description, description),
    amount_cents = coalesce(p_amount_cents, amount_cents),
    version = version + 1,
    state = CASE WHEN state IN ('rejected_by_tech', 'info_requested')
                 THEN 'in_execution'::milestone_state
                 ELSE state END
  WHERE id = p_cert_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_cert.pact_id, 'certification_edited', v_snapshot, v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'new_version', v_cert.version + 1,
    'new_state', 'in_execution'
  );
END;
$$;


ALTER FUNCTION "public"."sf_constructor_edit_cert"("p_cert_id" "uuid", "p_name" "text", "p_description" "text", "p_amount_cents" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_constructor_edit_cert"("p_cert_id" "uuid", "p_name" "text", "p_description" "text", "p_amount_cents" bigint) IS 'Sprint 4 · Constructor edita cert rechazada o pidiendo info. Incrementa version. Snapshot anterior en pact_events.';



CREATE OR REPLACE FUNCTION "public"."sf_count_unread_notifications"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid; v_user_id uuid; v_count int;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RETURN 0; END IF;
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RETURN 0; END IF;

  SELECT count(*)::int INTO v_count FROM public.notifications
  WHERE user_id = v_user_id AND channel = 'in_app' AND read_at IS NULL;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."sf_count_unread_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_create_acopio_milestone"("p_pact_id" "uuid", "p_name" "text", "p_total_cents" bigint, "p_items" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_pact_state text;
  v_next_ordinal smallint;
  v_milestone_id uuid;
  v_display_id text;
  v_item jsonb;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;

  IF v_user_role NOT IN ('promotor', 'constructor') THEN
    RAISE EXCEPTION 'Solo promotor o constructor pueden crear hitos de acopio';
  END IF;

  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state NOT IN ('in_execution', 'funded') THEN
    RAISE EXCEPTION 'El pacto debe estar en ejecución para crear acopio (estado: %)', v_pact_state;
  END IF;

  IF p_total_cents < 10000 THEN
    RAISE EXCEPTION 'El acopio mínimo es 100€ (10.000 céntimos)';
  END IF;

  -- Siguiente ordinal
  SELECT coalesce(max(ordinal), 0) + 1
  INTO v_next_ordinal
  FROM public.milestones
  WHERE pact_id = p_pact_id AND deleted_at IS NULL;

  -- Generar display_id
  v_display_id := 'PS-ACO-' || to_char(now(), 'YYYYMMDD') || '-' ||
    upper(substr(gen_random_uuid()::text, 1, 6));

  -- Crear hito de tipo acopio
  INSERT INTO public.milestones (
    pact_id, display_id, ordinal, name, amount_cents,
    category, state, state_updated_at
  ) VALUES (
    p_pact_id, v_display_id, v_next_ordinal, p_name, p_total_cents,
    'acopio', 'pending', now()
  )
  RETURNING id INTO v_milestone_id;

  -- Crear items de material si se proporcionaron
  IF jsonb_array_length(p_items) > 0 THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
      INSERT INTO public.acopio_items (
        milestone_id, pact_id, description, material_type, estimated_cents,
        supplier_name
      ) VALUES (
        v_milestone_id, p_pact_id,
        v_item->>'description',
        coalesce(v_item->>'material_type', 'generic'),
        (v_item->>'estimated_cents')::bigint,
        v_item->>'supplier_name'
      );
    END LOOP;
  END IF;

  -- Evento
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'acopio_created',
    jsonb_build_object(
      'milestone_id', v_milestone_id,
      'display_id', v_display_id,
      'total_cents', p_total_cents,
      'items_count', jsonb_array_length(p_items)
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'acopio_milestone_created', 'milestone', v_milestone_id,
    jsonb_build_object('pact_id', p_pact_id, 'total_cents', p_total_cents));

  RETURN jsonb_build_object(
    'milestone_id', v_milestone_id,
    'display_id', v_display_id,
    'ordinal', v_next_ordinal,
    'category', 'acopio',
    'items_created', jsonb_array_length(p_items)
  );
END;
$$;


ALTER FUNCTION "public"."sf_create_acopio_milestone"("p_pact_id" "uuid", "p_name" "text", "p_total_cents" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_create_organization"("p_legal_name" "text", "p_cif" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_org_type" "text" DEFAULT 'constructor'::"text") RETURNS TABLE("out_org_id" "uuid", "out_legal_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid; v_user_id uuid; v_org_id uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  IF p_org_type NOT IN ('constructor','tecnico','promotor','mixed') THEN
    RAISE EXCEPTION 'Tipo de organización inválido: %', p_org_type;
  END IF;
  IF p_org_type = 'promotor' THEN
    RAISE EXCEPTION 'Las organizaciones de promotor estarán disponibles en una versión posterior';
  END IF;
  IF length(trim(p_legal_name)) < 2 THEN
    RAISE EXCEPTION 'El nombre legal de la organización es obligatorio';
  END IF;
  IF EXISTS (SELECT 1 FROM public.organizations WHERE owner_user_id = v_user_id) THEN
    RAISE EXCEPTION 'Ya tienes una organización creada. En MVP solo se permite una por usuario.';
  END IF;

  INSERT INTO public.organizations (
    legal_name, cif, description, org_type, owner_user_id
  ) VALUES (
    trim(p_legal_name),
    nullif(trim(coalesce(p_cif, '')), ''),
    nullif(trim(coalesce(p_description, '')), ''),
    p_org_type::org_type,
    v_user_id
  ) RETURNING id INTO v_org_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_created', 'organization', v_org_id,
    jsonb_build_object('legal_name', trim(p_legal_name), 'org_type', p_org_type));

  out_org_id := v_org_id;
  out_legal_name := trim(p_legal_name);
  RETURN NEXT;
END; $$;


ALTER FUNCTION "public"."sf_create_organization"("p_legal_name" "text", "p_cif" "text", "p_description" "text", "p_org_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_create_pact_draft"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text", "p_pact_type" "text" DEFAULT 'obra_mayor'::"text", "p_obra_postal_code" "text" DEFAULT NULL::"text", "p_obra_city" "text" DEFAULT NULL::"text", "p_obra_province" "text" DEFAULT NULL::"text", "p_obra_type" "text" DEFAULT 'reforma_integral'::"text", "p_iva_rate_pct" numeric DEFAULT 21, "p_iva_included" boolean DEFAULT false, "p_estimated_start_date" "date" DEFAULT NULL::"date", "p_estimated_end_date" "date" DEFAULT NULL::"date", "p_obra_menor_declaration_accepted" boolean DEFAULT false) RETURNS TABLE("out_pact_id" "uuid", "out_display_id" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_user_role user_role;
  v_pact_id  uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.primary_role INTO v_user_id, v_user_role
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o el promotor pueden crear un pacto';
  END IF;

  IF p_pact_type NOT IN ('obra_mayor', 'obra_menor') THEN
    RAISE EXCEPTION 'Tipo de pacto inválido: %', p_pact_type;
  END IF;

  IF p_pact_type = 'obra_menor' AND NOT p_obra_menor_declaration_accepted THEN
    RAISE EXCEPTION 'Para obra menor debes aceptar la declaración responsable';
  END IF;

  -- Generar display_id único con reintentos. 6 dígitos = 1M combinaciones
  -- por día → colisión <1% incluso con miles de pacts/día.
  LOOP
    v_display_id := 'PS-PCT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');

    SELECT EXISTS(
      SELECT 1 FROM public.pacts WHERE display_id = v_display_id
    ) INTO v_exists;

    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar un display_id único tras 10 intentos';
    END IF;
  END LOOP;

  INSERT INTO public.pacts (
    display_id, title, description, pact_type,
    obra_address_line, obra_postal_code, obra_city, obra_province,
    obra_type, total_amount_cents, iva_rate_pct, iva_included,
    estimated_start_date, estimated_end_date,
    obra_menor_declaration_accepted_at, obra_menor_declaration_text_hash,
    state, funding_mode, platform_fee_pct, created_by_user_id
  ) VALUES (
    v_display_id, p_title, p_description, p_pact_type::pact_type,
    p_obra_address_line, p_obra_postal_code,
    coalesce(p_obra_city, p_obra_province), p_obra_province,
    p_obra_type, p_total_amount_cents, p_iva_rate_pct, p_iva_included,
    p_estimated_start_date, p_estimated_end_date,
    CASE WHEN p_pact_type = 'obra_menor' THEN now() ELSE NULL END,
    CASE WHEN p_pact_type = 'obra_menor' THEN 'sha256_obra_menor_v1' ELSE NULL END,
    'draft', 'fund_first',
    CASE WHEN p_pact_type = 'obra_menor' THEN 0.80 ELSE 1.00 END,
    v_user_id
  )
  RETURNING pacts.id INTO v_pact_id;

  INSERT INTO public.pact_parties (
    pact_id, user_id, role, invited_by_user_id, accepted_at,
    snapshot_full_name, snapshot_email
  )
  SELECT v_pact_id, v_user_id, (v_user_role::text)::pact_party_role,
         v_user_id, now(),
         u.full_name, u.email
  FROM public.users u WHERE u.id = v_user_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_draft_created', 'pact', v_pact_id,
    jsonb_build_object('display_id', v_display_id, 'pact_type', p_pact_type));

  out_pact_id := v_pact_id;
  out_display_id := v_display_id;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."sf_create_pact_draft"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_obra_menor_declaration_accepted" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_create_pact_v2"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text", "p_pact_type" "text" DEFAULT 'obra_mayor'::"text", "p_obra_postal_code" "text" DEFAULT NULL::"text", "p_obra_city" "text" DEFAULT NULL::"text", "p_obra_province" "text" DEFAULT NULL::"text", "p_obra_type" "text" DEFAULT 'reforma_integral'::"text", "p_iva_rate_pct" numeric DEFAULT 21, "p_iva_included" boolean DEFAULT false, "p_estimated_start_date" "date" DEFAULT NULL::"date", "p_estimated_end_date" "date" DEFAULT NULL::"date", "p_deposit_required_pct" numeric DEFAULT 30, "p_certification_frequency" "text" DEFAULT NULL::"text", "p_obra_menor_declaration_accepted" boolean DEFAULT false) RETURNS TABLE("out_pact_id" "uuid", "out_display_id" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_user_role user_role;
  v_pact_id  uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.primary_role INTO v_user_id, v_user_role
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o el promotor pueden crear un pacto';
  END IF;

  IF p_pact_type NOT IN ('obra_mayor', 'obra_menor') THEN
    RAISE EXCEPTION 'Tipo de pacto inválido: %', p_pact_type;
  END IF;

  IF p_deposit_required_pct NOT BETWEEN 15 AND 40 THEN
    RAISE EXCEPTION 'El depósito debe estar entre el 15%% y el 40%% (recibido: %%%)', p_deposit_required_pct;
  END IF;

  IF p_total_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El presupuesto mínimo del pacto es 500 €';
  END IF;

  IF p_pact_type = 'obra_menor' AND NOT p_obra_menor_declaration_accepted THEN
    RAISE EXCEPTION 'Para obra menor debes aceptar la declaración responsable';
  END IF;

  -- Generar display_id único con reintentos
  LOOP
    v_display_id := 'PS-PCT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.pacts WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.pacts (
    display_id, title, description, pact_type,
    obra_address_line, obra_postal_code, obra_city, obra_province,
    obra_type, total_amount_cents, iva_rate_pct, iva_included,
    estimated_start_date, estimated_end_date,
    obra_menor_declaration_accepted_at, obra_menor_declaration_text_hash,
    state, funding_mode, platform_fee_pct, created_by_user_id,
    -- Campos v2.0
    deposit_required_pct,
    certification_frequency_text,
    model_version
  ) VALUES (
    v_display_id, p_title, p_description, p_pact_type::pact_type,
    p_obra_address_line, p_obra_postal_code,
    coalesce(p_obra_city, p_obra_province), p_obra_province,
    p_obra_type, p_total_amount_cents, p_iva_rate_pct, p_iva_included,
    p_estimated_start_date, p_estimated_end_date,
    CASE WHEN p_pact_type = 'obra_menor' THEN now() ELSE NULL END,
    CASE WHEN p_pact_type = 'obra_menor' THEN 'sha256_obra_menor_v2' ELSE NULL END,
    'draft', 'fund_first',
    CASE WHEN p_pact_type = 'obra_menor' THEN 0.80 ELSE 1.00 END,
    v_user_id,
    p_deposit_required_pct,
    p_certification_frequency,
    'v2'
  )
  RETURNING pacts.id INTO v_pact_id;

  -- Creador como primera parte
  INSERT INTO public.pact_parties (
    pact_id, user_id, role, invited_by_user_id, accepted_at,
    snapshot_full_name, snapshot_email
  )
  SELECT
    v_pact_id, v_user_id,
    (v_user_role::text)::pact_party_role,
    v_user_id, now(),
    u.full_name, u.email
  FROM public.users u WHERE u.id = v_user_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_v2_created', 'pact', v_pact_id,
    jsonb_build_object(
      'display_id', v_display_id,
      'pact_type', p_pact_type,
      'deposit_pct', p_deposit_required_pct,
      'total_cents', p_total_amount_cents
    ));

  out_pact_id := v_pact_id;
  out_display_id := v_display_id;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."sf_create_pact_v2"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_deposit_required_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_create_pact_v2"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_deposit_required_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) IS 'Sprint 4 · Crea pact v2 sin hitos predefinidos. Acepta deposit_required_pct y certification_frequency. Marca model_version=v2.';



CREATE OR REPLACE FUNCTION "public"."sf_create_pact_v21"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text" DEFAULT NULL::"text", "p_pact_type" "text" DEFAULT 'obra_mayor'::"text", "p_obra_postal_code" "text" DEFAULT NULL::"text", "p_obra_city" "text" DEFAULT NULL::"text", "p_obra_province" "text" DEFAULT NULL::"text", "p_obra_type" "text" DEFAULT 'reforma_integral'::"text", "p_iva_rate_pct" numeric DEFAULT 10, "p_iva_included" boolean DEFAULT true, "p_estimated_start_date" "date" DEFAULT NULL::"date", "p_estimated_end_date" "date" DEFAULT NULL::"date", "p_advance_pct" numeric DEFAULT 30, "p_advance_reserve_pct" numeric DEFAULT 10, "p_certification_frequency" "text" DEFAULT NULL::"text", "p_obra_menor_declaration_accepted" boolean DEFAULT false) RETURNS TABLE("out_pact_id" "uuid", "out_display_id" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_user_role user_role;
  v_pact_id  uuid;
  v_display_id text;
  v_attempts int := 0;
  v_exists boolean;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.primary_role INTO v_user_id, v_user_role
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o el promotor pueden crear un pacto';
  END IF;

  IF p_pact_type NOT IN ('obra_mayor', 'obra_menor') THEN
    RAISE EXCEPTION 'Tipo de pacto inválido: %', p_pact_type;
  END IF;

  IF p_advance_pct < 10 OR p_advance_pct > 40 THEN
    RAISE EXCEPTION 'El adelanto debe estar entre 10%% y 40%% (recibido: %%%)', p_advance_pct;
  END IF;

  IF p_advance_reserve_pct < 0 OR p_advance_reserve_pct > 20 THEN
    RAISE EXCEPTION 'La reserva debe estar entre 0%% y 20%% (recibido: %%%)', p_advance_reserve_pct;
  END IF;

  IF p_advance_reserve_pct > p_advance_pct THEN
    RAISE EXCEPTION 'La reserva (%%%) no puede ser mayor que el adelanto total (%%%)',
      p_advance_reserve_pct, p_advance_pct;
  END IF;

  IF p_total_amount_cents < 50000 THEN
    RAISE EXCEPTION 'El presupuesto mínimo del pacto es 500 €';
  END IF;

  IF p_pact_type = 'obra_menor' AND NOT p_obra_menor_declaration_accepted THEN
    RAISE EXCEPTION 'Para obra menor debes aceptar la declaración responsable';
  END IF;

  LOOP
    v_display_id := 'PS-PCT-' || to_char(now(), 'YYYYMMDD') || '-' ||
      lpad(floor(random() * 1000000)::int::text, 6, '0');
    SELECT EXISTS(SELECT 1 FROM public.pacts WHERE display_id = v_display_id) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempts := v_attempts + 1;
    IF v_attempts >= 10 THEN
      RAISE EXCEPTION 'No se pudo generar display_id único';
    END IF;
  END LOOP;

  INSERT INTO public.pacts (
    display_id, title, description, pact_type,
    obra_address_line, obra_postal_code, obra_city, obra_province,
    obra_type, total_amount_cents, iva_rate_pct, iva_included,
    estimated_start_date, estimated_end_date,
    obra_menor_declaration_accepted_at, obra_menor_declaration_text_hash,
    state, funding_mode, platform_fee_pct, created_by_user_id,
    deposit_required_pct,
    advance_reserve_pct,
    advance_released_cents,
    advance_outstanding_cents,
    certification_frequency_text,
    model_version
  ) VALUES (
    v_display_id, p_title, p_description, p_pact_type::pact_type,
    p_obra_address_line, p_obra_postal_code,
    coalesce(p_obra_city, p_obra_province), p_obra_province,
    p_obra_type, p_total_amount_cents, p_iva_rate_pct, p_iva_included,
    p_estimated_start_date, p_estimated_end_date,
    CASE WHEN p_pact_type = 'obra_menor' THEN now() ELSE NULL END,
    CASE WHEN p_pact_type = 'obra_menor' THEN 'sha256_obra_menor_v21' ELSE NULL END,
    'draft', 'fund_first',
    CASE WHEN p_pact_type = 'obra_menor' THEN 0.80 ELSE 1.00 END,
    v_user_id,
    p_advance_pct,
    p_advance_reserve_pct,
    0,
    0,
    p_certification_frequency,
    'v2.1'
  )
  RETURNING pacts.id INTO v_pact_id;

  INSERT INTO public.pact_parties (
    pact_id, user_id, role, invited_by_user_id, accepted_at,
    snapshot_full_name, snapshot_email
  )
  SELECT
    v_pact_id, v_user_id,
    (v_user_role::text)::pact_party_role,
    v_user_id, now(),
    u.full_name, u.email
  FROM public.users u WHERE u.id = v_user_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_v21_created', 'pact', v_pact_id,
    jsonb_build_object(
      'display_id', v_display_id,
      'pact_type', p_pact_type,
      'advance_pct', p_advance_pct,
      'reserve_pct', p_advance_reserve_pct,
      'total_cents', p_total_amount_cents
    ));

  out_pact_id := v_pact_id;
  out_display_id := v_display_id;
  RETURN NEXT;
END;
$$;


ALTER FUNCTION "public"."sf_create_pact_v21"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_advance_pct" numeric, "p_advance_reserve_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_create_pact_v21"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_advance_pct" numeric, "p_advance_reserve_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) IS 'v2.1 · Crea pact con Adelanto (10-40) + reserva fija. model_version=v2.1.';



CREATE OR REPLACE FUNCTION "public"."sf_delete_my_account"("p_reason" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_active_pacts int;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT id INTO v_user_id
  FROM public.users
  WHERE auth_provider_id = v_auth_uid::text
    AND deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado o ya eliminado';
  END IF;

  -- Verificar que no tenga pactos activos (no puede borrar cuenta con
  -- compromisos legales en curso)
  SELECT count(*) INTO v_active_pacts
  FROM public.pact_parties pp
  JOIN public.pacts p ON p.id = pp.pact_id
  WHERE pp.user_id = v_user_id
    AND p.state IN ('inviting', 'signing', 'signed', 'funded',
                    'in_execution', 'disputed', 'suspended');

  IF v_active_pacts > 0 THEN
    RAISE EXCEPTION 'No puedes borrar tu cuenta con % pactos activos. Cierra o cancela los pactos primero.', v_active_pacts;
  END IF;

  -- Soft delete
  UPDATE public.users SET deleted_at = now() WHERE id = v_user_id;

  -- Audit
  INSERT INTO public.audit_log(actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (
    v_user_id, 'account_deleted', 'user', v_user_id,
    jsonb_build_object('reason', p_reason, 'mode', 'soft_delete')
  );

  RETURN v_user_id;
END;
$$;


ALTER FUNCTION "public"."sf_delete_my_account"("p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_delete_my_account"("p_reason" "text") IS 'RGPD · derecho de supresión. Soft delete + audit. Hard delete + anonimización por job tras plazos legales.';



CREATE OR REPLACE FUNCTION "public"."sf_delete_pact_message"("p_message_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.pact_messages
     SET deleted_at = coalesce(deleted_at, now())
   WHERE id = p_message_id
     AND sender_user_id = v_user_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mensaje no encontrado o no eres el autor';
  END IF;
END;
$$;


ALTER FUNCTION "public"."sf_delete_pact_message"("p_message_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_deposit_dispute_escrow"("p_milestone_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_escrow record;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT de.*, m.pact_id
  INTO v_escrow
  FROM public.dispute_escrows de
  JOIN public.milestones m ON m.id = de.milestone_id
  WHERE de.milestone_id = p_milestone_id;

  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'No hay escrow de disputa para este hito';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_escrow.pact_id AND user_id = v_user_id;

  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede depositar el escrow de disputa';
  END IF;

  IF v_escrow.state != 'pending_deposit' THEN
    RAISE EXCEPTION 'El escrow ya fue depositado (estado: %)', v_escrow.state;
  END IF;

  -- Registrar depósito (mock — en producción va vía Mangopay)
  UPDATE public.dispute_escrows
  SET state = 'deposited', deposited_at = now()
  WHERE id = v_escrow.id;

  -- Incrementar el depósito del pacto
  UPDATE public.pacts
  SET deposit_current_cents = deposit_current_cents + v_escrow.escrow_amount_cents
  WHERE id = v_escrow.pact_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_escrow.pact_id, 'dispute_escrow_deposited',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'escrow_cents', v_escrow.escrow_amount_cents
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'dispute_escrow_deposited', 'dispute_escrow', v_escrow.id,
    jsonb_build_object('amount_cents', v_escrow.escrow_amount_cents));

  RETURN jsonb_build_object(
    'success', true,
    'escrow_cents', v_escrow.escrow_amount_cents,
    'state', 'deposited'
  );
END;
$$;


ALTER FUNCTION "public"."sf_deposit_dispute_escrow"("p_milestone_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_finalize_pact_draft"("p_pact_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_total_milestones bigint;
  v_total_milestones_amount bigint;
  v_party_count int;
  v_required_parties int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;

  IF v_pact.id IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact.created_by_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede finalizar el pacto';
  END IF;
  IF v_pact.state != 'draft' THEN
    RAISE EXCEPTION 'El pacto no está en estado draft';
  END IF;

  -- Validar que tiene hitos y suman el total
  SELECT count(*), coalesce(sum(amount_cents), 0)
  INTO v_total_milestones, v_total_milestones_amount
  FROM public.milestones WHERE pact_id = p_pact_id;

  IF v_total_milestones < 1 THEN
    RAISE EXCEPTION 'El pacto debe tener al menos 1 hito';
  END IF;

  IF v_total_milestones_amount != v_pact.total_amount_cents THEN
    RAISE EXCEPTION 'La suma de hitos (%) no coincide con el total del pacto (%)',
      v_total_milestones_amount, v_pact.total_amount_cents;
  END IF;

  -- Validar partes: obra_mayor=3, obra_menor=2
  v_required_parties := CASE WHEN v_pact.pact_type = 'obra_mayor' THEN 3 ELSE 2 END;
  SELECT count(*) INTO v_party_count FROM public.pact_parties WHERE pact_id = p_pact_id;

  IF v_party_count != v_required_parties THEN
    RAISE EXCEPTION 'Se requieren % partes para % (actual: %)',
      v_required_parties, v_pact.pact_type, v_party_count;
  END IF;

  -- Transicionar a 'inviting' (las partes que no tienen cuenta recibirán email)
  UPDATE public.pacts SET state = 'inviting' WHERE id = p_pact_id;

  -- Audit
  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_caller_id, 'pact_finalized', 'pact', p_pact_id);

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_finalized',
    jsonb_build_object(
      'total_amount_cents', v_pact.total_amount_cents,
      'milestones', v_total_milestones,
      'parties', v_party_count
    ),
    v_caller_id);

  RETURN p_pact_id;
END;
$$;


ALTER FUNCTION "public"."sf_finalize_pact_draft"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_finalize_pact_draft"("p_pact_id" "uuid") IS 'Valida draft (hitos suman total, partes correctas) y transiciona a inviting.';



CREATE OR REPLACE FUNCTION "public"."sf_finalize_pact_v2"("p_pact_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_party_count int;
  v_required_parties int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;

  IF v_pact.id IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact.created_by_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede finalizar el pacto';
  END IF;
  IF v_pact.state != 'draft' THEN
    RAISE EXCEPTION 'El pacto no está en estado draft (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'sf_finalize_pact_v2 solo aplica a pacts v2. Usa sf_finalize_pact_draft para v1.';
  END IF;

  v_required_parties := CASE WHEN v_pact.pact_type = 'obra_mayor' THEN 3 ELSE 2 END;
  SELECT count(*) INTO v_party_count FROM public.pact_parties WHERE pact_id = p_pact_id;

  IF v_party_count != v_required_parties THEN
    RAISE EXCEPTION 'Se requieren % partes para % (actual: %)',
      v_required_parties, v_pact.pact_type, v_party_count;
  END IF;

  UPDATE public.pacts SET state = 'inviting' WHERE id = p_pact_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_caller_id, 'pact_v2_finalized', 'pact', p_pact_id);

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_finalized',
    jsonb_build_object(
      'model_version', 'v2',
      'total_amount_cents', v_pact.total_amount_cents,
      'deposit_required_pct', v_pact.deposit_required_pct,
      'parties', v_party_count
    ),
    v_caller_id);

  RETURN p_pact_id;
END;
$$;


ALTER FUNCTION "public"."sf_finalize_pact_v2"("p_pact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_finalize_pact_v21"("p_pact_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_party_count int;
  v_required_parties int;
BEGIN
  v_auth_uid := auth.uid();
  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;

  IF v_pact.id IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact.created_by_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede finalizar el pacto';
  END IF;
  IF v_pact.state != 'draft' THEN
    RAISE EXCEPTION 'El pacto no está en estado draft (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2.1' THEN
    RAISE EXCEPTION 'sf_finalize_pact_v21 solo aplica a pacts v2.1';
  END IF;

  v_required_parties := CASE WHEN v_pact.pact_type = 'obra_mayor' THEN 3 ELSE 2 END;
  SELECT count(*) INTO v_party_count FROM public.pact_parties WHERE pact_id = p_pact_id;

  IF v_party_count != v_required_parties THEN
    RAISE EXCEPTION 'Se requieren % partes para % (actual: %)',
      v_required_parties, v_pact.pact_type, v_party_count;
  END IF;

  UPDATE public.pacts SET state = 'inviting' WHERE id = p_pact_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id)
  VALUES (v_caller_id, 'pact_v21_finalized', 'pact', p_pact_id);

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_finalized',
    jsonb_build_object(
      'model_version', 'v2.1',
      'total_amount_cents', v_pact.total_amount_cents,
      'advance_pct', v_pact.deposit_required_pct,
      'reserve_pct', v_pact.advance_reserve_pct
    ),
    v_caller_id);

  RETURN p_pact_id;
END;
$$;


ALTER FUNCTION "public"."sf_finalize_pact_v21"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_finalize_pact_v21"("p_pact_id" "uuid") IS 'v2.1 · Pasa de draft a inviting. Valida partes según pact_type.';



CREATE OR REPLACE FUNCTION "public"."sf_get_dashboard_data"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_user_role text;
  v_in_custody bigint;
  v_active_works int;
  v_new_this_month int;
  v_next_release jsonb;
  v_urgent_tasks jsonb;
  v_active_pacts jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.primary_role::text INTO v_user_id, v_user_role
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- En custodia
  SELECT coalesce(sum(p.deposit_current_cents), 0)
  INTO v_in_custody
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.state IN ('funded','in_execution','paused_pending_tech','disputed');

  -- Obras activas
  SELECT count(*) INTO v_active_works
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.state IN (
      'inviting','signing','signed','funded',
      'in_execution','paused_pending_tech','disputed'
    );

  -- Nuevas este mes
  SELECT count(*) INTO v_new_this_month
  FROM public.pacts p
  JOIN public.pact_parties pp ON pp.pact_id = p.id
  WHERE pp.user_id = v_user_id
    AND p.created_at >= date_trunc('month', now());

  -- Próxima liberación: certificación/hito en cualquier estado posterior
  -- a la validación pero aún no pagado.
  SELECT jsonb_build_object(
    'amount_cents', m.amount_cents,
    'target_date', m.target_date,
    'pact_id', m.pact_id,
    'pact_title', p.title,
    'milestone_name', m.name,
    'ordinal', m.ordinal
  )
  INTO v_next_release
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  JOIN public.pact_parties pp ON pp.pact_id = m.pact_id
  WHERE pp.user_id = v_user_id
    AND m.state IN ('approved_by_tech','awaiting_promotor')
  ORDER BY
    coalesce(m.target_date, m.state_updated_at::date) ASC,
    m.ordinal ASC
  LIMIT 1;

  -- Tareas urgentes
  WITH urgents AS (
    SELECT
      'addendum_sign'::text     AS kind,
      ('Firmar anexo · ' || a.title) AS title,
      p.title                    AS subtitle,
      p.id                       AS pact_id,
      'URGENTE'::text            AS badge_label,
      a.created_at               AS sort_at
    FROM public.pact_addendums a
    JOIN public.pacts p ON p.id = a.pact_id
    JOIN public.pact_parties pp ON pp.pact_id = a.pact_id AND pp.user_id = v_user_id
    WHERE a.state IN ('proposed','signing')
      AND CASE pp.role::text
        WHEN 'promotor'    THEN a.signed_at_promotor IS NULL
        WHEN 'constructor' THEN a.signed_at_constructor IS NULL
        WHEN 'tecnico'     THEN a.signed_at_tecnico IS NULL
        ELSE false
      END

    UNION ALL

    SELECT
      'contract_sign'::text     AS kind,
      'Firmar contrato'::text    AS title,
      p.title                    AS subtitle,
      p.id                       AS pact_id,
      'URGENTE'::text            AS badge_label,
      pp.accepted_at             AS sort_at
    FROM public.pacts p
    JOIN public.pact_parties pp ON pp.pact_id = p.id AND pp.user_id = v_user_id
    WHERE p.state = 'signing'
      AND pp.accepted_at IS NOT NULL
      AND pp.signed_at IS NULL

    UNION ALL

    SELECT
      'accept_invite'::text     AS kind,
      'Aceptar invitación'::text AS title,
      p.title                    AS subtitle,
      p.id                       AS pact_id,
      'NUEVO'::text              AS badge_label,
      pp.invited_at              AS sort_at
    FROM public.pacts p
    JOIN public.pact_parties pp ON pp.pact_id = p.id AND pp.user_id = v_user_id
    WHERE p.state = 'inviting'
      AND pp.accepted_at IS NULL
  )
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'kind', u.kind,
      'title', u.title,
      'subtitle', u.subtitle,
      'pact_id', u.pact_id,
      'badge_label', u.badge_label
    )
    ORDER BY u.sort_at DESC
  ), '[]'::jsonb)
  INTO v_urgent_tasks
  FROM (
    SELECT * FROM urgents ORDER BY sort_at DESC LIMIT 5
  ) u;

  -- Obras activas
  WITH active AS (
    SELECT
      p.id, p.display_id, p.title, p.state::text AS state,
      coalesce(p.obra_city, p.obra_address_line) AS city,
      p.total_amount_cents, p.budget_consumed_cents,
      p.deposit_required_pct, p.deposit_current_cents,
      coalesce(p.model_version, 'v1') AS model_version,
      p.state_updated_at
    FROM public.pacts p
    JOIN public.pact_parties pp ON pp.pact_id = p.id AND pp.user_id = v_user_id
    WHERE p.state IN (
      'inviting','signing','signed','funded',
      'in_execution','paused_pending_tech','disputed'
    )
    ORDER BY p.state_updated_at DESC
    LIMIT 5
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'display_id', a.display_id,
    'title', a.title,
    'state', a.state,
    'city', a.city,
    'total_amount_cents', a.total_amount_cents,
    'budget_consumed_cents', a.budget_consumed_cents,
    'deposit_current_cents', a.deposit_current_cents,
    'progress_pct', CASE
      WHEN a.total_amount_cents > 0
        THEN round((a.budget_consumed_cents::numeric / a.total_amount_cents) * 100)::int
      ELSE 0
    END,
    'model_version', a.model_version
  )), '[]'::jsonb)
  INTO v_active_pacts
  FROM active a;

  RETURN jsonb_build_object(
    'role', v_user_role,
    'in_custody_cents', v_in_custody,
    'active_works', v_active_works,
    'new_works_this_month', v_new_this_month,
    'next_release', v_next_release,
    'urgent_tasks', v_urgent_tasks,
    'active_pacts', v_active_pacts
  );
END;
$$;


ALTER FUNCTION "public"."sf_get_dashboard_data"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_get_dashboard_data"() IS 'Sprint 4 extra hotfix · Estados de milestone corregidos a los reales (approved_by_tech, awaiting_promotor).';



CREATE OR REPLACE FUNCTION "public"."sf_get_invite_preview"("p_token" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_member public.organization_members%ROWTYPE;
  v_org    public.organizations%ROWTYPE;
  v_inviter_name text;
BEGIN
  SELECT * INTO v_member FROM public.organization_members
  WHERE invitation_token = p_token AND state = 'invited';

  IF v_member.id IS NULL THEN
    RETURN jsonb_build_object('valid', false);
  END IF;

  SELECT * INTO v_org FROM public.organizations
  WHERE id = v_member.organization_id;

  SELECT full_name INTO v_inviter_name FROM public.users
  WHERE id = v_member.invited_by_user_id;

  RETURN jsonb_build_object(
    'valid', true,
    'member_id', v_member.id,
    'invited_email', v_member.invited_email,
    'full_name', v_member.full_name,
    'can_view_economics', v_member.can_view_economics,
    'org_name', coalesce(v_org.trade_name, v_org.legal_name),
    'org_type', v_org.org_type,
    'inviter_name', v_inviter_name
  );
END;
$$;


ALTER FUNCTION "public"."sf_get_invite_preview"("p_token" "uuid") OWNER TO "postgres";


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


ALTER FUNCTION "public"."sf_get_milestone_detail"("p_milestone_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_get_milestone_detail"("p_milestone_id" "uuid") IS 'Detalle de hito + evidencias + última validación (rationale) en JSON. Acceso directo o vía organización; económicos gated.';



CREATE OR REPLACE FUNCTION "public"."sf_get_monthly_series"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_billing jsonb; v_flow jsonb; v_validations jsonb;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  WITH months AS (
    SELECT date_trunc('month', now()) - (interval '1 month' * g) AS m
    FROM generate_series(5, 0, -1) AS g
  ),
  cobrado AS (
    SELECT date_trunc('month', ms.paid_at) AS m, sum(ms.amount_cents) AS v
    FROM public.milestones ms
    JOIN public.pact_parties pp ON pp.pact_id = ms.pact_id
      AND pp.user_id = v_user_id AND pp.role = 'constructor'
    WHERE ms.paid_at IS NOT NULL
      AND ms.paid_at >= date_trunc('month', now()) - interval '5 months'
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'month', to_char(months.m, 'YYYY-MM'),
    'value', coalesce(cobrado.v, 0)
  ) ORDER BY months.m)
  INTO v_billing
  FROM months LEFT JOIN cobrado ON cobrado.m = months.m;

  WITH months AS (
    SELECT date_trunc('month', now()) - (interval '1 month' * g) AS m
    FROM generate_series(5, 0, -1) AS g
  ),
  pagado AS (
    SELECT date_trunc('month', ms.paid_at) AS m, sum(ms.amount_cents) AS v
    FROM public.milestones ms
    JOIN public.pact_parties pp ON pp.pact_id = ms.pact_id
      AND pp.user_id = v_user_id AND pp.role = 'promotor'
    WHERE ms.paid_at IS NOT NULL
      AND ms.paid_at >= date_trunc('month', now()) - interval '5 months'
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'month', to_char(months.m, 'YYYY-MM'),
    'value', coalesce(pagado.v, 0)
  ) ORDER BY months.m)
  INTO v_flow
  FROM months LEFT JOIN pagado ON pagado.m = months.m;

  WITH months AS (
    SELECT date_trunc('month', now()) - (interval '1 month' * g) AS m
    FROM generate_series(5, 0, -1) AS g
  ),
  vals AS (
    SELECT date_trunc('month', mv.decision_at) AS m, count(*) AS v
    FROM public.milestone_validations mv
    WHERE mv.validator_user_id = v_user_id
      AND mv.decision_at >= date_trunc('month', now()) - interval '5 months'
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object(
    'month', to_char(months.m, 'YYYY-MM'),
    'value', coalesce(vals.v, 0)
  ) ORDER BY months.m)
  INTO v_validations
  FROM months LEFT JOIN vals ON vals.m = months.m;

  RETURN jsonb_build_object(
    'billing', v_billing,
    'fund_flow', v_flow,
    'validations', v_validations
  );
END;
$$;


ALTER FUNCTION "public"."sf_get_monthly_series"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_get_monthly_series"() IS 'Series mensuales (6 meses) para los charts de la home: cobrado (constructor), pagado (promotor) y validaciones (técnico) del usuario autenticado.';



CREATE OR REPLACE FUNCTION "public"."sf_get_my_profile"() RETURNS TABLE("id" "uuid", "full_name" "text", "email" "text", "primary_role" "public"."user_role", "kyc_status" "public"."kyc_status", "organization_id" "uuid", "created_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT u.id, u.full_name, u.email, u.primary_role, u.kyc_status,
         u.organization_id, u.created_at
  FROM public.users u
  WHERE u.auth_provider_id = (auth.uid())::text
    AND u.deleted_at IS NULL;
$$;


ALTER FUNCTION "public"."sf_get_my_profile"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_get_my_profile"() IS 'Devuelve el perfil del usuario autenticado actual. Devuelve 0 filas si no existe perfil.';



CREATE OR REPLACE FUNCTION "public"."sf_get_my_profile_extended"() RETURNS TABLE("id" "uuid", "full_name" "text", "email" "text", "phone_e164" "text", "primary_role" "public"."user_role", "national_id" "text", "province" "text", "profession" "text", "colegio" "text", "num_colegiacion" "text", "organization_id" "uuid", "organization_name" "text", "organization_cif" "text", "kyc_status" "public"."kyc_status", "kyc_verified_at" timestamp with time zone, "kyc_provider" "text", "country_iso" character, "locale" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    u.id, u.full_name, u.email, u.phone_e164,
    u.primary_role, u.national_id, u.province,
    u.profession, u.colegio, u.num_colegiacion,
    u.organization_id, o.legal_name, o.cif,
    u.kyc_status, u.kyc_verified_at, u.kyc_provider,
    u.country_iso,
    u.locale,
    u.created_at
  FROM public.users u
  LEFT JOIN public.organizations o ON o.id = u.organization_id
  WHERE u.auth_provider_id = (auth.uid())::text
    AND u.deleted_at IS NULL;
$$;


ALTER FUNCTION "public"."sf_get_my_profile_extended"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_get_org_members"("p_org_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid  uuid;
  v_user_id   uuid;
  v_is_member boolean;
  v_result    jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_org_id AND user_id = v_user_id AND state = 'active'
  ) INTO v_is_member;
  IF NOT v_is_member THEN
    RAISE EXCEPTION 'No tienes acceso a esta organización';
  END IF;

  SELECT jsonb_build_object(
    'members', coalesce(jsonb_agg(jsonb_build_object(
      'id', om.id,
      'user_id', om.user_id,
      'role', om.role,
      'state', om.state,
      'invited_email', om.invited_email,
      'full_name', coalesce(u.full_name, om.full_name),
      'email', coalesce(u.email, om.invited_email),
      'can_view_economics', om.can_view_economics,
      'receive_notifications', om.receive_notifications,
      'receive_economic_notifications', om.receive_economic_notifications,
      'invited_at', om.invited_at,
      'accepted_at', om.accepted_at,
      'is_me', (om.user_id = v_user_id)
    ) ORDER BY
      CASE om.role WHEN 'owner' THEN 1 ELSE 2 END,
      om.accepted_at NULLS LAST,
      om.invited_at
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.organization_members om
  LEFT JOIN public.users u ON u.id = om.user_id
  WHERE om.organization_id = p_org_id
    AND om.state IN ('invited', 'active');

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."sf_get_org_members"("p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_get_pact_ai_context"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_in_pact boolean;
  v_context jsonb;
BEGIN
  -- Validar pertenencia
  SELECT public.fn_user_in_pact(p_pact_id) INTO v_in_pact;
  IF NOT v_in_pact THEN
    RAISE EXCEPTION 'No autorizado: usuario no pertenece al pacto %', p_pact_id
      USING ERRCODE = '42501';
  END IF;

  SELECT id INTO v_user_id FROM public.users
  WHERE auth_provider_id = auth.uid()::text AND deleted_at IS NULL;

  -- Construir el contexto
  SELECT jsonb_build_object(
    'pact', (
      SELECT jsonb_build_object(
        'id', p.id,
        'display_id', p.display_id,
        'title', p.title,
        'state', p.state,
        'total_amount_eur', p.total_amount_cents / 100.0,
        'currency', 'EUR',
        'budget_consumed_eur', coalesce(p.budget_consumed_cents, 0) / 100.0,
        'deposit_current_eur', coalesce(p.deposit_current_cents, 0) / 100.0,
        'advance_released_eur', coalesce(p.advance_released_cents, 0) / 100.0,
        'advance_outstanding_eur', coalesce(p.advance_outstanding_cents, 0) / 100.0,
        'is_demo_only', p.is_demo_only,
        'model_version', p.model_version
      )
      FROM public.pacts p WHERE p.id = p_pact_id
    ),

    'current_user_role', (
      SELECT pp.role FROM public.pact_parties pp
      WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id LIMIT 1
    ),

    'parties', (
      SELECT jsonb_agg(jsonb_build_object(
        'role', pp.role,
        'display_name', coalesce(u.full_name, pp.snapshot_full_name, pp.snapshot_email::text),
        'state', CASE WHEN pp.signed_at IS NOT NULL THEN 'signed'
                      WHEN pp.accepted_at IS NOT NULL THEN 'accepted'
                      ELSE 'invited' END
      ))
      FROM public.pact_parties pp
      LEFT JOIN public.users u ON u.id = pp.user_id
      WHERE pp.pact_id = p_pact_id
    ),

    'milestones', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', m.id,
        'display_id', m.display_id,
        'ordinal', m.ordinal,
        'name', m.name,
        'amount_eur', m.amount_cents / 100.0,
        'net_amount_eur', coalesce(m.net_amount_cents, m.amount_cents) / 100.0,
        'state', m.state,
        'has_invoice', m.invoice_storage_path IS NOT NULL
      ) ORDER BY m.ordinal)
      FROM public.milestones m
      WHERE m.pact_id = p_pact_id
    ),

    'last_verifications', (
      SELECT jsonb_agg(jsonb_build_object(
        'milestone_id', mav.milestone_id,
        'score', mav.score,
        'verdict', mav.verdict,
        'summary', mav.summary,
        'findings_count', jsonb_array_length(mav.findings),
        'created_at', mav.created_at
      ))
      FROM public.milestone_ai_verifications mav
      WHERE mav.pact_id = p_pact_id
      ORDER BY mav.created_at DESC
      LIMIT 6
    ),

    'health', (
      -- pact_health_scores es snapshot-based (varias filas por pacto, una
      -- por calculated_at). Tomamos la más reciente y completamos el
      -- ia_evidence_score con el cálculo on-demand desde las verificaciones.
      SELECT jsonb_build_object(
        'overall_score', phs.score,
        'milestone_compliance_pct', phs.milestone_compliance_pct,
        'no_disputes_pct', phs.no_disputes_pct,
        'snapshot_at', phs.calculated_at,
        'ia_evidence_score', (
          SELECT round(
            sum(mav.score::numeric * m.amount_cents) / nullif(sum(m.amount_cents), 0),
            2
          )
          FROM public.milestone_ai_verifications mav
          JOIN public.milestones m ON m.id = mav.milestone_id
          WHERE mav.pact_id = p_pact_id
            AND mav.id IN (
              SELECT DISTINCT ON (milestone_id) id
              FROM public.milestone_ai_verifications
              WHERE pact_id = p_pact_id
              ORDER BY milestone_id, created_at DESC
            )
        )
      )
      FROM public.pact_health_scores phs
      WHERE phs.pact_id = p_pact_id
      ORDER BY phs.calculated_at DESC
      LIMIT 1
    )
  ) INTO v_context;

  RETURN v_context;
END;
$$;


ALTER FUNCTION "public"."sf_get_pact_ai_context"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_get_pact_ai_context"("p_pact_id" "uuid") IS 'IA · Devuelve el contexto compactado del pacto en jsonb. Usado por ai-assistant-turn para construir el prompt del modelo. SECURITY DEFINER con validación de pertenencia al pacto.';



CREATE OR REPLACE FUNCTION "public"."sf_get_pact_detail"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid       uuid;
  v_user_id        uuid;
  v_can_act        boolean;
  v_is_direct      boolean;
  v_via_org        boolean;
  v_see_economics  boolean;
  v_can_move_money boolean;
  v_result         jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- Permiso de acceso (party directo o miembro activo de org parte)
  v_can_act := public.fn_user_can_act_on_pact(p_pact_id, v_user_id);
  IF NOT v_can_act THEN
    RAISE EXCEPTION 'No tienes acceso a este pacto';
  END IF;

  -- ¿Es party directo? (entonces ve todo siempre)
  SELECT EXISTS(
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id
  ) INTO v_is_direct;

  v_via_org        := NOT v_is_direct;
  v_see_economics  := public.fn_user_can_view_economics_on_pact(p_pact_id, v_user_id);
  v_can_move_money := public.fn_user_can_move_money(p_pact_id, v_user_id);

  SELECT jsonb_build_object(
    'pact', jsonb_build_object(
      'id', p.id,
      'display_id', p.display_id,
      'title', p.title,
      'description', p.description,
      'pact_type', p.pact_type::text,
      'state', p.state::text,
      'state_updated_at', p.state_updated_at,
      'obra_address_line', p.obra_address_line,
      'obra_postal_code', p.obra_postal_code,
      'obra_city', p.obra_city,
      'obra_province', p.obra_province,
      'obra_type', p.obra_type,
      'total_amount_cents',
        CASE WHEN v_see_economics THEN p.total_amount_cents ELSE NULL END,
      'iva_rate_pct', p.iva_rate_pct,
      'iva_included', p.iva_included,
      'platform_fee_pct',
        CASE WHEN v_see_economics THEN p.platform_fee_pct ELSE NULL END,
      'estimated_start_date', p.estimated_start_date,
      'estimated_end_date', p.estimated_end_date,
      'created_by_user_id', p.created_by_user_id,
      'created_at', p.created_at,
      'is_creator', (p.created_by_user_id = v_user_id),
      'my_user_id', v_user_id,
      -- v2.0
      'model_version', coalesce(p.model_version, 'v1'),
      'deposit_required_pct', p.deposit_required_pct,
      'deposit_current_cents',
        CASE WHEN v_see_economics THEN coalesce(p.deposit_current_cents, 0) ELSE NULL END,
      'budget_consumed_cents',
        CASE WHEN v_see_economics THEN coalesce(p.budget_consumed_cents, 0) ELSE NULL END,
      'certification_frequency_text', p.certification_frequency_text,
      -- v2.1
      'advance_reserve_pct', p.advance_reserve_pct,
      'advance_released_cents',
        CASE WHEN v_see_economics THEN coalesce(p.advance_released_cents, 0) ELSE NULL END,
      'advance_outstanding_cents',
        CASE WHEN v_see_economics THEN coalesce(p.advance_outstanding_cents, 0) ELSE NULL END,
      -- Sprint 6: contexto de acceso del caller
      'is_member_via_org', v_via_org,
      'can_view_economics', v_see_economics,
      'can_move_money', v_can_move_money
    ),
    'parties', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', pp.id,
        'role', pp.role::text,
        'user_id', pp.user_id,
        'is_me', (pp.user_id = v_user_id),
        'snapshot_full_name', pp.snapshot_full_name,
        'snapshot_email', pp.snapshot_email,
        'invited_at', pp.invited_at,
        'accepted_at', pp.accepted_at,
        'signed_at', pp.signed_at,
        'signature_state', pp.signature_state::text,
        'signature_id', pp.signaturit_signature_id
      ) ORDER BY
        CASE pp.role::text
          WHEN 'promotor' THEN 1
          WHEN 'constructor' THEN 2
          WHEN 'tecnico' THEN 3
          ELSE 4
        END
      )
      FROM public.pact_parties pp WHERE pp.pact_id = p.id
    ), '[]'::jsonb),
    'milestones', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', m.id,
        'display_id', m.display_id,
        'ordinal', m.ordinal,
        'name', m.name,
        'description', m.description,
        'amount_cents',
          CASE WHEN v_see_economics THEN m.amount_cents ELSE NULL END,
        'target_date', m.target_date,
        'state', m.state::text,
        'state_updated_at', m.state_updated_at,
        'started_at', m.started_at,
        'submitted_at', m.submitted_at,
        'validated_at', m.validated_at,
        'approved_by_promotor_at', m.approved_by_promotor_at,
        'rejected_at', m.rejected_at,
        'paid_at', m.paid_at,
        -- v2.0
        'version', coalesce(m.version, 1),
        'previous_version_id', m.previous_version_id,
        'invoice_number', m.invoice_number,
        'invoice_storage_path', m.invoice_storage_path,
        'invoice_sha256', m.invoice_sha256,
        'invoice_size_bytes', m.invoice_size_bytes,
        'detailed_doc_storage_path', m.detailed_doc_storage_path,
        'detailed_doc_sha256', m.detailed_doc_sha256,
        'detailed_doc_mime_type', m.detailed_doc_mime_type,
        'detailed_doc_size_bytes', m.detailed_doc_size_bytes,
        -- v2.1
        'advance_amortization_cents',
          CASE WHEN v_see_economics THEN coalesce(m.advance_amortization_cents, 0) ELSE NULL END,
        'net_amount_cents',
          CASE WHEN v_see_economics THEN coalesce(m.net_amount_cents, m.amount_cents) ELSE NULL END,
        'predeposit_received_cents',
          CASE WHEN v_see_economics THEN coalesce(m.predeposit_received_cents, 0) ELSE NULL END,
        'predeposit_deadline_at', m.predeposit_deadline_at,
        'forced_under_responsibility', coalesce(m.forced_under_responsibility, false),
        'forced_under_responsibility_at', m.forced_under_responsibility_at
      ) ORDER BY m.ordinal)
      FROM public.milestones m WHERE m.pact_id = p_pact_id
    ), '[]'::jsonb),
    'addendums', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', a.id,
        'display_id', a.display_id,
        'ordinal', a.ordinal,
        'title', a.title,
        'description', a.description,
        'extra_amount_cents',
          CASE WHEN v_see_economics THEN a.extra_amount_cents ELSE NULL END,
        'extra_days', a.extra_days,
        'justification', a.justification,
        'detailed_doc_storage_path', a.detailed_doc_storage_path,
        'detailed_doc_sha256', a.detailed_doc_sha256,
        'detailed_doc_mime_type', a.detailed_doc_mime_type,
        'detailed_doc_size_bytes', a.detailed_doc_size_bytes,
        'proposed_by_user_id', a.proposed_by_user_id,
        'proposed_by_role', a.proposed_by_role::text,
        'state', a.state::text,
        'signed_at_promotor', a.signed_at_promotor,
        'signed_at_constructor', a.signed_at_constructor,
        'signed_at_tecnico', a.signed_at_tecnico,
        'activated_at', CASE WHEN a.state = 'active'    THEN a.finalized_at END,
        'cancelled_at', CASE WHEN a.state = 'cancelled' THEN a.finalized_at END,
        'created_at', a.created_at
      ) ORDER BY a.ordinal)
      FROM public.pact_addendums a WHERE a.pact_id = p_pact_id
    ), '[]'::jsonb),
    -- Movimientos económicos: lista vacía si el miembro no ve economics
    'deposit_movements',
      CASE
        WHEN NOT v_see_economics THEN '[]'::jsonb
        ELSE coalesce((
          SELECT jsonb_agg(jsonb_build_object(
            'id', dm.id,
            'movement_type', dm.movement_type::text,
            'amount_cents', dm.amount_cents,
            'balance_before_cents', dm.balance_before_cents,
            'balance_after_cents', dm.balance_after_cents,
            'milestone_id', dm.related_milestone_id,
            'addendum_id', dm.related_addendum_id,
            'triggered_by_user_id', dm.triggered_by_user_id,
            'notes', dm.notes,
            'mangopay_transaction_id', dm.mangopay_transaction_id,
            'created_at', dm.occurred_at
          ) ORDER BY dm.occurred_at DESC)
          FROM public.deposit_movements dm WHERE dm.pact_id = p_pact_id
        ), '[]'::jsonb)
      END,
    -- Fase 1 interconexión (28-oct): pagos del pacto. «Cobrado» sale de aquí
    -- (payments succeeded), no de los hitos. Vacío si no se ven economics.
    'payments',
      CASE
        WHEN NOT v_see_economics THEN '[]'::jsonb
        ELSE coalesce((
          SELECT jsonb_agg(jsonb_build_object(
            'id', py.id,
            'milestone_id', py.milestone_id,
            'payment_type', py.payment_type::text,
            'amount_cents', py.amount_cents,
            'state', py.state::text,
            'destination_user_id', py.destination_user_id,
            'mangopay_transaction_id', py.mangopay_transaction_id,
            'succeeded_at', py.succeeded_at,
            'created_at', py.created_at
          ) ORDER BY coalesce(py.succeeded_at, py.created_at) DESC)
          FROM public.payments py WHERE py.pact_id = p_pact_id
        ), '[]'::jsonb)
      END,
    -- v2.1: póliza de caución (con importes enmascarados si no hay perms)
    'surety_policy', (
      SELECT jsonb_build_object(
        'id', sp.id,
        'insurer_name', sp.insurer_name,
        'policy_number', sp.policy_number,
        'premium_cents',
          CASE WHEN v_see_economics THEN sp.premium_cents ELSE NULL END,
        'initial_coverage_cents',
          CASE WHEN v_see_economics THEN sp.initial_coverage_cents ELSE NULL END,
        'current_coverage_cents',
          CASE WHEN v_see_economics THEN sp.current_coverage_cents ELSE NULL END,
        'status', sp.status::text,
        'issued_at', sp.issued_at,
        'released_at', sp.released_at,
        'cancelled_at', sp.cancelled_at,
        'claims',
          CASE WHEN v_see_economics THEN sp.claims ELSE NULL END,
        'notes', sp.notes,
        'created_at', sp.created_at
      )
      FROM public.surety_policies sp WHERE sp.pact_id = p_pact_id LIMIT 1
    )
  ) INTO v_result
  FROM public.pacts p
  WHERE p.id = p_pact_id;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."sf_get_pact_detail"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_get_pact_detail"("p_pact_id" "uuid") IS 'Sprint 6 · Detalle del pacto consciente de Organizations + Members. Permite acceso a miembros activos de orgs parte; enmascara importes cuando can_view_economics=false. Añade flags is_member_via_org, can_view_economics, can_move_money al payload.';



CREATE OR REPLACE FUNCTION "public"."sf_get_quality_summary"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result  jsonb;
BEGIN
  SELECT jsonb_build_object(
    'avg_quality_score',    COALESCE(AVG(qh.quality_score), 0),
    'total_holdback_cents', COALESCE(SUM(qh.holdback_cents), 0)::int,
    'holdback_count',       COUNT(qh.id)::int,
    'pacts_with_ipc',       (
      SELECT COUNT(*)::int FROM pacts p2
      WHERE p2.ipc_enabled = true
        AND EXISTS (
          SELECT 1 FROM pact_members pm2
          WHERE pm2.pact_id = p2.id AND pm2.user_id = v_user_id
        )
    ),
    'total_acopio_cents',   COALESCE((
      SELECT SUM(m2.amount_cents)::int FROM milestones m2
      WHERE m2.category = 'acopio'
        AND m2.state NOT IN ('paid', 'cancelled')
        AND EXISTS (
          SELECT 1 FROM pact_members pm3
          WHERE pm3.pact_id = m2.pact_id AND pm3.user_id = v_user_id
        )
    ), 0)
  ) INTO v_result
  FROM quality_holdbacks qh
  JOIN milestones m ON m.id = qh.milestone_id
  JOIN pact_members pm ON pm.pact_id = m.pact_id AND pm.user_id = v_user_id;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."sf_get_quality_summary"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_import_budget_as_pact"("p_api_key" "text", "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_key_id        uuid;
  v_partner       text;
  v_scopes        text[];
  v_hash          text;
  v_email         text;
  v_promotor_id   uuid;
  v_promotor_auth text;
  v_pact_id       uuid;
  v_display_id    text;
  v_plan_count    int := 0;
  v_presu_id      text;
BEGIN
  -- 1. Autenticar api-key
  v_hash := encode(extensions.digest(p_api_key, 'sha256'), 'hex');
  SELECT id, partner_id, scopes
    INTO v_key_id, v_partner, v_scopes
  FROM public.api_keys
  WHERE key_hash = v_hash AND active = true AND revoked_at IS NULL;

  IF v_key_id IS NULL THEN
    RAISE EXCEPTION 'api-key inválida o revocada' USING errcode = '28000';
  END IF;
  IF NOT ('import:budget' = ANY(v_scopes)) THEN
    RAISE EXCEPTION 'la api-key no tiene el scope import:budget' USING errcode = '42501';
  END IF;

  -- 2. Resolver promotor por email
  v_email := lower(trim(p_payload ->> 'promotor_email'));
  IF v_email IS NULL OR v_email = '' THEN
    RAISE EXCEPTION 'payload sin promotor_email';
  END IF;

  SELECT id, auth_provider_id INTO v_promotor_id, v_promotor_auth
  FROM public.users
  WHERE lower(email) = v_email AND primary_role = 'promotor' AND deleted_at IS NULL
  LIMIT 1;

  IF v_promotor_id IS NULL THEN
    RAISE EXCEPTION 'no existe un promotor de PactStream con email %; requiere invitación/vinculación', v_email
      USING errcode = 'P0002';
  END IF;

  -- 3. Impersonar al promotor y crear el pacto
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_promotor_auth, 'role', 'authenticated')::text, true);

  SELECT out_pact_id, out_display_id INTO v_pact_id, v_display_id
  FROM public.sf_create_pact_v21(
    p_title              => coalesce(p_payload ->> 'title', 'Obra importada de CostPact'),
    p_obra_address_line  => coalesce(p_payload ->> 'obra_address_line', 'Sin dirección'),
    p_total_amount_cents => (p_payload ->> 'total_amount_cents')::bigint,
    p_description        => p_payload ->> 'description',
    p_obra_city          => p_payload ->> 'obra_city',
    p_obra_province      => p_payload ->> 'obra_province',
    p_obra_postal_code   => p_payload ->> 'obra_postal_code',
    p_obra_type          => coalesce(p_payload ->> 'obra_type', 'reforma_integral'),
    p_iva_rate_pct       => coalesce((p_payload ->> 'iva_rate_pct')::numeric, 21),
    p_obra_menor_declaration_accepted => true
  );

  -- 4. Hitos del presupuesto → PLAN (no milestones: no consumen techo v2.1)
  v_plan_count := public.sf_write_pact_plan(v_pact_id, p_payload -> 'milestones');

  -- 5. Enlace + auditoría
  v_presu_id := p_payload ->> 'costpact_presupuesto_id';
  INSERT INTO public.pact_metadata (pact_id, key, value) VALUES
    (v_pact_id, 'source', 'costpact'),
    (v_pact_id, 'costpact_presupuesto_id', coalesce(v_presu_id, '')),
    (v_pact_id, 'partner_id', v_partner);

  INSERT INTO public.api_key_usage (api_key_id, partner_id, endpoint)
  VALUES (v_key_id, v_partner, 'sf_import_budget_as_pact');

  RETURN jsonb_build_object(
    'ok', true,
    'pact_id', v_pact_id,
    'display_id', v_display_id,
    'promotor_email', v_email,
    'plan_items_created', v_plan_count,
    'partner_id', v_partner
  );
END;
$$;


ALTER FUNCTION "public"."sf_import_budget_as_pact"("p_api_key" "text", "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_invite_org_member"("p_org_id" "uuid", "p_invited_email" "text", "p_full_name" "text", "p_can_view_economics" boolean DEFAULT false) RETURNS TABLE("out_member_id" "uuid", "out_invitation_token" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid; v_user_id uuid; v_member_id uuid; v_token uuid; v_norm_email text;
  v_existing_id uuid; v_existing_state text;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_org_id AND user_id = v_user_id
      AND role = 'owner' AND state = 'active'
  ) THEN RAISE EXCEPTION 'Solo el owner puede invitar miembros'; END IF;

  v_norm_email := lower(trim(p_invited_email));
  IF v_norm_email = '' OR position('@' IN v_norm_email) < 2 THEN
    RAISE EXCEPTION 'Email inválido';
  END IF;
  IF length(trim(p_full_name)) < 2 THEN
    RAISE EXCEPTION 'El nombre completo del miembro es obligatorio';
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE id = v_user_id AND lower(email) = v_norm_email) THEN
    RAISE EXCEPTION 'No puedes invitarte a ti mismo';
  END IF;

  -- ¿Hay una invitación previa para este email?
  SELECT id, state::text INTO v_existing_id, v_existing_state
  FROM public.organization_members
  WHERE organization_id = p_org_id AND lower(invited_email) = v_norm_email;

  v_token := gen_random_uuid();

  IF v_existing_id IS NOT NULL THEN
    IF v_existing_state IN ('invited', 'active') THEN
      RAISE EXCEPTION 'Ya existe una invitación o membresía para %', v_norm_email;
    END IF;
    -- Estaba revocada · la reactivamos como nueva invitación
    UPDATE public.organization_members
    SET full_name = trim(p_full_name),
        can_view_economics = p_can_view_economics,
        state = 'invited',
        invitation_token = v_token,
        invited_by_user_id = v_user_id,
        invited_at = now(),
        accepted_at = NULL,
        revoked_at = NULL,
        revoked_reason = NULL,
        user_id = NULL
    WHERE id = v_existing_id;
    v_member_id := v_existing_id;
  ELSE
    INSERT INTO public.organization_members (
      organization_id, invited_email, full_name,
      role, can_view_economics, state, invitation_token, invited_by_user_id
    ) VALUES (
      p_org_id, v_norm_email, trim(p_full_name),
      'member', p_can_view_economics, 'invited', v_token, v_user_id
    ) RETURNING id INTO v_member_id;
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id,
    CASE WHEN v_existing_id IS NULL THEN 'org_member_invited' ELSE 'org_member_reinvited' END,
    'organization_member', v_member_id,
    jsonb_build_object('org_id', p_org_id, 'email', v_norm_email,
                       'can_view_economics', p_can_view_economics));

  out_member_id := v_member_id;
  out_invitation_token := v_token;
  RETURN NEXT;
END; $$;


ALTER FUNCTION "public"."sf_invite_org_member"("p_org_id" "uuid", "p_invited_email" "text", "p_full_name" "text", "p_can_view_economics" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_invite_party"("p_pact_id" "uuid", "p_role" "text", "p_email" "text", "p_full_name" "text", "p_phone" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_caller_id uuid;
  v_party_id uuid;
  v_existing_user_id uuid;
  v_pact_state pact_state;
  v_pact_type pact_type;
  v_creator_id uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT id INTO v_caller_id FROM public.users
  WHERE auth_provider_id = v_auth_uid::text AND deleted_at IS NULL;

  -- Validar pacto y permisos
  SELECT state, pact_type, created_by_user_id
  INTO v_pact_state, v_pact_type, v_creator_id
  FROM public.pacts WHERE id = p_pact_id;

  IF v_pact_state IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact_state NOT IN ('draft') THEN
    RAISE EXCEPTION 'Solo puedes invitar partes en estado draft (estado actual: %)', v_pact_state;
  END IF;
  IF v_creator_id != v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador del pacto puede invitar partes';
  END IF;

  -- Validar rol
  IF p_role NOT IN ('promotor', 'constructor', 'tecnico') THEN
    RAISE EXCEPTION 'Rol inválido: %', p_role;
  END IF;
  IF v_pact_type = 'obra_menor' AND p_role = 'tecnico' THEN
    RAISE EXCEPTION 'Obra menor no requiere técnico';
  END IF;

  -- Buscar si el invitado ya tiene cuenta en PactStream
  SELECT id INTO v_existing_user_id
  FROM public.users
  WHERE lower(email) = lower(p_email) AND deleted_at IS NULL
  LIMIT 1;

  -- ── Auditoría 2026-07-13 C4: rechazo de autotrato ────────────────
  IF v_existing_user_id IS NOT NULL AND v_existing_user_id = v_caller_id THEN
    RAISE EXCEPTION 'Autotrato no permitido: no puedes invitarte a ti mismo como contraparte del pacto';
  END IF;

  -- ── Auditoría 2026-07-13: rechazo de email duplicado en el pacto ─
  IF EXISTS (
    SELECT 1 FROM public.pact_parties
    WHERE pact_id = p_pact_id
      AND lower(snapshot_email) = lower(p_email)
  ) THEN
    RAISE EXCEPTION 'Ya existe una parte invitada con ese email en este pacto';
  END IF;

  -- ── Auditoría 2026-07-13: rechazo de user_id duplicado en el pacto ─
  IF v_existing_user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.pact_parties
    WHERE pact_id = p_pact_id
      AND user_id = v_existing_user_id
  ) THEN
    RAISE EXCEPTION 'Ese usuario ya es parte de este pacto';
  END IF;

  -- Insertar la parte
  INSERT INTO public.pact_parties (
    pact_id,
    user_id,
    role,
    invited_by_user_id,
    snapshot_full_name,
    snapshot_email
  ) VALUES (
    p_pact_id,
    v_existing_user_id,
    p_role::pact_party_role,
    v_caller_id,
    p_full_name,
    lower(p_email)
  )
  RETURNING id INTO v_party_id;

  -- Audit
  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_caller_id, 'pact_party_invited', 'pact', p_pact_id,
    jsonb_build_object('role', p_role, 'email', p_email,
      'existing_user', v_existing_user_id IS NOT NULL));

  RETURN v_party_id;
END;
$$;


ALTER FUNCTION "public"."sf_invite_party"("p_pact_id" "uuid", "p_role" "text", "p_email" "text", "p_full_name" "text", "p_phone" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_invite_party"("p_pact_id" "uuid", "p_role" "text", "p_email" "text", "p_full_name" "text", "p_phone" "text") IS 'Añade una parte al pacto. Si el email tiene cuenta PactStream, vincula. Si no, queda pendiente.';



CREATE OR REPLACE FUNCTION "public"."sf_link_cert_to_plan_item"("p_milestone_id" "uuid", "p_plan_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_caller_id uuid := current_user_id();
  v_pact_id   uuid;
  v_item      public.pact_plan_items%ROWTYPE;
BEGIN
  SELECT pact_id INTO v_pact_id FROM public.milestones WHERE id = p_milestone_id;
  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Certificación no encontrada';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.pact_parties
    WHERE pact_id = v_pact_id AND user_id = v_caller_id AND role = 'constructor'
  ) THEN
    RAISE EXCEPTION 'Solo el constructor del pacto puede enlazar la certificación' USING errcode = '42501';
  END IF;

  SELECT * INTO v_item FROM public.pact_plan_items WHERE id = p_plan_item_id;
  IF v_item.id IS NULL OR v_item.pact_id <> v_pact_id THEN
    RAISE EXCEPTION 'El elemento del plan no pertenece a este pacto';
  END IF;
  IF v_item.kind = 'advance' THEN
    RAISE EXCEPTION 'El Adelanto no se certifica: lo gestiona el propio pacto';
  END IF;
  IF v_item.milestone_id IS NOT NULL AND v_item.milestone_id <> p_milestone_id THEN
    RAISE EXCEPTION 'Ese elemento del plan ya tiene una certificación';
  END IF;

  UPDATE public.pact_plan_items SET milestone_id = p_milestone_id WHERE id = p_plan_item_id;
END;
$$;


ALTER FUNCTION "public"."sf_link_cert_to_plan_item"("p_milestone_id" "uuid", "p_plan_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_link_costpact_budget"("p_pact_id" "uuid", "p_presupuesto_id" "text", "p_items" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_caller_id uuid := current_user_id();
  v_pact      public.pacts%ROWTYPE;
BEGIN
  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN
    RAISE EXCEPTION 'Pacto no encontrado';
  END IF;
  IF v_pact.created_by_user_id IS DISTINCT FROM v_caller_id THEN
    RAISE EXCEPTION 'Solo el creador puede enlazar el presupuesto' USING errcode = '42501';
  END IF;
  IF v_pact.state <> 'draft' THEN
    RAISE EXCEPTION 'El presupuesto solo se enlaza con el pacto en borrador';
  END IF;
  IF nullif(trim(p_presupuesto_id), '') IS NULL THEN
    RAISE EXCEPTION 'Falta el presupuesto de CostPact';
  END IF;

  INSERT INTO public.pact_metadata (pact_id, key, value) VALUES
    (p_pact_id, 'source', 'costpact'),
    (p_pact_id, 'costpact_presupuesto_id', trim(p_presupuesto_id))
  ON CONFLICT (pact_id, key) DO UPDATE SET value = EXCLUDED.value;

  RETURN public.sf_write_pact_plan(p_pact_id, p_items);
END;
$$;


ALTER FUNCTION "public"."sf_link_costpact_budget"("p_pact_id" "uuid", "p_presupuesto_id" "text", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_list_my_notifications"("p_limit" integer DEFAULT 50, "p_only_unread" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_items   jsonb;
BEGIN
  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT jsonb_agg(payload ORDER BY ord_at DESC)
    INTO v_items
  FROM (
    SELECT
      n.created_at AS ord_at,
      jsonb_build_object(
        'id', n.id,
        'pact_id', n.pact_id,
        'milestone_id', n.milestone_id,
        'notification_type', n.notification_type,
        'priority', n.priority::text,
        'title', n.title,
        'body', n.body,
        'cta_url', n.cta_url,
        'read_at', n.read_at,
        'sent_at', n.sent_at,
        'created_at', n.created_at
      ) AS payload
    FROM public.notifications n
    WHERE n.user_id = v_user_id
      AND n.channel = 'in_app'
      AND (NOT p_only_unread OR n.read_at IS NULL)
    ORDER BY n.created_at DESC
    LIMIT p_limit
  ) t;

  -- Devolvemos array plano para mantener compatibilidad con el cliente
  -- Flutter del Sprint 3. El contador de no-leídas se obtiene aparte
  -- vía sf_count_unread_notifications.
  RETURN coalesce(v_items, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."sf_list_my_notifications"("p_limit" integer, "p_only_unread" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_list_my_orgs"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_orgs     jsonb;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;

  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', o.id,
    'legal_name', o.legal_name,
    'trade_name', o.trade_name,
    'cif', o.cif,
    'description', o.description,
    'org_type', coalesce(o.org_type::text, 'constructor'),
    'kyb_status', o.kyb_status::text,
    'is_owner', (om.role = 'owner'),
    'can_view_economics', om.can_view_economics,
    'member_id', om.id,
    'joined_at', om.accepted_at,
    'members_count', (
      SELECT count(*) FROM public.organization_members
      WHERE organization_id = o.id AND state = 'active'
    ),
    'pending_invites_count', (
      SELECT count(*) FROM public.organization_members
      WHERE organization_id = o.id AND state = 'invited'
    )
  ) ORDER BY (om.role = 'owner') DESC, o.created_at DESC), '[]'::jsonb)
  INTO v_orgs
  FROM public.organizations o
  JOIN public.organization_members om
    ON om.organization_id = o.id
    AND om.user_id = v_user_id
    AND om.state = 'active'
  WHERE o.deleted_at IS NULL;

  RETURN jsonb_build_object(
    'user_id', v_user_id,
    'organizations', v_orgs
  );
END;
$$;


ALTER FUNCTION "public"."sf_list_my_orgs"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_list_my_pacts"() RETURNS TABLE("pact_id" "uuid", "display_id" "text", "title" "text", "pact_type" "text", "state" "text", "state_updated_at" timestamp with time zone, "obra_city" "text", "obra_province" "text", "total_amount_cents" bigint, "my_role" "text", "is_member_via_org" boolean, "parties_total" integer, "parties_accepted" integer, "milestones_total" integer, "milestones_paid" integer, "next_milestone_name" "text", "next_milestone_amount_cents" bigint, "next_milestone_target_date" "date", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  RETURN QUERY
  WITH direct_pacts AS (
    -- Pacts donde soy parte directa
    SELECT DISTINCT pp.pact_id, pp.role::text AS my_role, false AS via_org
    FROM public.pact_parties pp
    WHERE pp.user_id = v_user_id
  ),
  org_pacts AS (
    -- Pacts donde la org de mi user es constructor/técnico
    SELECT DISTINCT pp.pact_id, pp.role::text AS my_role, true AS via_org
    FROM public.pact_parties pp
    JOIN public.organizations o ON o.owner_user_id = pp.user_id
      AND o.deleted_at IS NULL
    JOIN public.organization_members om ON om.organization_id = o.id
    WHERE om.user_id = v_user_id
      AND om.state = 'active'
      AND pp.role::text IN ('constructor', 'tecnico')
      -- Evitar duplicar si el user es a la vez parte directa
      AND NOT EXISTS (
        SELECT 1 FROM public.pact_parties pp2
        WHERE pp2.pact_id = pp.pact_id AND pp2.user_id = v_user_id
      )
  ),
  my_pacts AS (
    SELECT * FROM direct_pacts
    UNION ALL
    SELECT * FROM org_pacts
  ),
  my_economics AS (
    -- Para cada pact, si el user puede ver economics
    SELECT
      mp.pact_id,
      public.fn_user_can_view_economics_on_pact(mp.pact_id, v_user_id) AS can_view_econ
    FROM my_pacts mp
  ),
  party_stats AS (
    SELECT
      pp.pact_id,
      count(*)::int AS total,
      count(*) FILTER (WHERE pp.accepted_at IS NOT NULL)::int AS accepted
    FROM public.pact_parties pp
    GROUP BY pp.pact_id
  ),
  milestone_stats AS (
    SELECT
      m.pact_id,
      count(*)::int AS total,
      count(*) FILTER (WHERE m.state = 'paid')::int AS paid
    FROM public.milestones m
    GROUP BY m.pact_id
  ),
  next_milestones AS (
    SELECT DISTINCT ON (m.pact_id)
      m.pact_id, m.name, m.amount_cents, m.target_date
    FROM public.milestones m
    WHERE m.state != 'paid'
    ORDER BY m.pact_id, m.ordinal
  )
  SELECT
    p.id AS pact_id,
    p.display_id,
    p.title,
    p.pact_type::text,
    p.state::text,
    p.state_updated_at,
    p.obra_city,
    p.obra_province,
    -- Económicos sensibles: NULL si el user no puede verlos
    CASE WHEN me.can_view_econ THEN p.total_amount_cents ELSE NULL END
      AS total_amount_cents,
    mp.my_role,
    mp.via_org AS is_member_via_org,
    coalesce(ps.total, 0) AS parties_total,
    coalesce(ps.accepted, 0) AS parties_accepted,
    coalesce(ms.total, 0) AS milestones_total,
    coalesce(ms.paid, 0) AS milestones_paid,
    nm.name AS next_milestone_name,
    CASE WHEN me.can_view_econ THEN nm.amount_cents ELSE NULL END
      AS next_milestone_amount_cents,
    nm.target_date AS next_milestone_target_date,
    p.created_at
  FROM my_pacts mp
  JOIN public.pacts p ON p.id = mp.pact_id
  LEFT JOIN my_economics me ON me.pact_id = mp.pact_id
  LEFT JOIN party_stats ps ON ps.pact_id = p.id
  LEFT JOIN milestone_stats ms ON ms.pact_id = p.id
  LEFT JOIN next_milestones nm ON nm.pact_id = p.id
  ORDER BY p.state_updated_at DESC;
END;
$$;


ALTER FUNCTION "public"."sf_list_my_pacts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_list_pact_messages"("p_pact_id" "uuid", "p_limit" integer DEFAULT 50, "p_before_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_items   jsonb;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  -- Clamping defensivo del limit.
  p_limit := greatest(1, least(coalesce(p_limit, 50), 200));

  SELECT jsonb_agg(payload ORDER BY ord DESC)
    INTO v_items
    FROM (
      SELECT
        m.created_at AS ord,
        jsonb_build_object(
          'id', m.id,
          'sender_user_id', m.sender_user_id,
          'sender_name', u.full_name,
          'sender_role', pp.role::text,
          -- Cuando el mensaje está soft-deleted, no exponemos su cuerpo
          -- a nadie (queda una tombstone visible en el hilo).
          'body', CASE WHEN m.deleted_at IS NULL THEN m.body ELSE NULL END,
          'deleted_at', m.deleted_at,
          'created_at', m.created_at,
          'is_mine', (m.sender_user_id = v_user_id)
        ) AS payload
      FROM public.pact_messages m
      LEFT JOIN public.users u ON u.id = m.sender_user_id
      LEFT JOIN public.pact_parties pp
             ON pp.pact_id = m.pact_id AND pp.user_id = m.sender_user_id
      WHERE m.pact_id = p_pact_id
        AND (p_before_at IS NULL OR m.created_at < p_before_at)
      ORDER BY m.created_at DESC
      LIMIT p_limit
    ) t;

  RETURN coalesce(v_items, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."sf_list_pact_messages"("p_pact_id" "uuid", "p_limit" integer, "p_before_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_mark_all_notifications_read"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_count   int;
BEGIN
  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  WITH upd AS (
    UPDATE public.notifications
    SET read_at = now()
    WHERE user_id = v_user_id
      AND channel = 'in_app'
      AND read_at IS NULL
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM upd;

  RETURN coalesce(v_count, 0);
END;
$$;


ALTER FUNCTION "public"."sf_mark_all_notifications_read"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_mark_notification_read"("p_notification_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.notifications
  SET read_at = coalesce(read_at, now())
  WHERE id = p_notification_id AND user_id = v_user_id;
END;
$$;


ALTER FUNCTION "public"."sf_mark_notification_read"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_mark_pact_read"("p_pact_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  INSERT INTO public.pact_message_reads (pact_id, user_id, last_read_at)
       VALUES (p_pact_id, v_user_id, now())
   ON CONFLICT (pact_id, user_id)
   DO UPDATE SET last_read_at = EXCLUDED.last_read_at;
END;
$$;


ALTER FUNCTION "public"."sf_mark_pact_read"("p_pact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_milestone_confirm_release"("p_milestone_id" "uuid", "p_amount_cents" bigint, "p_transfer_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_pact_id    uuid;
  v_state      milestone_state;
  v_pact_type  pact_type;
  v_promotor   uuid;
  v_net_cents  bigint;
begin
  -- Lock del hito (serializa con el mock y otros releases).
  perform 1 from public.milestones where id = p_milestone_id for update;

  select m.pact_id, m.state, p.pact_type
    into v_pact_id, v_state, v_pact_type
  from public.milestones m
  join public.pacts p on p.id = m.pact_id
  where m.id = p_milestone_id;
  if v_pact_id is null then
    raise exception 'Hito no encontrado: %', p_milestone_id;
  end if;

  -- Idempotencia: si ya está pagado, no repetir.
  if v_state = 'paid' then
    return jsonb_build_object('success', true, 'idempotent', true);
  end if;

  select user_id into v_promotor
    from public.pact_parties where pact_id = v_pact_id and role = 'promotor' limit 1;

  -- Cascada de obra menor (sin técnico): ready_for_review → awaiting_promotor.
  if v_pact_type = 'obra_menor' and v_state = 'ready_for_review' then
    update public.milestones set state = 'in_validation' where id = p_milestone_id;
    update public.milestones set state = 'approved_by_tech', validated_at = now() where id = p_milestone_id;
    update public.milestones set state = 'awaiting_promotor' where id = p_milestone_id;
    insert into public.milestone_validations (milestone_id, validator_user_id, decision, rationale)
    values (p_milestone_id, v_promotor, 'approved'::validation_decision,
      '[obra menor: validación automática por promotor · release Mangopay]');
    v_state := 'awaiting_promotor';
  end if;

  if v_state <> 'awaiting_promotor' then
    raise exception 'El hito no está esperando decisión del promotor (estado: %)', v_state;
  end if;

  v_net_cents := public._sf_milestone_release_ledger(p_milestone_id, v_promotor, p_transfer_id, 'mangopay');

  insert into public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_promotor, 'milestone_confirm_release', 'milestone', p_milestone_id,
    jsonb_build_object('net_cents', v_net_cents, 'transfer_id', p_transfer_id));

  return jsonb_build_object('success', true, 'released_cents', v_net_cents);
end;
$$;


ALTER FUNCTION "public"."sf_milestone_confirm_release"("p_milestone_id" "uuid", "p_amount_cents" bigint, "p_transfer_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_milestone_force_advance"("p_milestone_id" "uuid", "p_disclaimer_accepted" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_milestone public.milestones%ROWTYPE;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
BEGIN
  IF NOT p_disclaimer_accepted THEN
    RAISE EXCEPTION 'Debes aceptar el disclaimer para avanzar bajo tu responsabilidad';
  END IF;

  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_milestone FROM public.milestones WHERE id = p_milestone_id;
  IF v_milestone.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = v_milestone.pact_id;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact.id AND user_id = v_user_id;
  IF v_user_role != 'constructor' THEN
    RAISE EXCEPTION 'Solo el constructor puede activar este toggle';
  END IF;

  IF v_milestone.state NOT IN ('pending_predeposit', 'paused_no_predeposit') THEN
    RAISE EXCEPTION 'Solo aplica a certificaciones pendientes o paralizadas (estado: %)',
      v_milestone.state;
  END IF;

  UPDATE public.milestones
  SET state = 'in_execution',
      forced_under_responsibility = true,
      forced_under_responsibility_at = now(),
      started_at = coalesce(started_at, now())
  WHERE id = p_milestone_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact.id, 'cert_forced_under_responsibility',
    jsonb_build_object(
      'cert_id', p_milestone_id,
      'cert_ordinal', v_milestone.ordinal,
      'predeposit_received_cents', v_milestone.predeposit_received_cents,
      'predeposit_required_cents', v_milestone.net_amount_cents,
      'disclaimer_accepted_at', now()
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'cert_force_advance', 'milestone', p_milestone_id,
    jsonb_build_object(
      'predeposit_gap_cents',
      v_milestone.net_amount_cents - v_milestone.predeposit_received_cents
    ));

  RETURN jsonb_build_object(
    'success', true,
    'new_state', 'in_execution',
    'forced_under_responsibility', true
  );
END;
$$;


ALTER FUNCTION "public"."sf_milestone_force_advance"("p_milestone_id" "uuid", "p_disclaimer_accepted" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_milestone_force_advance"("p_milestone_id" "uuid", "p_disclaimer_accepted" boolean) IS 'v2.1 · Constructor avanza sin pre-depósito completo asumiendo responsabilidad.';



CREATE OR REPLACE FUNCTION "public"."sf_milestone_promotor_decide"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid; v_user_id uuid; v_pact_id uuid; v_pact_type pact_type;
  v_milestone_state milestone_state; v_user_role pact_party_role;
  v_final_state milestone_state; v_amount_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  -- ── Auditoría 2026-07-13 M1: lock de la fila del hito ────────────
  -- Serializa decisiones concurrentes sobre el mismo hito (evita doble
  -- release / doble disputa). Debe ejecutarse ANTES de leer el estado.
  PERFORM 1 FROM public.milestones WHERE id = p_milestone_id FOR UPDATE;

  SELECT m.pact_id, m.state, m.amount_cents, p.pact_type
  INTO v_pact_id, v_milestone_state, v_amount_cents, v_pact_type
  FROM public.milestones m JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;
  IF v_pact_id IS NULL THEN RAISE EXCEPTION 'Hito no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN RAISE EXCEPTION 'Solo el promotor puede decidir'; END IF;
  IF p_decision NOT IN ('approve', 'dispute') THEN RAISE EXCEPTION 'Decisión inválida: %', p_decision; END IF;

  IF v_pact_type = 'obra_menor' AND v_milestone_state = 'ready_for_review' THEN
    UPDATE public.milestones SET state = 'in_validation' WHERE id = p_milestone_id;
    UPDATE public.milestones SET state = 'approved_by_tech', validated_at = now() WHERE id = p_milestone_id;
    UPDATE public.milestones SET state = 'awaiting_promotor' WHERE id = p_milestone_id;
    INSERT INTO public.milestone_validations (milestone_id, validator_user_id, decision, rationale)
    VALUES (p_milestone_id, v_user_id, 'approved'::validation_decision,
      coalesce('[obra menor: validación automática por promotor] ' || p_rationale, '[obra menor: validación automática por promotor]'));
  ELSIF v_milestone_state != 'awaiting_promotor' THEN
    RAISE EXCEPTION 'El hito no está esperando decisión del promotor (estado: %)', v_milestone_state;
  END IF;

  IF p_decision = 'approve' THEN
    -- Fase 1 interconexión (28-oct): el mock escribe el MISMO libro que el
    -- release real (guard de saldo, custodia, deposit_movements, payments).
    v_amount_cents := public._sf_milestone_release_ledger(p_milestone_id, v_user_id, NULL, 'mock');
    v_final_state := 'paid';
  ELSE
    UPDATE public.milestones SET state = 'disputed' WHERE id = p_milestone_id;
    v_final_state := 'disputed';
    INSERT INTO public.milestone_objections (milestone_id, raised_by_user_id, reason_categories, reason_detail)
    VALUES (p_milestone_id, v_user_id, ARRAY['other']::text[],
      coalesce(p_rationale, 'Objeción del promotor'));
    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact_id, 'milestone_disputed',
      jsonb_build_object('milestone_id', p_milestone_id, 'rationale', p_rationale), v_user_id);
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'milestone_promotor_decided', 'milestone', p_milestone_id,
    jsonb_build_object('decision', p_decision, 'final_state', v_final_state::text, 'released_cents',
      CASE WHEN p_decision = 'approve' THEN v_amount_cents END));

  RETURN jsonb_build_object('success', true, 'milestone_state', v_final_state::text);
END;
$$;


ALTER FUNCTION "public"."sf_milestone_promotor_decide"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_milestone_promotor_decide"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") IS 'El promotor decide approve|dispute. Obra mayor: desde awaiting_promotor. Obra menor: desde ready_for_review (cascada). approve = release MOCK por _sf_milestone_release_ledger (mismo libro que Mangopay, con guard de saldo). Lock FOR UPDATE del hito (M1).';



CREATE OR REPLACE FUNCTION "public"."sf_milestone_tech_review"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_pact_id  uuid;
  v_pact_type pact_type;
  v_milestone_state milestone_state;
  v_user_role pact_party_role;
  v_validation_id uuid;
  v_final_state milestone_state;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT m.pact_id, m.state, p.pact_type
  INTO v_pact_id, v_milestone_state, v_pact_type
  FROM public.milestones m JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;
  IF v_pact_id IS NULL THEN RAISE EXCEPTION 'Hito no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact_id AND user_id = v_user_id;
  IF v_user_role IS NULL THEN RAISE EXCEPTION 'No formas parte de este pacto'; END IF;
  IF v_pact_type = 'obra_mayor' AND v_user_role != 'tecnico' THEN
    RAISE EXCEPTION 'Solo el arquitecto técnico puede validar técnicamente este hito';
  END IF;
  IF v_milestone_state != 'ready_for_review' THEN
    RAISE EXCEPTION 'El hito no está listo para revisión (estado actual: %)', v_milestone_state;
  END IF;
  IF p_decision NOT IN ('approve', 'reject', 'request_info') THEN
    RAISE EXCEPTION 'Decisión inválida: %', p_decision;
  END IF;

  UPDATE public.milestones SET state = 'in_validation' WHERE id = p_milestone_id;

  IF p_decision = 'approve' THEN
    UPDATE public.milestones SET state = 'approved_by_tech', validated_at = now() WHERE id = p_milestone_id;
    UPDATE public.milestones SET state = 'awaiting_promotor' WHERE id = p_milestone_id;
    v_final_state := 'awaiting_promotor';
  ELSIF p_decision = 'reject' THEN
    UPDATE public.milestones SET state = 'rejected_by_tech', rejected_at = now() WHERE id = p_milestone_id;
    v_final_state := 'rejected_by_tech';
  ELSE
    UPDATE public.milestones SET state = 'info_requested' WHERE id = p_milestone_id;
    v_final_state := 'info_requested';
  END IF;

  INSERT INTO public.milestone_validations (milestone_id, validator_user_id, decision, rationale)
  VALUES (p_milestone_id, v_user_id,
    CASE p_decision WHEN 'approve' THEN 'approved'::validation_decision
                    WHEN 'reject' THEN 'rejected'::validation_decision
                    ELSE 'info_requested'::validation_decision END,
    p_rationale)
  RETURNING id INTO v_validation_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact_id, 'milestone_tech_reviewed',
    jsonb_build_object('milestone_id', p_milestone_id, 'decision', p_decision,
      'final_state', v_final_state::text), v_user_id);

  RETURN jsonb_build_object('success', true,
    'milestone_state', v_final_state::text, 'validation_id', v_validation_id);
END;
$$;


ALTER FUNCTION "public"."sf_milestone_tech_review"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_my_milestone_releases"() RETURNS TABLE("payment_id" "uuid", "pact_id" "uuid", "pact_display_id" "text", "pact_title" "text", "milestone_id" "uuid", "milestone_ordinal" integer, "milestone_name" "text", "amount_cents" bigint, "succeeded_at" timestamp with time zone, "via" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select py.id, py.pact_id, p.display_id, p.title,
         py.milestone_id, m.ordinal, m.name, py.amount_cents,
         py.succeeded_at,
         case when py.mangopay_transaction_id is null then 'mock' else 'mangopay' end
    from public.payments py
    join public.users u on u.id = py.destination_user_id
    join public.pacts p on p.id = py.pact_id
    left join public.milestones m on m.id = py.milestone_id
   where u.auth_provider_id = (auth.uid())::text
     and u.deleted_at is null
     and py.payment_type = 'milestone_release'
     and py.state = 'succeeded'
   order by py.succeeded_at desc nulls last;
$$;


ALTER FUNCTION "public"."sf_my_milestone_releases"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_pact_finalize_settlement"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid         uuid;
  v_user_id          uuid;
  v_user_role        pact_party_role;
  v_pact_state       text;
  v_release_threshold smallint;
  v_avg_quality      numeric;
  v_total_holdback   bigint;
  v_reserve_cents    bigint;
  v_settlement       text;
  v_holdback_row     record;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  -- Solo promotor puede iniciar liquidación
  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;

  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede iniciar la liquidación final';
  END IF;

  -- Solo pactos completados
  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state != 'completed' THEN
    RAISE EXCEPTION 'El pacto debe estar completado para liquidar (estado actual: %)', v_pact_state;
  END IF;

  -- Leer umbral de liberación
  SELECT (value)::smallint INTO v_release_threshold
  FROM public.app_settings WHERE key = 'quality_release_threshold';
  v_release_threshold := coalesce(v_release_threshold, 70);

  -- Calcular calidad media ponderada del pacto
  SELECT
    CASE WHEN sum(m.amount_cents) > 0 THEN
      sum(
        coalesce(
          (SELECT score FROM public.milestone_ai_verifications
           WHERE milestone_id = m.id
           ORDER BY created_at DESC LIMIT 1),
          75  -- neutral si no hay verificación
        )::numeric * m.amount_cents
      ) / sum(m.amount_cents)
    ELSE 75
    END
  INTO v_avg_quality
  FROM public.milestones m
  WHERE m.pact_id = p_pact_id
    AND m.deleted_at IS NULL
    AND m.state = 'paid';

  -- Total retenido
  SELECT coalesce(sum(amount_cents), 0)
  INTO v_total_holdback
  FROM public.quality_holdbacks
  WHERE pact_id = p_pact_id AND state = 'held';

  -- Reserva del pacto
  SELECT coalesce(
    (total_amount_cents * advance_reserve_pct / 100)::bigint,
    0
  )
  INTO v_reserve_cents
  FROM public.pacts WHERE id = p_pact_id;

  -- Decisión
  IF v_avg_quality >= v_release_threshold THEN
    -- Calidad OK → liberar todo
    v_settlement := 'released';

    -- Liberar holdbacks individuales
    FOR v_holdback_row IN
      SELECT id, milestone_id, amount_cents
      FROM public.quality_holdbacks
      WHERE pact_id = p_pact_id AND state = 'held'
    LOOP
      UPDATE public.quality_holdbacks
      SET state = 'released', released_at = now(), released_by = v_user_id
      WHERE id = v_holdback_row.id;

      UPDATE public.milestones
      SET quality_holdback_cents = 0,
          net_paid_cents = amount_cents
      WHERE id = v_holdback_row.milestone_id;
    END LOOP;

    -- Marcar pacto
    UPDATE public.pacts
    SET quality_settlement_state = 'released',
        total_quality_holdback_cents = 0,
        state = 'closed'
    WHERE id = p_pact_id;

  ELSE
    -- Calidad insuficiente → retener reserva, holdbacks quedan retenidos
    v_settlement := 'under_review';

    UPDATE public.quality_holdbacks
    SET state = 'under_review'
    WHERE pact_id = p_pact_id AND state = 'held';

    UPDATE public.pacts
    SET quality_settlement_state = 'under_review'
    WHERE id = p_pact_id;
  END IF;

  -- Evento
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'quality_settlement',
    jsonb_build_object(
      'settlement', v_settlement,
      'avg_quality_score', round(v_avg_quality, 1),
      'release_threshold', v_release_threshold,
      'total_holdback_cents', v_total_holdback,
      'reserve_cents', v_reserve_cents,
      'holdbacks_count', (SELECT count(*) FROM public.quality_holdbacks WHERE pact_id = p_pact_id)
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'quality_settlement', 'pact', p_pact_id,
    jsonb_build_object('settlement', v_settlement, 'avg_quality', round(v_avg_quality, 1)));

  RETURN jsonb_build_object(
    'settlement', v_settlement,
    'avg_quality_score', round(v_avg_quality, 1),
    'release_threshold', v_release_threshold,
    'total_holdback_released_cents', CASE WHEN v_settlement = 'released' THEN v_total_holdback ELSE 0 END,
    'reserve_cents', v_reserve_cents
  );
END;
$$;


ALTER FUNCTION "public"."sf_pact_finalize_settlement"("p_pact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_pact_fund_initial"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_deposit_required_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede depositar el adelanto inicial';
  END IF;

  IF v_pact.state != 'signed' THEN
    RAISE EXCEPTION 'El pacto no está en estado signed (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2' THEN
    RAISE EXCEPTION 'sf_pact_fund_initial solo aplica a pacts v2';
  END IF;

  v_deposit_required_cents := (v_pact.total_amount_cents * v_pact.deposit_required_pct / 100)::bigint;

  -- Transiciones state machine: signed → funded → in_execution
  UPDATE public.pacts
  SET state = 'funded',
      deposit_current_cents = v_deposit_required_cents
  WHERE id = p_pact_id;

  UPDATE public.pacts
  SET state = 'in_execution'
  WHERE id = p_pact_id;

  -- Registrar movimiento de depósito
  INSERT INTO public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    balance_before_cents, balance_after_cents, notes
  ) VALUES (
    p_pact_id, 'initial_deposit', v_deposit_required_cents, v_user_id,
    0, v_deposit_required_cents,
    'Depósito inicial · ' || v_pact.deposit_required_pct || '% del presupuesto'
  );

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'pact_funded',
    jsonb_build_object(
      'deposit_pct', v_pact.deposit_required_pct,
      'deposit_cents', v_deposit_required_cents
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_fund_initial', 'pact', p_pact_id,
    jsonb_build_object('deposit_cents', v_deposit_required_cents));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', 'in_execution',
    'deposit_cents', v_deposit_required_cents,
    'deposit_pct', v_pact.deposit_required_pct
  );
END;
$$;


ALTER FUNCTION "public"."sf_pact_fund_initial"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_pact_fund_initial"("p_pact_id" "uuid") IS 'Sprint 4 · Promotor deposita el % inicial. Pact: signed → funded → in_execution. Registra deposit_movement initial_deposit.';



CREATE OR REPLACE FUNCTION "public"."sf_pact_predeposit_milestone"("p_milestone_id" "uuid", "p_amount_cents" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_milestone public.milestones%ROWTYPE;
  v_user_role pact_party_role;
  v_required_cents bigint;
  v_balance_before bigint;
  v_balance_after bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_milestone FROM public.milestones WHERE id = p_milestone_id;
  IF v_milestone.id IS NULL THEN RAISE EXCEPTION 'Certificación no encontrada'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = v_milestone.pact_id;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_pact.id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede pre-depositar';
  END IF;

  IF v_milestone.state NOT IN ('pending_predeposit', 'paused_no_predeposit') THEN
    RAISE EXCEPTION 'La certificación no está pendiente de pre-depósito (estado: %)',
      v_milestone.state;
  END IF;

  v_required_cents := v_milestone.net_amount_cents - v_milestone.predeposit_received_cents;

  IF p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'El importe debe ser positivo';
  END IF;
  IF p_amount_cents > v_required_cents THEN
    RAISE EXCEPTION 'El importe excede lo pendiente (% €)', v_required_cents / 100;
  END IF;

  UPDATE public.milestones
  SET predeposit_received_cents = predeposit_received_cents + p_amount_cents
  WHERE id = p_milestone_id;

  v_balance_before := v_pact.deposit_current_cents;
  v_balance_after := v_balance_before + p_amount_cents;

  UPDATE public.pacts
  SET deposit_current_cents = v_balance_after
  WHERE id = v_pact.id;

  INSERT INTO public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    related_milestone_id, balance_before_cents, balance_after_cents, notes
  ) VALUES (
    v_pact.id, 'predeposit_for_cert', p_amount_cents, v_user_id,
    p_milestone_id, v_balance_before, v_balance_after,
    'Pre-depósito de Cert #' || v_milestone.ordinal
  );

  IF (v_milestone.predeposit_received_cents + p_amount_cents) >= v_milestone.net_amount_cents THEN
    UPDATE public.milestones
    SET state = 'in_execution',
        started_at = coalesce(started_at, now())
    WHERE id = p_milestone_id;

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact.id, 'cert_predeposit_completed',
      jsonb_build_object('cert_id', p_milestone_id),
      v_user_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'predeposit_received_cents', v_milestone.predeposit_received_cents + p_amount_cents,
    'predeposit_required_cents', v_milestone.net_amount_cents,
    'completed', (v_milestone.predeposit_received_cents + p_amount_cents) >= v_milestone.net_amount_cents
  );
END;
$$;


ALTER FUNCTION "public"."sf_pact_predeposit_milestone"("p_milestone_id" "uuid", "p_amount_cents" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_pact_predeposit_milestone"("p_milestone_id" "uuid", "p_amount_cents" bigint) IS 'v2.1 · Promotor pre-deposita el neto. Cuando se completa, la cert pasa a in_execution.';



CREATE OR REPLACE FUNCTION "public"."sf_pact_replenish_deposit"("p_pact_id" "uuid", "p_amount_cents" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_balance_before bigint;
  v_balance_after bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede reponer el depósito';
  END IF;

  IF p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'El importe a reponer debe ser positivo';
  END IF;

  v_balance_before := v_pact.deposit_current_cents;
  v_balance_after := v_balance_before + p_amount_cents;

  UPDATE public.pacts
  SET deposit_current_cents = v_balance_after
  WHERE id = p_pact_id;

  INSERT INTO public.deposit_movements (
    pact_id, movement_type, amount_cents, triggered_by_user_id,
    balance_before_cents, balance_after_cents, notes
  ) VALUES (
    p_pact_id, 'replenishment', p_amount_cents, v_user_id,
    v_balance_before, v_balance_after,
    'Reposición voluntaria del promotor'
  );

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'deposit_replenished',
    jsonb_build_object('amount_cents', p_amount_cents,
                       'new_balance', v_balance_after),
    v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'new_balance_cents', v_balance_after
  );
END;
$$;


ALTER FUNCTION "public"."sf_pact_replenish_deposit"("p_pact_id" "uuid", "p_amount_cents" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_pact_setup_advance"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_pact public.pacts%ROWTYPE;
  v_user_role pact_party_role;
  v_total_advance_cents bigint;
  v_reserve_cents bigint;
  v_released_cents bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_pact FROM public.pacts WHERE id = p_pact_id;
  IF v_pact.id IS NULL THEN RAISE EXCEPTION 'Pacto no encontrado'; END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = p_pact_id AND user_id = v_user_id;
  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede configurar el adelanto';
  END IF;

  IF v_pact.state != 'signed' THEN
    RAISE EXCEPTION 'El pacto no está en estado signed (actual: %)', v_pact.state;
  END IF;
  IF v_pact.model_version != 'v2.1' THEN
    RAISE EXCEPTION 'sf_pact_setup_advance solo aplica a pacts v2.1';
  END IF;

  v_total_advance_cents := (v_pact.total_amount_cents * v_pact.deposit_required_pct / 100)::bigint;
  v_reserve_cents := (v_pact.total_amount_cents * v_pact.advance_reserve_pct / 100)::bigint;
  v_released_cents := v_total_advance_cents - v_reserve_cents;

  UPDATE public.pacts
  SET state = 'funded',
      deposit_current_cents = v_reserve_cents,
      advance_released_cents = v_released_cents,
      advance_outstanding_cents = v_released_cents
  WHERE id = p_pact_id;

  UPDATE public.pacts SET state = 'in_execution' WHERE id = p_pact_id;

  IF v_reserve_cents > 0 THEN
    INSERT INTO public.deposit_movements (
      pact_id, movement_type, amount_cents, triggered_by_user_id,
      balance_before_cents, balance_after_cents, notes
    ) VALUES (
      p_pact_id, 'reserve_deposit', v_reserve_cents, v_user_id,
      0, v_reserve_cents,
      'Reserva de finiquito · ' || v_pact.advance_reserve_pct || '% del presupuesto'
    );
  END IF;

  IF v_released_cents > 0 THEN
    INSERT INTO public.deposit_movements (
      pact_id, movement_type, amount_cents, triggered_by_user_id,
      balance_before_cents, balance_after_cents, notes
    ) VALUES (
      p_pact_id, 'initial_deposit', v_released_cents, v_user_id,
      v_reserve_cents, v_reserve_cents,
      'Anticipo entregado al constructor · ' ||
        (v_pact.deposit_required_pct - v_pact.advance_reserve_pct) ||
        '% del presupuesto'
    );
  END IF;

  INSERT INTO public.surety_policies (
    pact_id, insurer_name, initial_coverage_cents, current_coverage_cents,
    status, created_by_user_id, admin_notes
  ) VALUES (
    p_pact_id, 'PENDIENTE_ADMIN', v_released_cents, v_released_cents,
    'draft', v_user_id,
    'Auto-creada por sf_pact_setup_advance. Pendiente de confirmar aseguradora real desde panel admin.'
  );

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (p_pact_id, 'advance_setup',
    jsonb_build_object(
      'advance_pct', v_pact.deposit_required_pct,
      'reserve_pct', v_pact.advance_reserve_pct,
      'total_advance_cents', v_total_advance_cents,
      'released_cents', v_released_cents,
      'reserve_cents', v_reserve_cents
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'pact_setup_advance', 'pact', p_pact_id,
    jsonb_build_object(
      'released_cents', v_released_cents,
      'reserve_cents', v_reserve_cents
    ));

  RETURN jsonb_build_object(
    'success', true,
    'pact_state', 'in_execution',
    'total_deposited_cents', v_total_advance_cents,
    'released_to_constructor_cents', v_released_cents,
    'reserve_custody_cents', v_reserve_cents,
    'surety_policy_pending_admin', true
  );
END;
$$;


ALTER FUNCTION "public"."sf_pact_setup_advance"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_pact_setup_advance"("p_pact_id" "uuid") IS 'v2.1 · Promotor deposita el adelanto. Libera la parte variable al constructor y custodia la reserva. Crea póliza draft.';



CREATE OR REPLACE FUNCTION "public"."sf_plan_item_kind"("p_trigger" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT CASE p_trigger
    WHEN 'firma_contrato' THEN 'advance'
    WHEN 'fin_garantia'   THEN 'retention'
    ELSE 'phase'
  END;
$$;


ALTER FUNCTION "public"."sf_plan_item_kind"("p_trigger" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_recalc_pact_health"("p_pact_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_total_milestones int; v_paid_milestones int; v_with_evidences int;
  v_fast_validations int; v_reviewable int; v_disputes int;
  v_avg_ia_score numeric; v_compliance_pct numeric; v_evidence_pct numeric;
  v_speed_pct numeric; v_no_disputes_pct numeric; v_ia_score numeric;
  v_final_score smallint; v_snapshot_id uuid;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE state = 'paid')
  INTO v_total_milestones, v_paid_milestones
  FROM public.milestones WHERE pact_id = p_pact_id;
  IF v_total_milestones = 0 THEN RETURN jsonb_build_object('score', 0, 'error', 'no_milestones'); END IF;

  SELECT count(DISTINCT m.id) INTO v_with_evidences
  FROM public.milestones m WHERE m.pact_id = p_pact_id
    AND m.state IN ('ready_for_review','approved_by_tech','paid','disputed')
    AND EXISTS (SELECT 1 FROM public.milestone_evidences me WHERE me.milestone_id = m.id);

  SELECT count(*) INTO v_reviewable FROM public.milestones
  WHERE pact_id = p_pact_id AND state IN ('ready_for_review','approved_by_tech','paid','disputed');

  SELECT count(*) INTO v_fast_validations
  FROM public.milestones m
  JOIN public.milestone_state_transitions mst ON mst.milestone_id = m.id AND mst.to_state = 'paid'
  JOIN public.milestone_state_transitions mst2 ON mst2.milestone_id = m.id AND mst2.to_state = 'ready_for_review'
  WHERE m.pact_id = p_pact_id AND m.state = 'paid'
    AND (mst.occurred_at - mst2.occurred_at) < interval '7 days';

  SELECT count(*) INTO v_disputes FROM public.disputes
  WHERE pact_id = p_pact_id AND state NOT IN ('resolved','withdrawn');

  SELECT avg((ar.metadata->>'score_numeric')::numeric) INTO v_avg_ia_score
  FROM public.ai_runs ar WHERE ar.pact_id = p_pact_id AND ar.run_type = 'vision'
    AND ar.success = true AND ar.metadata->>'score_numeric' IS NOT NULL;

  v_compliance_pct := round((v_paid_milestones::numeric / v_total_milestones) * 100, 2);
  v_evidence_pct := CASE WHEN v_reviewable = 0 THEN 100 ELSE round((v_with_evidences::numeric / v_reviewable) * 100, 2) END;
  v_speed_pct := CASE WHEN v_paid_milestones = 0 THEN 100 ELSE round((v_fast_validations::numeric / v_paid_milestones) * 100, 2) END;
  v_no_disputes_pct := greatest(0, 100 - (v_disputes * 20));
  v_ia_score := coalesce(v_avg_ia_score, 75);
  v_final_score := round(v_compliance_pct*0.30 + v_evidence_pct*0.25 + v_speed_pct*0.20 + v_no_disputes_pct*0.15 + v_ia_score*0.10)::smallint;
  v_final_score := greatest(0, least(100, v_final_score));

  INSERT INTO public.pact_health_scores (pact_id,score,milestone_compliance_pct,evidence_validity_pct,validation_speed_pct,no_disputes_pct,ia_evidence_score,calculated_at)
  VALUES (p_pact_id,v_final_score,v_compliance_pct,v_evidence_pct,v_speed_pct,v_no_disputes_pct,v_ia_score,now())
  ON CONFLICT (pact_id, calculated_at) DO UPDATE SET score=EXCLUDED.score, milestone_compliance_pct=EXCLUDED.milestone_compliance_pct,
    evidence_validity_pct=EXCLUDED.evidence_validity_pct, validation_speed_pct=EXCLUDED.validation_speed_pct,
    no_disputes_pct=EXCLUDED.no_disputes_pct, ia_evidence_score=EXCLUDED.ia_evidence_score
  RETURNING id INTO v_snapshot_id;

  RETURN jsonb_build_object('snapshot_id',v_snapshot_id,'score',v_final_score,'milestone_compliance',v_compliance_pct,
    'evidence_validity',v_evidence_pct,'validation_speed',v_speed_pct,'no_disputes',v_no_disputes_pct,'ia_score',v_ia_score);
END;
$$;


ALTER FUNCTION "public"."sf_recalc_pact_health"("p_pact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_recalc_pact_health"("p_pact_id" "uuid") IS 'Sprint 8 · Genera un snapshot de salud del pacto en pact_health_scores. Llámalo tras cualquier cambio de estado de un hito. Coste: O(n hitos).';



CREATE OR REPLACE FUNCTION "public"."sf_recalc_user_reputation"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_role user_role; v_pacts_total int; v_pacts_completed int; v_pacts_disputed int;
  v_payment_speed_pct numeric; v_evidence_quality_pct numeric;
  v_sign_rate_pct numeric; v_val_speed_pct numeric;
  v_final_score smallint; v_tier text; v_components jsonb; v_snapshot_id uuid;
BEGIN
  -- ── Control de acceso (auditoría 2026-07-13 A3) ──────────────────
  -- Un cliente directo (authenticated/anon) solo puede recalcular su propia
  -- reputación. service_role y llamadas internas SECURITY DEFINER
  -- (current_user = owner, p.ej. desde get_user_reputation) quedan exentos.
  IF current_user IN ('authenticated', 'anon') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = p_user_id
        AND u.auth_provider_id = auth.uid()::text
        AND u.deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'Forbidden' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  SELECT primary_role INTO v_user_role FROM public.users
  WHERE id = p_user_id AND deleted_at IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'user_not_found'); END IF;

  SELECT
    count(DISTINCT pp.pact_id),
    count(DISTINCT pp.pact_id) FILTER (
      WHERE NOT EXISTS (SELECT 1 FROM public.milestones m WHERE m.pact_id = pp.pact_id AND m.state != 'paid')
        AND EXISTS (SELECT 1 FROM public.milestones m2 WHERE m2.pact_id = pp.pact_id AND m2.state = 'paid')
    ),
    count(DISTINCT d.pact_id)
  INTO v_pacts_total, v_pacts_completed, v_pacts_disputed
  FROM public.pact_parties pp
  LEFT JOIN public.disputes d ON d.pact_id = pp.pact_id AND d.state NOT IN ('resolved','withdrawn')
  WHERE pp.user_id = p_user_id;

  IF v_user_role = 'promotor' THEN
    SELECT CASE WHEN count(*) = 0 THEN 100
      ELSE round(count(*) FILTER (WHERE m.state = 'paid')::numeric / count(*) * 100, 2) END
    INTO v_payment_speed_pct
    FROM public.pact_parties pp JOIN public.milestones m ON m.pact_id = pp.pact_id
    WHERE pp.user_id = p_user_id AND pp.role = 'promotor';

    v_final_score := round(
      v_payment_speed_pct * 0.40 +
      greatest(0, 100 - (v_pacts_disputed * 25)) * 0.35 +
      (CASE WHEN v_pacts_total = 0 THEN 75 ELSE v_pacts_completed::numeric / v_pacts_total * 100 END) * 0.25
    )::smallint;
    v_components := jsonb_build_object('payment_speed_pct', v_payment_speed_pct,
      'no_disputes_pct', greatest(0, 100 - v_pacts_disputed * 25),
      'completion_pct', CASE WHEN v_pacts_total = 0 THEN 75 ELSE round(v_pacts_completed::numeric / v_pacts_total * 100, 2) END);

  ELSIF v_user_role = 'constructor' THEN
    SELECT CASE WHEN count(*) = 0 THEN 75
      ELSE round(count(*) FILTER (WHERE (ar.metadata->>'score_numeric')::numeric >= 75)::numeric / count(*) * 100, 2) END
    INTO v_evidence_quality_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id
    JOIN public.ai_runs ar ON ar.pact_id = pp.pact_id AND ar.run_type = 'vision' AND ar.success = true
      AND ar.metadata->>'score_numeric' IS NOT NULL
    WHERE pp.user_id = p_user_id AND pp.role = 'constructor';

    v_final_score := round(
      (CASE WHEN v_pacts_total = 0 THEN 75 ELSE v_pacts_completed::numeric / v_pacts_total * 100 END) * 0.40 +
      v_evidence_quality_pct * 0.35 + greatest(0, 100 - v_pacts_disputed * 25) * 0.25
    )::smallint;
    v_components := jsonb_build_object('completion_pct', CASE WHEN v_pacts_total = 0 THEN 75
      ELSE round(v_pacts_completed::numeric / v_pacts_total * 100, 2) END,
      'evidence_quality_pct', v_evidence_quality_pct, 'no_disputes_pct', greatest(0, 100 - v_pacts_disputed * 25));

  ELSE -- tecnico
    SELECT CASE WHEN count(*) = 0 THEN 100
      ELSE round(count(*) FILTER (WHERE (mst_paid.occurred_at - mst_rfr.occurred_at) < interval '3 days')::numeric / count(*) * 100, 2) END
    INTO v_val_speed_pct
    FROM public.pact_parties pp
    JOIN public.milestones m ON m.pact_id = pp.pact_id AND m.state = 'paid'
    JOIN public.milestone_state_transitions mst_rfr ON mst_rfr.milestone_id = m.id AND mst_rfr.to_state = 'ready_for_review'
    JOIN public.milestone_state_transitions mst_paid ON mst_paid.milestone_id = m.id AND mst_paid.to_state = 'paid'
    WHERE pp.user_id = p_user_id AND pp.role = 'tecnico';

    SELECT CASE WHEN count(*) = 0 THEN 100
      ELSE round(count(*) FILTER (WHERE pp2.signed_at IS NOT NULL)::numeric / count(*) * 100, 2) END
    INTO v_sign_rate_pct FROM public.pact_parties pp2
    WHERE pp2.user_id = p_user_id AND pp2.role = 'tecnico';

    v_final_score := round(coalesce(v_val_speed_pct, 100)*0.50 + coalesce(v_sign_rate_pct, 100)*0.30 + greatest(0, 100 - v_pacts_disputed*25)*0.20)::smallint;
    v_components := jsonb_build_object('validation_speed_pct', coalesce(v_val_speed_pct, 100),
      'sign_rate_pct', coalesce(v_sign_rate_pct, 100), 'no_disputes_pct', greatest(0, 100 - v_pacts_disputed * 25));
  END IF;

  v_final_score := greatest(0, least(100, v_final_score));
  v_tier := private.score_to_tier(v_final_score);

  INSERT INTO public.user_reputations (user_id, role, score, tier, components, pacts_total, pacts_completed, pacts_disputed, calculated_at)
  VALUES (p_user_id, v_user_role, v_final_score, v_tier, v_components, v_pacts_total, v_pacts_completed, v_pacts_disputed, now())
  RETURNING id INTO v_snapshot_id;

  RETURN jsonb_build_object('snapshot_id', v_snapshot_id, 'role', v_user_role, 'score', v_final_score,
    'tier', v_tier, 'components', v_components, 'pacts_total', v_pacts_total,
    'pacts_completed', v_pacts_completed, 'pacts_disputed', v_pacts_disputed);
END;
$$;


ALTER FUNCTION "public"."sf_recalc_user_reputation"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_recalc_user_reputation"("p_user_id" "uuid") IS 'Sprint 8 · Genera un snapshot de reputación del usuario en user_reputations. Llámalo tras completar un pacto o resolver una disputa.';



CREATE OR REPLACE FUNCTION "public"."sf_record_ai_verification"("p_milestone_id" "uuid", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_hash" "text", "p_evidences_count" smallint, "p_documents_count" smallint, "p_score" smallint, "p_verdict" "text", "p_summary" "text", "p_findings" "jsonb", "p_checklist_match" "jsonb", "p_recommendation" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cache_read_tokens" integer, "p_cost_cents" bigint, "p_duration_ms" integer) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_pact_id uuid;
  v_verification_id uuid;
BEGIN
  -- Resolver pact_id desde milestone
  SELECT pact_id INTO v_pact_id FROM public.milestones WHERE id = p_milestone_id;
  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Milestone % no encontrado', p_milestone_id;
  END IF;

  -- INSERT en la tabla
  INSERT INTO public.milestone_ai_verifications (
    milestone_id, pact_id, provider, model, prompt_version,
    input_hash_sha256, evidences_count, documents_count,
    score, verdict, summary, findings, checklist_match, recommendation,
    input_tokens, output_tokens, cache_read_tokens, cost_cents, duration_ms
  ) VALUES (
    p_milestone_id, v_pact_id, p_provider, p_model, p_prompt_version,
    p_input_hash, p_evidences_count, p_documents_count,
    p_score, p_verdict::ai_verdict, p_summary, p_findings, p_checklist_match, p_recommendation,
    p_input_tokens, p_output_tokens, p_cache_read_tokens, p_cost_cents, p_duration_ms
  )
  RETURNING id INTO v_verification_id;

  -- NOTA: el ia_evidence_score se calcula on-demand vía sf_get_pact_ai_context.
  -- Si en el futuro quieres incorporarlo al snapshot de pact_health_scores,
  -- la lógica de recalculación de salud (que ya existe en tu sistema) puede
  -- consultar milestone_ai_verifications para incluirlo en el próximo snapshot.

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, actor_user_id, payload)
  VALUES (
    v_pact_id,
    'ai_verification_completed',
    null,
    jsonb_build_object(
      'verification_id', v_verification_id,
      'milestone_id', p_milestone_id,
      'verdict', p_verdict,
      'score', p_score,
      'provider', p_provider
    )
  );

  RETURN v_verification_id;
END;
$$;


ALTER FUNCTION "public"."sf_record_ai_verification"("p_milestone_id" "uuid", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_hash" "text", "p_evidences_count" smallint, "p_documents_count" smallint, "p_score" smallint, "p_verdict" "text", "p_summary" "text", "p_findings" "jsonb", "p_checklist_match" "jsonb", "p_recommendation" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cache_read_tokens" integer, "p_cost_cents" bigint, "p_duration_ms" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_record_assistant_turn"("p_pact_id" "uuid", "p_user_message" "text", "p_assistant_content" "text", "p_assistant_blocks" "jsonb", "p_tool_call_name" "text", "p_tool_call_input" "jsonb", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cost_cents" bigint, "p_latency_ms" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_user_msg_id uuid;
  v_assistant_msg_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM public.users
  WHERE auth_provider_id = auth.uid()::text AND deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  IF NOT public.fn_user_in_pact(p_pact_id) THEN
    RAISE EXCEPTION 'Usuario no pertenece al pacto %', p_pact_id USING ERRCODE = '42501';
  END IF;

  -- Insert turno usuario
  INSERT INTO public.ai_assistant_messages (
    pact_id, user_id, role, content, provider
  ) VALUES (
    p_pact_id, v_user_id, 'user', p_user_message, p_provider
  ) RETURNING id INTO v_user_msg_id;

  -- Insert turno asistente
  INSERT INTO public.ai_assistant_messages (
    pact_id, user_id, role, content, content_blocks,
    tool_call_name, tool_call_input,
    tool_call_status,
    provider, model, prompt_version,
    input_tokens, output_tokens, cost_cents, latency_ms
  ) VALUES (
    p_pact_id, v_user_id, 'assistant', p_assistant_content, p_assistant_blocks,
    p_tool_call_name, p_tool_call_input,
    CASE WHEN p_tool_call_name IS NOT NULL THEN 'proposed' ELSE NULL END,
    p_provider, p_model, p_prompt_version,
    p_input_tokens, p_output_tokens, p_cost_cents, p_latency_ms
  ) RETURNING id INTO v_assistant_msg_id;

  -- Event log
  INSERT INTO public.pact_events (pact_id, event_type, actor_user_id, payload)
  VALUES (
    p_pact_id, 'ai_assistant_message', v_user_id,
    jsonb_build_object(
      'assistant_msg_id', v_assistant_msg_id,
      'tool_proposed', p_tool_call_name,
      'provider', p_provider
    )
  );

  RETURN jsonb_build_object(
    'user_message_id', v_user_msg_id,
    'assistant_message_id', v_assistant_msg_id
  );
END;
$$;


ALTER FUNCTION "public"."sf_record_assistant_turn"("p_pact_id" "uuid", "p_user_message" "text", "p_assistant_content" "text", "p_assistant_blocks" "jsonb", "p_tool_call_name" "text", "p_tool_call_input" "jsonb", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cost_cents" bigint, "p_latency_ms" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_record_milestone_evidence"("p_milestone_id" "uuid", "p_evidence_type" "text", "p_storage_path" "text", "p_sha256_hash" "text", "p_file_size_bytes" bigint DEFAULT NULL::bigint, "p_mime_type" "text" DEFAULT NULL::"text", "p_gps_latitude" double precision DEFAULT NULL::double precision, "p_gps_longitude" double precision DEFAULT NULL::double precision, "p_gps_accuracy_meters" double precision DEFAULT NULL::double precision, "p_client_timestamp" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_description" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid        uuid;
  v_user_id         uuid;
  v_pact_id         uuid;
  v_pact_title      text;
  v_milestone_name  text;
  v_milestone_state milestone_state;
  v_evidence_id     uuid;
  v_can_act         boolean;
  v_actor_name      text;
  v_recipients      uuid[];
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id, u.full_name INTO v_user_id, v_actor_name
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id, m.state, m.name, p.title
    INTO v_pact_id, v_milestone_state, v_milestone_name, v_pact_title
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  v_can_act := public.fn_user_acts_as_constructor_on_pact(v_pact_id, v_user_id);
  IF NOT v_can_act THEN
    RAISE EXCEPTION 'Solo el constructor (o su equipo) puede subir evidencias';
  END IF;

  IF v_milestone_state NOT IN ('in_execution', 'ready_for_review', 'info_requested') THEN
    RAISE EXCEPTION 'No se pueden subir evidencias en estado: %', v_milestone_state;
  END IF;

  IF p_evidence_type NOT IN ('photo', 'video', 'audio', 'document', 'note') THEN
    RAISE EXCEPTION 'Tipo de evidencia inválido: %', p_evidence_type;
  END IF;

  INSERT INTO public.milestone_evidences (
    milestone_id, uploaded_by_user_id, evidence_type,
    storage_path, file_size_bytes, mime_type, sha256_hash,
    gps_latitude, gps_longitude, gps_accuracy_meters,
    client_timestamp, description
  ) VALUES (
    p_milestone_id, v_user_id, p_evidence_type::evidence_type,
    p_storage_path, p_file_size_bytes, p_mime_type, p_sha256_hash,
    p_gps_latitude, p_gps_longitude, p_gps_accuracy_meters,
    coalesce(p_client_timestamp, now()), p_description
  )
  RETURNING id INTO v_evidence_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact_id, 'evidence_uploaded',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'evidence_id', v_evidence_id,
      'type', p_evidence_type
    ),
    v_user_id);

  -- Notificación operativa: parties + miembros del equipo, excluyendo al
  -- propio uploader (ya lo sabe).
  SELECT array_agg(user_id) INTO v_recipients
  FROM public.fn_notification_recipients(
    v_pact_id, NULL, false, v_user_id
  );

  PERFORM public.fn_create_notifications(
    p_user_ids        := v_recipients,
    p_notification_type := 'evidence_uploaded',
    p_title           := 'Nueva evidencia · ' || coalesce(v_milestone_name, 'Hito'),
    p_body            := coalesce(v_actor_name, 'Un miembro del equipo') ||
                         ' subió una ' ||
                         CASE p_evidence_type
                           WHEN 'photo' THEN 'foto'
                           WHEN 'video' THEN 'vídeo'
                           WHEN 'audio' THEN 'nota de audio'
                           WHEN 'document' THEN 'documento'
                           ELSE 'evidencia'
                         END ||
                         ' al hito de "' || coalesce(v_pact_title, 'la obra') || '".',
    p_pact_id         := v_pact_id,
    p_milestone_id    := p_milestone_id,
    p_cta_url         := '/pacts/' || v_pact_id::text || '/milestones/' || p_milestone_id::text,
    p_priority        := 'normal',
    p_idempotency_root := 'evidence:' || v_evidence_id::text
  );

  RETURN v_evidence_id;
END;
$$;


ALTER FUNCTION "public"."sf_record_milestone_evidence"("p_milestone_id" "uuid", "p_evidence_type" "text", "p_storage_path" "text", "p_sha256_hash" "text", "p_file_size_bytes" bigint, "p_mime_type" "text", "p_gps_latitude" double precision, "p_gps_longitude" double precision, "p_gps_accuracy_meters" double precision, "p_client_timestamp" timestamp with time zone, "p_description" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_release_acopio_item"("p_item_id" "uuid", "p_amount_cents" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_item record;
  v_milestone record;
  v_total_released bigint;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT ai.*, m.pact_id, m.amount_cents AS milestone_total
  INTO v_item
  FROM public.acopio_items ai
  JOIN public.milestones m ON m.id = ai.milestone_id
  WHERE ai.id = p_item_id;

  IF v_item IS NULL THEN
    RAISE EXCEPTION 'Item de acopio no encontrado';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_item.pact_id AND user_id = v_user_id;

  IF v_user_role != 'promotor' THEN
    RAISE EXCEPTION 'Solo el promotor puede autorizar liberaciones de acopio';
  END IF;

  IF v_item.state NOT IN ('purchased', 'delivered', 'verified') THEN
    RAISE EXCEPTION 'El item debe estar comprado/entregado/verificado para liberar fondos (estado: %)', v_item.state;
  END IF;

  IF p_amount_cents <= 0 OR p_amount_cents > v_item.estimated_cents THEN
    RAISE EXCEPTION 'Importe de liberación inválido';
  END IF;

  -- Verificar que no exceda el total del milestone
  SELECT coalesce(sum(released_cents), 0)
  INTO v_total_released
  FROM public.acopio_items
  WHERE milestone_id = v_item.milestone_id AND state = 'released';

  IF v_total_released + p_amount_cents > v_item.milestone_total THEN
    RAISE EXCEPTION 'La liberación excedería el total del escrow de acopio';
  END IF;

  -- Liberar
  UPDATE public.acopio_items
  SET state = 'released',
      released_cents = p_amount_cents,
      actual_cents = p_amount_cents,
      released_at = now()
  WHERE id = p_item_id;

  -- Evento
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_item.pact_id, 'acopio_item_released',
    jsonb_build_object(
      'item_id', p_item_id,
      'milestone_id', v_item.milestone_id,
      'amount_cents', p_amount_cents,
      'description', v_item.description
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'acopio_item_released', 'acopio_item', p_item_id,
    jsonb_build_object('amount_cents', p_amount_cents));

  RETURN jsonb_build_object(
    'success', true,
    'released_cents', p_amount_cents,
    'total_released_cents', v_total_released + p_amount_cents,
    'milestone_total_cents', v_item.milestone_total
  );
END;
$$;


ALTER FUNCTION "public"."sf_release_acopio_item"("p_item_id" "uuid", "p_amount_cents" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_resolve_dispute_escrow"("p_milestone_id" "uuid", "p_resolution" "text", "p_promotor_pct" numeric DEFAULT 100, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id uuid;
  v_user_role pact_party_role;
  v_escrow record;
  v_to_promotor bigint;
  v_to_constructor bigint;
  v_final_state text;
  v_milestone_state milestone_state;
  v_milestone_new_state milestone_state;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT de.*
  INTO v_escrow
  FROM public.dispute_escrows de
  WHERE de.milestone_id = p_milestone_id;

  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'No hay escrow de disputa para este hito';
  END IF;

  SELECT role INTO v_user_role FROM public.pact_parties
  WHERE pact_id = v_escrow.pact_id AND user_id = v_user_id;

  -- Solo técnico o promotor pueden resolver
  IF v_user_role NOT IN ('tecnico', 'promotor') THEN
    RAISE EXCEPTION 'Solo el técnico o promotor pueden resolver la disputa';
  END IF;

  IF v_escrow.state NOT IN ('deposited', 'pending_deposit') THEN
    RAISE EXCEPTION 'El escrow ya fue resuelto (estado: %)', v_escrow.state;
  END IF;

  IF p_resolution NOT IN ('favor_promotor', 'favor_constructor', 'split') THEN
    RAISE EXCEPTION 'Resolución inválida: %. Usar favor_promotor | favor_constructor | split', p_resolution;
  END IF;

  IF p_promotor_pct < 0 OR p_promotor_pct > 100 THEN
    RAISE EXCEPTION 'p_promotor_pct debe estar entre 0 y 100';
  END IF;

  -- Distribuir fondos
  v_to_promotor := (v_escrow.escrow_amount_cents * p_promotor_pct / 100)::bigint;
  v_to_constructor := v_escrow.escrow_amount_cents - v_to_promotor;

  IF p_resolution = 'favor_promotor' THEN
    v_final_state := 'released_to_promotor';
    v_to_promotor := v_escrow.escrow_amount_cents;
    v_to_constructor := 0;
  ELSIF p_resolution = 'favor_constructor' THEN
    v_final_state := 'released_to_constructor';
    v_to_promotor := 0;
    v_to_constructor := v_escrow.escrow_amount_cents;
  ELSE
    v_final_state := 'split';
  END IF;

  UPDATE public.dispute_escrows
  SET state = v_final_state,
      resolved_at = now(),
      resolution_note = p_note,
      released_to_promotor_cents = v_to_promotor,
      released_to_constructor_cents = v_to_constructor
  WHERE id = v_escrow.id;

  -- Descontar del depósito del pacto
  UPDATE public.pacts
  SET deposit_current_cents = greatest(0, deposit_current_cents - v_escrow.escrow_amount_cents)
  WHERE id = v_escrow.pact_id;

  -- ── NUEVO: transición del estado del hito (salir de 'disputed') ──────────────
  -- Sin esto, el hito quedaba en 'disputed' para siempre (callejón sin salida).
  SELECT state INTO v_milestone_state FROM public.milestones WHERE id = p_milestone_id;
  IF v_milestone_state = 'disputed' THEN
    v_milestone_new_state := CASE p_resolution
      WHEN 'favor_constructor' THEN 'paid'::milestone_state          -- disputa rechazada → se paga
      ELSE 'in_execution'::milestone_state                           -- favor_promotor / split → ajustes
    END;
    -- El trigger validate_milestone_state_transition valida disputed →
    -- {paid, in_execution}; el trigger de completitud del pacto se dispara al
    -- llegar a 'paid'. (Ver CAVEAT DE DINERO en la cabecera.)
    UPDATE public.milestones
    SET state = v_milestone_new_state
    WHERE id = p_milestone_id;
  END IF;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_escrow.pact_id, 'dispute_escrow_resolved',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'resolution', p_resolution,
      'milestone_new_state', v_milestone_new_state,
      'to_promotor_cents', v_to_promotor,
      'to_constructor_cents', v_to_constructor,
      'note', p_note
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'dispute_escrow_resolved', 'dispute_escrow', v_escrow.id,
    jsonb_build_object('resolution', p_resolution, 'promotor_pct', p_promotor_pct,
                       'milestone_new_state', v_milestone_new_state));

  RETURN jsonb_build_object(
    'success', true,
    'resolution', p_resolution,
    'milestone_new_state', v_milestone_new_state,
    'to_promotor_cents', v_to_promotor,
    'to_constructor_cents', v_to_constructor,
    'state', v_final_state
  );
END;
$$;


ALTER FUNCTION "public"."sf_resolve_dispute_escrow"("p_milestone_id" "uuid", "p_resolution" "text", "p_promotor_pct" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_revoke_org_member"("p_member_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_member public.organization_members%ROWTYPE;
  v_was_invited boolean;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = auth.uid()::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_member FROM public.organization_members WHERE id = p_member_id;
  IF v_member.id IS NULL THEN RAISE EXCEPTION 'Miembro no encontrado'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = v_member.organization_id AND user_id = v_user_id
      AND role = 'owner' AND state = 'active'
  ) THEN RAISE EXCEPTION 'Solo el owner puede revocar miembros'; END IF;

  IF v_member.role = 'owner' THEN
    RAISE EXCEPTION 'No se puede revocar al owner de la organización';
  END IF;
  IF v_member.state = 'revoked' THEN
    RAISE EXCEPTION 'El miembro ya está revocado';
  END IF;

  v_was_invited := (v_member.state = 'invited');

  IF v_was_invited THEN
    -- Cancelación de invitación pendiente: borrado físico
    DELETE FROM public.organization_members WHERE id = p_member_id;
  ELSE
    -- Revocación de miembro activo: soft delete para trazabilidad
    UPDATE public.organization_members
    SET state = 'revoked', revoked_at = now(),
        revoked_reason = nullif(trim(coalesce(p_reason, '')), '')
    WHERE id = p_member_id;
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id,
    CASE WHEN v_was_invited THEN 'org_invite_cancelled' ELSE 'org_member_revoked' END,
    'organization_member', p_member_id,
    jsonb_build_object('reason', p_reason, 'was_invited', v_was_invited));

  RETURN jsonb_build_object(
    'success', true,
    'was_invitation', v_was_invited,
    'deleted', v_was_invited,
    'revoked_at', CASE WHEN NOT v_was_invited THEN now() END
  );
END; $$;


ALTER FUNCTION "public"."sf_revoke_org_member"("p_member_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_send_pact_message"("p_pact_id" "uuid", "p_body" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id     uuid;
  v_message_id  uuid;
  v_pact_state  text;
  v_body_clean  text;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  -- Bloqueamos escritura en pactos terminales (evita ensuciar
  -- histórico legal de pactos ya cerrados).
  SELECT state::text INTO v_pact_state
    FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state IN ('cancelled', 'completed_paid') THEN
    RAISE EXCEPTION 'No se puede enviar mensajes en un pacto %', v_pact_state;
  END IF;

  v_body_clean := btrim(p_body);
  IF length(v_body_clean) = 0 THEN
    RAISE EXCEPTION 'El mensaje está vacío';
  END IF;
  IF length(v_body_clean) > 2000 THEN
    RAISE EXCEPTION 'El mensaje supera 2000 caracteres';
  END IF;

  INSERT INTO public.pact_messages (pact_id, sender_user_id, body)
       VALUES (p_pact_id, v_user_id, v_body_clean)
    RETURNING id INTO v_message_id;

  -- Registrar en pact_events → dispara trigger de notificaciones (F2.4)
  -- que notifica a las demás partes. Solo enviamos un preview del body
  -- (nunca 2000 caracteres en el payload de un evento).
  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
       VALUES (
         p_pact_id,
         'pact_message_sent',
         jsonb_build_object(
           'message_id', v_message_id,
           'preview', left(v_body_clean, 140)
         ),
         v_user_id
       );

  -- Marcamos el propio mensaje como leído para el autor.
  INSERT INTO public.pact_message_reads (pact_id, user_id, last_read_at)
       VALUES (p_pact_id, v_user_id, now())
   ON CONFLICT (pact_id, user_id)
   DO UPDATE SET last_read_at = EXCLUDED.last_read_at;

  RETURN jsonb_build_object('id', v_message_id);
END;
$$;


ALTER FUNCTION "public"."sf_send_pact_message"("p_pact_id" "uuid", "p_body" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_set_my_locale"("p_locale" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_locale text;
BEGIN
  v_locale := lower(COALESCE(p_locale, ''));

  -- Se rechaza explícitamente en vez de caer a español en silencio: aquí el
  -- llamante es la app con una acción deliberada del usuario, así que un
  -- valor inválido es un bug del cliente y debe verse.
  IF v_locale NOT IN ('es', 'es-419', 'en') THEN
    RAISE EXCEPTION 'Unsupported locale: %', p_locale
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.users
     SET locale = v_locale
   WHERE auth_provider_id = (auth.uid())::text
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No profile for current user'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN v_locale;
END;
$$;


ALTER FUNCTION "public"."sf_set_my_locale"("p_locale" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_sign_contract"("p_pact_id" "uuid", "p_consent_text_hash" "text", "p_user_agent" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_party    public.pact_parties%ROWTYPE;
  v_pact_state pact_state;
  v_total_parties int;
  v_signed_parties int;
  v_new_state pact_state;
  v_signature_id text;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT * INTO v_party
  FROM public.pact_parties pp
  WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id;

  IF v_party.id IS NULL THEN
    RAISE EXCEPTION 'No formas parte de este pacto';
  END IF;

  IF v_party.accepted_at IS NULL THEN
    RAISE EXCEPTION 'Debes aceptar la invitación antes de firmar';
  END IF;

  IF v_party.signed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Ya firmaste este contrato';
  END IF;

  SELECT state INTO v_pact_state FROM public.pacts WHERE id = p_pact_id;
  IF v_pact_state NOT IN ('signing', 'inviting') THEN
    RAISE EXCEPTION 'No se puede firmar en estado: %', v_pact_state;
  END IF;

  v_signature_id := 'PS-SIG-' ||
    substring(p_pact_id::text, 1, 8) || '-' ||
    substring(v_user_id::text, 1, 8) || '-' ||
    extract(epoch from now())::bigint::text;

  UPDATE public.pact_parties
  SET
    signed_at = now(),
    signature_state = 'signed',
    signaturit_signature_id = v_signature_id,
    snapshot_role_data = coalesce(snapshot_role_data, '{}'::jsonb) ||
      jsonb_build_object(
        'signature_method', 'consent_explicit_v1',
        'consent_text_hash', p_consent_text_hash,
        'user_agent', p_user_agent,
        'signed_at_iso', now()::text
      )
  WHERE id = v_party.id;

  SELECT count(*), count(*) FILTER (WHERE signed_at IS NOT NULL)
  INTO v_total_parties, v_signed_parties
  FROM public.pact_parties WHERE pact_id = p_pact_id;

  v_new_state := v_pact_state;

  IF v_signed_parties = v_total_parties THEN
    UPDATE public.pacts SET state = 'signed' WHERE id = p_pact_id;
    v_new_state := 'signed';

    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (p_pact_id, 'contract_fully_signed',
      jsonb_build_object('parties_count', v_total_parties),
      v_user_id);
  END IF;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'contract_signed', 'pact', p_pact_id,
    jsonb_build_object(
      'role', v_party.role::text,
      'signature_id', v_signature_id,
      'consent_text_hash', p_consent_text_hash
    ));

  RETURN jsonb_build_object(
    'success', true,
    'signature_id', v_signature_id,
    'pact_state', v_new_state::text,
    'all_signed', v_signed_parties = v_total_parties
  );
END;
$$;


ALTER FUNCTION "public"."sf_sign_contract"("p_pact_id" "uuid", "p_consent_text_hash" "text", "p_user_agent" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sf_sign_contract"("p_pact_id" "uuid", "p_consent_text_hash" "text", "p_user_agent" "text") IS 'Firma con consentimiento explícito (pre-Signaturit). Cuando todos firman, pact pasa signing → signed. Guarda evidencia legal en snapshot_role_data.';



CREATE OR REPLACE FUNCTION "public"."sf_submit_milestone_for_review"("p_milestone_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid        uuid;
  v_user_id         uuid;
  v_pact_id         uuid;
  v_pact_title      text;
  v_pact_type       text;
  v_milestone_state milestone_state;
  v_milestone_name  text;
  v_can_act         boolean;
  v_evidence_count  int;
  v_target_roles    text[];
  v_recipients      uuid[];
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  SELECT m.pact_id, m.state, m.name, p.title, p.pact_type::text
    INTO v_pact_id, v_milestone_state, v_milestone_name, v_pact_title, v_pact_type
  FROM public.milestones m
  JOIN public.pacts p ON p.id = m.pact_id
  WHERE m.id = p_milestone_id;

  IF v_pact_id IS NULL THEN
    RAISE EXCEPTION 'Hito no encontrado';
  END IF;

  v_can_act := public.fn_user_acts_as_constructor_on_pact(v_pact_id, v_user_id);
  IF NOT v_can_act THEN
    RAISE EXCEPTION 'Solo el constructor (o su equipo) puede marcar el hito como listo';
  END IF;

  IF v_milestone_state NOT IN ('in_execution', 'info_requested') THEN
    RAISE EXCEPTION 'El hito no está en ejecución (estado actual: %)', v_milestone_state;
  END IF;

  SELECT count(*) INTO v_evidence_count
  FROM public.milestone_evidences
  WHERE milestone_id = p_milestone_id AND NOT is_superseded;

  IF v_evidence_count < 1 THEN
    RAISE EXCEPTION 'Debes subir al menos 1 evidencia antes de marcar el hito como listo';
  END IF;

  UPDATE public.milestones
  SET state = 'ready_for_review', submitted_at = now()
  WHERE id = p_milestone_id;

  INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
  VALUES (v_pact_id, 'milestone_submitted_for_review',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'evidence_count', v_evidence_count
    ),
    v_user_id);

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'milestone_submitted', 'milestone', p_milestone_id,
    jsonb_build_object('evidence_count', v_evidence_count));

  -- En obra mayor revisa el técnico; en obra menor revisa el promotor.
  v_target_roles := CASE v_pact_type
                      WHEN 'obra_mayor' THEN ARRAY['tecnico']
                      ELSE ARRAY['promotor']
                    END;

  SELECT array_agg(user_id) INTO v_recipients
  FROM public.fn_notification_recipients(
    v_pact_id, v_target_roles, false, v_user_id
  );

  PERFORM public.fn_create_notifications(
    p_user_ids        := v_recipients,
    p_notification_type := 'milestone_submitted',
    p_title           := 'Hito listo para revisar · ' || coalesce(v_milestone_name, 'Sin nombre'),
    p_body            := 'El constructor ha enviado el hito de "' ||
                         coalesce(v_pact_title, 'la obra') || '" para tu validación con ' ||
                         v_evidence_count::text || ' evidencia' ||
                         CASE WHEN v_evidence_count = 1 THEN '' ELSE 's' END || '.',
    p_pact_id         := v_pact_id,
    p_milestone_id    := p_milestone_id,
    p_cta_url         := '/pacts/' || v_pact_id::text || '/milestones/' || p_milestone_id::text,
    p_priority        := 'high',
    p_idempotency_root := 'milestone_submitted:' || p_milestone_id::text
  );

  RETURN jsonb_build_object(
    'success', true,
    'milestone_state', 'ready_for_review',
    'evidence_count', v_evidence_count
  );
END;
$$;


ALTER FUNCTION "public"."sf_submit_milestone_for_review"("p_milestone_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_unread_pact_messages_count"("p_pact_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id      uuid;
  v_last_read_at timestamptz;
  v_count        int;
BEGIN
  SELECT u.id INTO v_user_id FROM public.users u
   WHERE u.auth_provider_id = auth.uid()::text
     AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  IF NOT public.fn_user_can_act_on_pact(p_pact_id, v_user_id) THEN
    RAISE EXCEPTION 'No perteneces a este pacto';
  END IF;

  SELECT last_read_at INTO v_last_read_at
    FROM public.pact_message_reads
   WHERE pact_id = p_pact_id AND user_id = v_user_id;

  SELECT count(*) INTO v_count
    FROM public.pact_messages m
   WHERE m.pact_id = p_pact_id
     AND m.deleted_at IS NULL
     AND m.sender_user_id <> v_user_id
     AND (v_last_read_at IS NULL OR m.created_at > v_last_read_at);

  RETURN coalesce(v_count, 0);
END;
$$;


ALTER FUNCTION "public"."sf_unread_pact_messages_count"("p_pact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_update_member_permissions"("p_member_id" "uuid", "p_can_view_economics" boolean DEFAULT NULL::boolean, "p_receive_notifications" boolean DEFAULT NULL::boolean, "p_receive_economic_notifications" boolean DEFAULT NULL::boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_member   public.organization_members%ROWTYPE;
BEGIN
  v_auth_uid := auth.uid();
  SELECT u.id INTO v_user_id FROM public.users u
  WHERE u.auth_provider_id = v_auth_uid::text AND u.deleted_at IS NULL;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Perfil no encontrado'; END IF;

  SELECT * INTO v_member FROM public.organization_members
  WHERE id = p_member_id;
  IF v_member.id IS NULL THEN
    RAISE EXCEPTION 'Miembro no encontrado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = v_member.organization_id
      AND user_id = v_user_id
      AND role = 'owner'
      AND state = 'active'
  ) THEN
    RAISE EXCEPTION 'Solo el owner puede modificar permisos';
  END IF;

  IF v_member.role = 'owner' THEN
    RAISE EXCEPTION 'Los permisos del owner no se pueden modificar';
  END IF;

  UPDATE public.organization_members
  SET can_view_economics             = coalesce(p_can_view_economics, can_view_economics),
      receive_notifications          = coalesce(p_receive_notifications, receive_notifications),
      receive_economic_notifications = coalesce(p_receive_economic_notifications, receive_economic_notifications)
  WHERE id = p_member_id;

  INSERT INTO public.audit_log (actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (v_user_id, 'org_member_perms_updated', 'organization_member', p_member_id,
    jsonb_build_object(
      'can_view_economics', p_can_view_economics,
      'receive_notifications', p_receive_notifications,
      'receive_economic_notifications', p_receive_economic_notifications
    ));

  RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."sf_update_member_permissions"("p_member_id" "uuid", "p_can_view_economics" boolean, "p_receive_notifications" boolean, "p_receive_economic_notifications" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_update_my_profile"("p_full_name" "text" DEFAULT NULL::"text", "p_phone_e164" "text" DEFAULT NULL::"text", "p_avatar_url" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM public.users
  WHERE auth_provider_id = auth.uid()::text
    AND deleted_at IS NULL
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Perfil no encontrado';
  END IF;

  UPDATE public.users
  SET
    full_name  = COALESCE(p_full_name,  full_name),
    phone_e164 = COALESCE(p_phone_e164, phone_e164),
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    updated_at = now()
  WHERE id = v_user_id;
END;
$$;


ALTER FUNCTION "public"."sf_update_my_profile"("p_full_name" "text", "p_phone_e164" "text", "p_avatar_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sf_write_pact_plan"("p_pact_id" "uuid", "p_items" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_item    jsonb;
  v_ordinal smallint := 0;
BEGIN
  DELETE FROM public.pact_plan_items WHERE pact_id = p_pact_id;
  FOR v_item IN SELECT * FROM jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  LOOP
    v_ordinal := v_ordinal + 1;
    INSERT INTO public.pact_plan_items
      (pact_id, ordinal, name, description, amount_cents, percentage, kind)
    VALUES (
      p_pact_id,
      v_ordinal,
      coalesce(nullif(trim(v_item ->> 'name'), ''), 'Hito ' || v_ordinal),
      nullif(trim(v_item ->> 'description'), ''),
      greatest(coalesce((v_item ->> 'amount_cents')::bigint, 0), 0),
      (v_item ->> 'percentage')::numeric,
      public.sf_plan_item_kind(v_item ->> 'trigger')
    );
  END LOOP;
  RETURN v_ordinal;
END;
$$;


ALTER FUNCTION "public"."sf_write_pact_plan"("p_pact_id" "uuid", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_pact_type_requires_tecnico"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.requires_tecnico := (NEW.pact_type = 'obra_mayor');
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_pact_type_requires_tecnico"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_in_pact"("p_pact_id" "uuid", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM pact_parties pp
    WHERE pp.pact_id = p_pact_id
    AND (pp.user_id = p_user_id
         OR (pp.organization_id IS NOT NULL AND pp.organization_id IN
             (SELECT organization_id FROM users WHERE id = p_user_id AND organization_id IS NOT NULL)))
  )
$$;


ALTER FUNCTION "public"."user_in_pact"("p_pact_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_milestone_state_transition"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  valid_transitions text[];
BEGIN
  IF OLD.state = NEW.state THEN
    RETURN NEW;
  END IF;

  valid_transitions := CASE OLD.state
    -- v1
    WHEN 'pending'           THEN ARRAY['in_execution', 'pending_predeposit']
    WHEN 'in_execution'      THEN ARRAY['ready_for_review', 'paused_no_predeposit']
    WHEN 'ready_for_review'  THEN ARRAY['in_validation']
    WHEN 'in_validation'     THEN ARRAY['approved_by_tech', 'rejected_by_tech', 'info_requested']
    WHEN 'info_requested'    THEN ARRAY['ready_for_review']
    WHEN 'rejected_by_tech'  THEN ARRAY['in_execution', 'disputed']
    WHEN 'approved_by_tech'  THEN ARRAY['awaiting_promotor', 'disputed']
    WHEN 'awaiting_promotor' THEN ARRAY['paid', 'disputed']
    WHEN 'disputed'          THEN ARRAY['paid', 'awaiting_promotor', 'in_execution']
    -- v2.1
    WHEN 'pending_predeposit'   THEN ARRAY['in_execution', 'paused_no_predeposit']
    WHEN 'paused_no_predeposit' THEN ARRAY['in_execution', 'pending_predeposit']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (NEW.state::text = ANY(valid_transitions)) THEN
    RAISE EXCEPTION 'Transición de estado de hito inválida: % → %', OLD.state, NEW.state;
  END IF;

  INSERT INTO milestone_state_transitions(milestone_id, from_state, to_state, transitioned_by_user_id)
  VALUES (NEW.id, OLD.state, NEW.state, current_user_id());

  NEW.state_updated_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_milestone_state_transition"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_pact_state_transition"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  valid_transitions text[];
BEGIN
  IF OLD.state = NEW.state THEN
    RETURN NEW;
  END IF;
  valid_transitions := CASE OLD.state
    WHEN 'draft' THEN ARRAY['inviting', 'cancelled']
    WHEN 'inviting' THEN ARRAY['signing', 'cancelled']
    WHEN 'signing' THEN ARRAY['signed', 'cancelled']
    WHEN 'signed' THEN ARRAY['funded', 'cancelled']
    WHEN 'funded' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'in_execution' THEN ARRAY['paused_pending_tech', 'disputed', 'completed', 'suspended']
    WHEN 'paused_pending_tech' THEN ARRAY['in_execution', 'disputed', 'cancelled']
    WHEN 'disputed' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'suspended' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'completed' THEN ARRAY['closed']
    ELSE ARRAY[]::text[]
  END;
  IF NOT (NEW.state::text = ANY(valid_transitions)) THEN
    RAISE EXCEPTION 'Transición de estado de pacto inválida: % → %', OLD.state, NEW.state;
  END IF;
  INSERT INTO pact_state_transitions(pact_id, from_state, to_state, transitioned_by_user_id)
  VALUES (NEW.id, OLD.state, NEW.state, current_user_id());
  NEW.state_updated_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_pact_state_transition"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."acopio_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "description" "text" NOT NULL,
    "material_type" "text" DEFAULT 'generic'::"text" NOT NULL,
    "estimated_cents" bigint NOT NULL,
    "actual_cents" bigint,
    "supplier_name" "text",
    "supplier_cif" "text",
    "invoice_ref" "text",
    "invoice_storage_path" "text",
    "invoice_sha256" "text",
    "state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "purchased_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "verified_at" timestamp with time zone,
    "released_at" timestamp with time zone,
    "released_cents" bigint DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "acopio_items_estimated_cents_check" CHECK (("estimated_cents" > 0)),
    CONSTRAINT "acopio_items_state_check" CHECK (("state" = ANY (ARRAY['pending'::"text", 'quoted'::"text", 'purchased'::"text", 'delivered'::"text", 'verified'::"text", 'released'::"text"])))
);


ALTER TABLE "public"."acopio_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ai_assistant_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "content" "text",
    "content_blocks" "jsonb",
    "tool_call_name" "text",
    "tool_call_input" "jsonb",
    "tool_call_status" "text",
    "tool_call_result" "jsonb",
    "feedback" "text",
    "provider" "text",
    "model" "text",
    "prompt_version" "text",
    "input_tokens" integer,
    "output_tokens" integer,
    "cost_cents" bigint DEFAULT 0 NOT NULL,
    "latency_ms" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ai_assistant_messages_feedback_check" CHECK ((("feedback" IS NULL) OR ("feedback" = ANY (ARRAY['up'::"text", 'down'::"text"])))),
    CONSTRAINT "ai_assistant_messages_provider_check" CHECK ((("provider" IS NULL) OR ("provider" = ANY (ARRAY['demo'::"text", 'live'::"text"])))),
    CONSTRAINT "ai_assistant_messages_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'assistant'::"text", 'tool_result'::"text"]))),
    CONSTRAINT "ai_assistant_messages_tool_call_status_check" CHECK ((("tool_call_status" IS NULL) OR ("tool_call_status" = ANY (ARRAY['proposed'::"text", 'confirmed'::"text", 'executed'::"text", 'cancelled'::"text"]))))
);


ALTER TABLE "public"."ai_assistant_messages" OWNER TO "postgres";


COMMENT ON TABLE "public"."ai_assistant_messages" IS 'IA · Turnos del asistente conversacional embebido en cada pacto. Separado de la tabla messages (chat humano) para no contaminar conversaciones. Hilo aislado por usuario: cada parte ve solo su hilo, admin ve todos.';



CREATE TABLE IF NOT EXISTS "public"."ai_fixtures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "fixture_key" "text" NOT NULL,
    "fixture_type" "public"."ai_fixture_type" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ai_fixtures" OWNER TO "postgres";


COMMENT ON TABLE "public"."ai_fixtures" IS 'IA · Fixtures editables in-app que alimentan Demo Mode. Cada fila es una respuesta pre-grabada (dictamen Vision o intent del asistente). Editar en caliente desde el panel admin sin tocar código.';



CREATE TABLE IF NOT EXISTS "public"."ai_prompts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prompt_key" "text" NOT NULL,
    "version" "text" NOT NULL,
    "system_prompt" "text" NOT NULL,
    "schema" "jsonb",
    "is_active" boolean DEFAULT false NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by_user_id" "uuid"
);


ALTER TABLE "public"."ai_prompts" OWNER TO "postgres";


COMMENT ON TABLE "public"."ai_prompts" IS 'IA · Store de prompts versionados. Cambiar de versión es UPDATE is_active = false / true sin redeploy. Auditoría completa de qué prompt generó qué dictum.';



CREATE TABLE IF NOT EXISTS "public"."ai_runs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "run_type" "text" NOT NULL,
    "pact_id" "uuid",
    "milestone_id" "uuid",
    "user_uid_hash" "text",
    "provider" "text" NOT NULL,
    "model" "text",
    "prompt_version" "text",
    "input_tokens" integer,
    "output_tokens" integer,
    "cache_read_tokens" integer,
    "cost_cents" bigint DEFAULT 0 NOT NULL,
    "duration_ms" integer,
    "success" boolean NOT NULL,
    "error_code" "text",
    "error_message" "text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ai_runs_cache_read_tokens_check" CHECK ((("cache_read_tokens" IS NULL) OR ("cache_read_tokens" >= 0))),
    CONSTRAINT "ai_runs_cost_cents_check" CHECK (("cost_cents" >= 0)),
    CONSTRAINT "ai_runs_duration_ms_check" CHECK ((("duration_ms" IS NULL) OR ("duration_ms" >= 0))),
    CONSTRAINT "ai_runs_input_tokens_check" CHECK ((("input_tokens" IS NULL) OR ("input_tokens" >= 0))),
    CONSTRAINT "ai_runs_output_tokens_check" CHECK ((("output_tokens" IS NULL) OR ("output_tokens" >= 0))),
    CONSTRAINT "ai_runs_provider_check" CHECK (("provider" = ANY (ARRAY['demo'::"text", 'live'::"text"]))),
    CONSTRAINT "ai_runs_run_type_check" CHECK (("run_type" = ANY (ARRAY['vision'::"text", 'assistant'::"text", 'tool_execute'::"text"])))
);


ALTER TABLE "public"."ai_runs" OWNER TO "postgres";


COMMENT ON TABLE "public"."ai_runs" IS 'IA · Telemetría cross-pact de cada invocación al gateway IA. Sin PII. Alimenta dashboard admin de coste, latencia, errores y kill switch.';



CREATE TABLE IF NOT EXISTS "public"."api_key_usage" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "api_key_id" "uuid" NOT NULL,
    "partner_id" "text" NOT NULL,
    "endpoint" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."api_key_usage" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."api_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "partner_id" "text" NOT NULL,
    "label" "text" DEFAULT ''::"text" NOT NULL,
    "key_hash" "text" NOT NULL,
    "scopes" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "rate_limit_rpm" integer DEFAULT 60 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone
);


ALTER TABLE "public"."api_keys" OWNER TO "postgres";


COMMENT ON TABLE "public"."api_keys" IS 'API keys for external partner integrations';



COMMENT ON COLUMN "public"."api_keys"."key_hash" IS 'SHA-256 hex digest — never store raw keys';



CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "description" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_by_user_id" "uuid"
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


COMMENT ON TABLE "public"."app_settings" IS 'Configuración operativa interna (kv). Solo service_role lee/escribe. Auditoría 16-jul: se retiró la policy app_settings_select_all USING(true).';



CREATE TABLE IF NOT EXISTS "public"."audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "actor_user_id" "uuid",
    "action" "text" NOT NULL,
    "entity_type" "text",
    "entity_id" "uuid",
    "ip_address" "inet",
    "user_agent" "text",
    "metadata" "jsonb",
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cae_enlaces_cliente" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "expediente_id" "uuid" NOT NULL,
    "token_sha256" "text" NOT NULL,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expira_at" timestamp with time zone NOT NULL,
    "revocado_at" timestamp with time zone,
    "aperturas" integer DEFAULT 0 NOT NULL,
    "primera_apertura_at" timestamp with time zone,
    "ultima_apertura_at" timestamp with time zone
);


ALTER TABLE "public"."cae_enlaces_cliente" OWNER TO "postgres";


COMMENT ON TABLE "public"."cae_enlaces_cliente" IS 'Enlaces con los que el propietario ve su obra sin tener cuenta. Registrar la apertura no es telemetría: es la prueba de que la empresa informó al cliente y cuándo, y le sirve a ella el día que haya discusión.';



CREATE TABLE IF NOT EXISTS "public"."cae_expedientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "pact_id" "uuid",
    "ficha_codigo" "text" NOT NULL,
    "ficha_version" "text" NOT NULL,
    "comunidad_autonoma" "public"."cae_comunidad" NOT NULL,
    "anio_ejecucion" integer NOT NULL,
    "direccion" "text" NOT NULL,
    "datos_calculo" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "ahorro_kwh" integer,
    "estado" "public"."cae_estado_expediente" DEFAULT 'borrador'::"public"."cae_estado_expediente" NOT NULL,
    "ayuda_fnee" boolean DEFAULT false NOT NULL,
    "lote_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "importe_obra_eur" numeric,
    "obra_iniciada_at" timestamp with time zone,
    CONSTRAINT "cae_exp_ahorro_no_negativo" CHECK ((("ahorro_kwh" IS NULL) OR ("ahorro_kwh" >= 0))),
    CONSTRAINT "cae_exp_anio_plausible" CHECK ((("anio_ejecucion" >= 2023) AND ("anio_ejecucion" <= 2100))),
    CONSTRAINT "cae_exp_direccion_no_vacia" CHECK (("length"("btrim"("direccion")) > 0)),
    CONSTRAINT "cae_exp_en_lote_coherente" CHECK ((("estado" <> 'en_lote'::"public"."cae_estado_expediente") OR ("lote_id" IS NOT NULL))),
    CONSTRAINT "cae_exp_ficha_conocida" CHECK (("ficha_codigo" = ANY (ARRAY['RES022'::"text", 'RES060'::"text"]))),
    CONSTRAINT "cae_exp_lote_solo_en_estados" CHECK ((("lote_id" IS NULL) OR ("estado" = ANY (ARRAY['en_lote'::"public"."cae_estado_expediente", 'entregado'::"public"."cae_estado_expediente"]))))
);


ALTER TABLE "public"."cae_expedientes" OWNER TO "postgres";


COMMENT ON COLUMN "public"."cae_expedientes"."pact_id" IS 'Opcional a propósito. El escrow no tiene licencia; si el expediente exigiera un pacto, el vertical heredaría ese bloqueo.';



COMMENT ON COLUMN "public"."cae_expedientes"."ficha_version" IS 'Versión APLICADA, no la vigente. Un expediente se juzga con la ficha de su momento.';



COMMENT ON COLUMN "public"."cae_expedientes"."ayuda_fnee" IS 'Orden TED/815/2023 art. 14.8: una actuación con ayuda del FNEE NO puede generar CAE. No puede entrar en ningún lote.';



COMMENT ON COLUMN "public"."cae_expedientes"."importe_obra_eur" IS 'Importe de la obra en euros. Sirve para decirle al cliente CUÁNTO pierde de deducción, no solo que la pierde. Anulable: un expediente puede nacer antes de que haya oferta cerrada, y el aviso cualitativo funciona igual sin él.';



COMMENT ON COLUMN "public"."cae_expedientes"."obra_iniciada_at" IS 'Fecha declarada de inicio de obra. Es INDEPENDIENTE de `estado`, a propósito: el estado depende de la puerta del certificado energético previo (un expediente sin ese papel no puede salir de «borrador» aunque la obra ya haya arrancado), así que el estado NO sirve para saber si la obra empezó. Sin esta columna no se puede afirmar que la obra no ha empezado: NULL significa «no consta», nunca «no ha empezado». Se rellena y se vacía desde la ficha del expediente sin pasar por la puerta del certificado — precisamente el caso que importa es declarar el inicio de una obra que sigue en borrador.';



CREATE TABLE IF NOT EXISTS "public"."cae_lotes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "comunidad_autonoma" "public"."cae_comunidad" NOT NULL,
    "anio" integer NOT NULL,
    "estado" "public"."cae_estado_lote" DEFAULT 'abierto'::"public"."cae_estado_lote" NOT NULL,
    "delegado_nombre" "text",
    "entregado_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cae_lotes_anio_plausible" CHECK ((("anio" >= 2023) AND ("anio" <= 2100))),
    CONSTRAINT "cae_lotes_entregado_con_fecha" CHECK ((("estado" = 'entregado'::"public"."cae_estado_lote") = ("entregado_at" IS NOT NULL)))
);


ALTER TABLE "public"."cae_lotes" OWNER TO "postgres";


COMMENT ON TABLE "public"."cae_lotes" IS 'Agrupación de expedientes CAE para una solicitud de emisión. El mínimo de 30 MWh (Orden TED/815/2023 art. 14.6) NO se almacena: se calcula sumando los expedientes del lote. Ojo: ese mínimo NO aplica en Ceuta y Melilla.';



CREATE TABLE IF NOT EXISTS "public"."cae_requisitos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "expediente_id" "uuid" NOT NULL,
    "clave" "text" NOT NULL,
    "estado" "public"."cae_estado_requisito" DEFAULT 'pendiente'::"public"."cae_estado_requisito" NOT NULL,
    "document_id" "uuid",
    "nota" "text",
    "actualizado_por" "uuid",
    "actualizado_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cae_req_aportado_con_documento" CHECK ((("estado" <> ALL (ARRAY['aportado'::"public"."cae_estado_requisito", 'verificado'::"public"."cae_estado_requisito"])) OR ("document_id" IS NOT NULL))),
    CONSTRAINT "cae_req_clave_formato" CHECK (("clave" ~ '^[a-z0-9_]+$'::"text"))
);


ALTER TABLE "public"."cae_requisitos" OWNER TO "postgres";


COMMENT ON TABLE "public"."cae_requisitos" IS 'Estado de cada requisito documental. El CATÁLOGO de qué requisitos tiene cada ficha vive en src/lib/cae/requisitos.ts del front: es dato normativo y se revisa como código.';



CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deposit_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "movement_type" "public"."deposit_movement_type" NOT NULL,
    "amount_cents" bigint NOT NULL,
    "triggered_by_user_id" "uuid",
    "related_milestone_id" "uuid",
    "related_addendum_id" "uuid",
    "balance_before_cents" bigint NOT NULL,
    "balance_after_cents" bigint NOT NULL,
    "mangopay_transaction_id" "text",
    "notes" "text",
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "deposit_movements_balance_after_cents_check" CHECK (("balance_after_cents" >= 0)),
    CONSTRAINT "deposit_movements_balance_before_cents_check" CHECK (("balance_before_cents" >= 0))
);


ALTER TABLE "public"."deposit_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispute_contributions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dispute_id" "uuid" NOT NULL,
    "contributor_user_id" "uuid" NOT NULL,
    "contributor_role" "public"."pact_party_role" NOT NULL,
    "contribution_text" "text",
    "attached_evidence_ids" "uuid"[],
    "attached_doc_ids" "uuid"[],
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."dispute_contributions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispute_escrows" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "dispute_amount_cents" bigint NOT NULL,
    "escrow_amount_cents" bigint NOT NULL,
    "escrow_pct_used" numeric(5,2) NOT NULL,
    "state" "text" DEFAULT 'pending_deposit'::"text" NOT NULL,
    "deposited_at" timestamp with time zone,
    "resolved_at" timestamp with time zone,
    "resolution_note" "text",
    "released_to_promotor_cents" bigint DEFAULT 0,
    "released_to_constructor_cents" bigint DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "dispute_escrows_escrow_amount_cents_check" CHECK (("escrow_amount_cents" > 0)),
    CONSTRAINT "dispute_escrows_state_check" CHECK (("state" = ANY (ARRAY['pending_deposit'::"text", 'deposited'::"text", 'released_to_promotor'::"text", 'released_to_constructor'::"text", 'split'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."dispute_escrows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."disputes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "display_id" "text" NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "amount_held_cents" bigint NOT NULL,
    "state" "public"."dispute_state" DEFAULT 'opened'::"public"."dispute_state" NOT NULL,
    "state_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "first_response_due_at" timestamp with time zone NOT NULL,
    "resolution_due_at" timestamp with time zone NOT NULL,
    "outcome" "public"."dispute_outcome" DEFAULT 'pending'::"public"."dispute_outcome" NOT NULL,
    "outcome_amount_to_constructor_cents" bigint DEFAULT 0,
    "outcome_amount_refund_promotor_cents" bigint DEFAULT 0,
    "outcome_rationale" "text",
    "resolved_at" timestamp with time zone,
    "resolution_doc_id" "uuid",
    "accepted_by_promotor_at" timestamp with time zone,
    "accepted_by_constructor_at" timestamp with time zone,
    "accepted_by_tecnico_at" timestamp with time zone,
    "closed_at" timestamp with time zone
);


ALTER TABLE "public"."disputes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid",
    "doc_type" "public"."document_type" NOT NULL,
    "display_id" "text",
    "storage_path" "text" NOT NULL,
    "file_size_bytes" bigint,
    "mime_type" "text" DEFAULT 'application/pdf'::"text" NOT NULL,
    "sha256_hash" "text" NOT NULL,
    "pages" smallint,
    "generated_by" "text",
    "uploaded_by_user_id" "uuid",
    "signature_id" "uuid",
    "signed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "retention_until" timestamp with time zone DEFAULT ("now"() + '10 years'::interval) NOT NULL
);


ALTER TABLE "public"."documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ipc_indices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "year_month" "text" NOT NULL,
    "index_value" numeric(8,3) NOT NULL,
    "variation_monthly_pct" numeric(6,3),
    "variation_annual_pct" numeric(6,3),
    "source" "text" DEFAULT 'INE'::"text" NOT NULL,
    "published_at" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ipc_indices" OWNER TO "postgres";


COMMENT ON TABLE "public"."ipc_indices" IS 'Serie del IPC del INE. Alimentada por Edge Function ipc-updater (cron mensual).';



CREATE TABLE IF NOT EXISTS "public"."legal_consents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "doc_type" "public"."legal_doc_type" NOT NULL,
    "doc_version" "text" NOT NULL,
    "doc_hash" "text" NOT NULL,
    "consented_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ip_address" "inet",
    "user_agent" "text",
    "revoked_at" timestamp with time zone
);


ALTER TABLE "public"."legal_consents" OWNER TO "postgres";


COMMENT ON TABLE "public"."legal_consents" IS 'Trazabilidad de aceptación de Términos, Privacidad, Cookies y Consentimiento Biométrico. Append-only.';



CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_user_id" "uuid",
    "is_system_event" boolean DEFAULT false NOT NULL,
    "event_type" "text",
    "body" "text",
    "attached_doc_ids" "uuid"[],
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."milestone_ai_verifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "provider" "text" NOT NULL,
    "model" "text" NOT NULL,
    "prompt_version" "text" NOT NULL,
    "input_hash_sha256" "text" NOT NULL,
    "evidences_count" smallint NOT NULL,
    "documents_count" smallint NOT NULL,
    "score" smallint NOT NULL,
    "verdict" "public"."ai_verdict" NOT NULL,
    "summary" "text" NOT NULL,
    "findings" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "checklist_match" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "recommendation" "text",
    "input_tokens" integer,
    "output_tokens" integer,
    "cache_read_tokens" integer,
    "cost_cents" bigint DEFAULT 0 NOT NULL,
    "duration_ms" integer,
    "reviewed_by_user_id" "uuid",
    "reviewed_at" timestamp with time zone,
    "justifications" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "milestone_ai_verifications_documents_count_check" CHECK (("documents_count" >= 0)),
    CONSTRAINT "milestone_ai_verifications_evidences_count_check" CHECK (("evidences_count" >= 0)),
    CONSTRAINT "milestone_ai_verifications_provider_check" CHECK (("provider" = ANY (ARRAY['demo'::"text", 'live'::"text"]))),
    CONSTRAINT "milestone_ai_verifications_score_check" CHECK ((("score" >= 0) AND ("score" <= 100)))
);


ALTER TABLE "public"."milestone_ai_verifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."milestone_ai_verifications" IS 'IA · Dictamen de Claude Vision por certificación. Append-only en campos del modelo (score/verdict/findings); reviewed_*/justifications son mutables para que el técnico documente sus decisiones sobre el dictamen.';



COMMENT ON COLUMN "public"."milestone_ai_verifications"."input_hash_sha256" IS 'SHA-256 del payload exacto enviado al modelo. Permite verificar que el dictamen no se ha modificado y reproducir la llamada si fuera necesario.';



COMMENT ON COLUMN "public"."milestone_ai_verifications"."justifications" IS 'Array de { finding_id, note, user_uid } con las justificaciones que el técnico añadió antes de firmar pese al hallazgo. Solo modificable vía RPC.';



CREATE TABLE IF NOT EXISTS "public"."milestone_evidences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "uploaded_by_user_id" "uuid" NOT NULL,
    "evidence_type" "public"."evidence_type" NOT NULL,
    "storage_path" "text" NOT NULL,
    "file_size_bytes" bigint,
    "mime_type" "text",
    "sha256_hash" "text" NOT NULL,
    "exif_metadata" "jsonb",
    "gps_latitude" numeric(10,7),
    "gps_longitude" numeric(10,7),
    "gps_accuracy_meters" numeric(8,2),
    "obra_distance_meters" numeric(10,2),
    "geolocation_verification" "public"."evidence_verification" DEFAULT 'pending'::"public"."evidence_verification" NOT NULL,
    "client_timestamp" timestamp with time zone,
    "server_timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tsa_timestamp_token" "text",
    "tsa_provider" "text" DEFAULT 'signaturit_tsa'::"text",
    "description" "text",
    "technical_notes" "text",
    "is_superseded" boolean DEFAULT false NOT NULL,
    "superseded_by_id" "uuid",
    "superseded_at" timestamp with time zone,
    CONSTRAINT "milestone_evidences_no_update" CHECK ((1 = 1))
);


ALTER TABLE "public"."milestone_evidences" OWNER TO "postgres";


COMMENT ON TABLE "public"."milestone_evidences" IS 'Evidencias del trabajo. APPEND-ONLY: timestamp servidor, GPS y hash son inmutables. Solo se puede marcar como superseded.';



COMMENT ON COLUMN "public"."milestone_evidences"."geolocation_verification" IS 'Resultado del contraste entre la ubicación de la evidencia y la de la obra. Nace como pending: el sellado (hash, hora de servidor, GPS) sí está garantizado, pero la verificación geográfica todavía no está implementada. No afirmar que la evidencia se verifica contra el catastro hasta que exista.';



CREATE TABLE IF NOT EXISTS "public"."milestone_objections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "raised_by_user_id" "uuid" NOT NULL,
    "raised_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reason_categories" "text"[] NOT NULL,
    "reason_detail" "text" NOT NULL,
    "resulting_dispute_id" "uuid"
);


ALTER TABLE "public"."milestone_objections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."milestone_state_transitions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "from_state" "public"."milestone_state",
    "to_state" "public"."milestone_state" NOT NULL,
    "transitioned_by_user_id" "uuid",
    "reason" "text",
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."milestone_state_transitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."milestone_validations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "validator_user_id" "uuid" NOT NULL,
    "decision" "public"."validation_decision" NOT NULL,
    "decision_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rationale" "text",
    "technical_specs_check" "jsonb",
    "critical_checks_check" "jsonb",
    "requested_info_categories" "text"[],
    "requested_info_text" "text",
    "certificate_doc_id" "uuid"
);


ALTER TABLE "public"."milestone_validations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."milestones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "display_id" "text" NOT NULL,
    "ordinal" smallint NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "amount_cents" bigint NOT NULL,
    "target_date" "date",
    "technical_specs" "jsonb",
    "critical_checks" "jsonb",
    "state" "public"."milestone_state" DEFAULT 'pending'::"public"."milestone_state" NOT NULL,
    "state_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "objection_window_hours" smallint DEFAULT 48 NOT NULL,
    "started_at" timestamp with time zone,
    "submitted_at" timestamp with time zone,
    "validated_at" timestamp with time zone,
    "approved_by_promotor_at" timestamp with time zone,
    "rejected_at" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "payment_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "version" smallint DEFAULT 1 NOT NULL,
    "previous_version_id" "uuid",
    "detailed_doc_storage_path" "text",
    "detailed_doc_sha256" "text",
    "detailed_doc_mime_type" "text",
    "detailed_doc_size_bytes" bigint,
    "invoice_storage_path" "text",
    "invoice_sha256" "text",
    "invoice_number" "text",
    "invoice_size_bytes" bigint,
    "advance_amortization_cents" bigint DEFAULT 0 NOT NULL,
    "net_amount_cents" bigint GENERATED ALWAYS AS (("amount_cents" - "advance_amortization_cents")) STORED,
    "predeposit_received_cents" bigint DEFAULT 0 NOT NULL,
    "predeposit_deadline_at" timestamp with time zone,
    "forced_under_responsibility" boolean DEFAULT false NOT NULL,
    "forced_under_responsibility_at" timestamp with time zone,
    "quality_holdback_cents" bigint DEFAULT 0 NOT NULL,
    "net_paid_cents" bigint,
    "category" "text" DEFAULT 'certification'::"text" NOT NULL,
    "original_amount_cents" bigint,
    "ipc_adjustment_pct" numeric(6,3) DEFAULT 0,
    "ipc_applied_month" "text",
    CONSTRAINT "milestones_advance_amortization_cents_check" CHECK (("advance_amortization_cents" >= 0)),
    CONSTRAINT "milestones_amount_cents_check" CHECK (("amount_cents" > 0)),
    CONSTRAINT "milestones_category_check" CHECK (("category" = ANY (ARRAY['certification'::"text", 'acopio'::"text", 'retention'::"text"]))),
    CONSTRAINT "milestones_detailed_doc_size_bytes_check" CHECK ((("detailed_doc_size_bytes" IS NULL) OR ("detailed_doc_size_bytes" > 0))),
    CONSTRAINT "milestones_invoice_size_bytes_check" CHECK ((("invoice_size_bytes" IS NULL) OR ("invoice_size_bytes" > 0))),
    CONSTRAINT "milestones_predeposit_received_cents_check" CHECK (("predeposit_received_cents" >= 0)),
    CONSTRAINT "milestones_version_check" CHECK (("version" >= 1))
);


ALTER TABLE "public"."milestones" OWNER TO "postgres";


COMMENT ON TABLE "public"."milestones" IS 'Hitos del pacto. Suma de amount_cents debe igualar el total del pacto (validar por trigger).';



COMMENT ON COLUMN "public"."milestones"."advance_amortization_cents" IS 'v2.1 · Importe que esta certificación amortiza del adelanto entregado al constructor (= amount_cents * advance_pct / 100).';



COMMENT ON COLUMN "public"."milestones"."net_amount_cents" IS 'v2.1 · Importe neto a pagar al constructor (bruto - amortización). Columna calculada automáticamente.';



COMMENT ON COLUMN "public"."milestones"."predeposit_received_cents" IS 'v2.1 · Importe que el promotor ha pre-depositado en custodia para esta certificación. Debe igualar net_amount_cents antes de que se pueda emitir.';



COMMENT ON COLUMN "public"."milestones"."predeposit_deadline_at" IS 'v2.1 · Plazo límite (3 días desde creación del borrador) para que el promotor complete el pre-depósito. Si expira, la cert pasa a paused_no_predeposit.';



COMMENT ON COLUMN "public"."milestones"."forced_under_responsibility" IS 'v2.1 · El constructor decidió avanzar sin pre-depósito completo, asumiendo el riesgo. Libera a PactStream/aseguradora de responsabilidad sobre lo ejecutado en este intervalo.';



COMMENT ON COLUMN "public"."milestones"."quality_holdback_cents" IS 'Importe retenido por baja calidad documental (IA score < umbral)';



COMMENT ON COLUMN "public"."milestones"."net_paid_cents" IS 'Importe efectivamente pagado al constructor (amount_cents - quality_holdback_cents)';



COMMENT ON COLUMN "public"."milestones"."category" IS 'Tipo de hito: certification (normal), acopio (escrow materiales), retention (reserva final)';



COMMENT ON COLUMN "public"."milestones"."original_amount_cents" IS 'Importe original antes de ajuste IPC (null si no hay ajuste)';



COMMENT ON COLUMN "public"."milestones"."ipc_adjustment_pct" IS 'Porcentaje de ajuste IPC aplicado sobre el original';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pact_id" "uuid",
    "milestone_id" "uuid",
    "notification_type" "text" NOT NULL,
    "channel" "public"."notification_channel" NOT NULL,
    "priority" "public"."notification_priority" DEFAULT 'normal'::"public"."notification_priority" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "cta_url" "text",
    "sent_at" timestamp with time zone,
    "read_at" timestamp with time zone,
    "clicked_at" timestamp with time zone,
    "failed_at" timestamp with time zone,
    "failure_reason" "text",
    "idempotency_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "invited_email" "text" NOT NULL,
    "full_name" "text",
    "role" "public"."org_member_role" DEFAULT 'member'::"public"."org_member_role" NOT NULL,
    "can_view_economics" boolean DEFAULT false NOT NULL,
    "state" "public"."org_member_state" DEFAULT 'invited'::"public"."org_member_state" NOT NULL,
    "invitation_token" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "invited_by_user_id" "uuid" NOT NULL,
    "invited_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accepted_at" timestamp with time zone,
    "revoked_at" timestamp with time zone,
    "revoked_reason" "text",
    "receive_notifications" boolean DEFAULT true NOT NULL,
    "receive_economic_notifications" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."organization_members" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organization_members"."receive_notifications" IS 'Si false, el miembro NO recibe ninguna notificación in-app/email de pactos donde su organización participa. Default true.';



COMMENT ON COLUMN "public"."organization_members"."receive_economic_notifications" IS 'Si false, el miembro no recibe notificaciones de eventos económicos (pre-depósito, pago liberado, factura). Sólo aplica si también puede ver economics. Default true.';



CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "legal_name" "text" NOT NULL,
    "trade_name" "text",
    "cif" "text" NOT NULL,
    "address_line" "text",
    "postal_code" "text",
    "city" "text",
    "province" "text",
    "country_iso" character(2) DEFAULT 'ES'::"bpchar" NOT NULL,
    "registry" "text",
    "registry_number" "text",
    "beneficial_owners" "jsonb",
    "kyb_status" "public"."kyc_status" DEFAULT 'not_started'::"public"."kyc_status" NOT NULL,
    "kyb_verified_at" timestamp with time zone,
    "kyb_provider" "text" DEFAULT 'onfido'::"text",
    "mangopay_user_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "owner_user_id" "uuid" NOT NULL,
    "description" "text",
    "org_type" "public"."org_type" DEFAULT 'constructor'::"public"."org_type" NOT NULL,
    "escrow_owner_id" "text",
    "escrow_payer_id" "text",
    CONSTRAINT "organizations_escrow_owner_id_prefijo" CHECK ((("escrow_owner_id" IS NULL) OR ("escrow_owner_id" ~ '^acct_'::"text") OR ("escrow_owner_id" ~ '^[0-9]+$'::"text"))),
    CONSTRAINT "organizations_escrow_payer_id_prefijo" CHECK ((("escrow_payer_id" IS NULL) OR ("escrow_payer_id" ~ '^cus_'::"text") OR ("escrow_payer_id" ~ '^[0-9]+$'::"text")))
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organizations"."mangopay_user_id" IS 'DEPRECADA: sustituida por escrow_owner_id / escrow_payer_id (migracion 20260831100000). Nunca la escribio ningun flujo.';



COMMENT ON COLUMN "public"."organizations"."escrow_owner_id" IS 'Cuenta conectada del proveedor de escrow con la que la organizacion COBRA (acct_... en Stripe).';



COMMENT ON COLUMN "public"."organizations"."escrow_payer_id" IS 'Identidad del proveedor de escrow con la que la organizacion PAGA (cus_... en Stripe).';



CREATE TABLE IF NOT EXISTS "public"."pact_addendums" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "display_id" "text" NOT NULL,
    "ordinal" smallint NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "extra_amount_cents" bigint NOT NULL,
    "extra_days" smallint DEFAULT 0 NOT NULL,
    "justification" "text",
    "detailed_doc_storage_path" "text",
    "detailed_doc_sha256" "text",
    "detailed_doc_mime_type" "text",
    "detailed_doc_size_bytes" bigint,
    "proposed_by_user_id" "uuid" NOT NULL,
    "proposed_by_role" "public"."pact_party_role" NOT NULL,
    "signed_at_promotor" timestamp with time zone,
    "signed_at_constructor" timestamp with time zone,
    "signed_at_tecnico" timestamp with time zone,
    "state" "public"."addendum_state" DEFAULT 'proposed'::"public"."addendum_state" NOT NULL,
    "state_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "finalized_at" timestamp with time zone,
    "cancelled_reason" "text",
    CONSTRAINT "pact_addendums_detailed_doc_size_bytes_check" CHECK ((("detailed_doc_size_bytes" IS NULL) OR ("detailed_doc_size_bytes" > 0))),
    CONSTRAINT "pact_addendums_ordinal_check" CHECK (("ordinal" >= 1))
);


ALTER TABLE "public"."pact_addendums" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pact_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "event_type" "text" NOT NULL,
    "event_version" smallint DEFAULT 1 NOT NULL,
    "payload" "jsonb" NOT NULL,
    "actor_user_id" "uuid",
    "actor_type" "text" DEFAULT 'user'::"text",
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "pact_events_no_modification" CHECK ((1 = 1))
);


ALTER TABLE "public"."pact_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."pact_events" IS 'Event log apéndice-solo del pacto. Fuente de verdad para reconstruir estado.';



CREATE TABLE IF NOT EXISTS "public"."pact_health_scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "score" smallint NOT NULL,
    "milestone_compliance_pct" numeric(5,2),
    "evidence_validity_pct" numeric(5,2),
    "validation_speed_pct" numeric(5,2),
    "no_disputes_pct" numeric(5,2),
    "calculated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ia_evidence_score" numeric(5,2),
    CONSTRAINT "pact_health_scores_ia_evidence_score_check" CHECK ((("ia_evidence_score" IS NULL) OR (("ia_evidence_score" >= (0)::numeric) AND ("ia_evidence_score" <= (100)::numeric)))),
    CONSTRAINT "pact_health_scores_score_check" CHECK ((("score" >= 0) AND ("score" <= 100)))
);


ALTER TABLE "public"."pact_health_scores" OWNER TO "postgres";


COMMENT ON COLUMN "public"."pact_health_scores"."ia_evidence_score" IS 'v2.1+IA · Media ponderada de los scores de milestone_ai_verifications del pacto. NULL si aún no hay verificaciones de IA.';



CREATE TABLE IF NOT EXISTS "public"."pact_message_reads" (
    "pact_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pact_message_reads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pact_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "sender_user_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pact_messages_body_check" CHECK ((("length"("btrim"("body")) > 0) AND ("length"("body") <= 2000)))
);


ALTER TABLE "public"."pact_messages" OWNER TO "postgres";


COMMENT ON TABLE "public"."pact_messages" IS 'Chat entre partes de un pacto. Todo acceso vía RPC (RLS deny-by-default).';



CREATE TABLE IF NOT EXISTS "public"."pact_metadata" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "key" "text" NOT NULL,
    "value" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pact_metadata" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pact_parties" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "organization_id" "uuid",
    "role" "public"."pact_party_role" NOT NULL,
    "invited_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "invited_by_user_id" "uuid",
    "accepted_at" timestamp with time zone,
    "signed_at" timestamp with time zone,
    "snapshot_full_name" "text",
    "snapshot_id_number" "text",
    "snapshot_email" "public"."citext",
    "snapshot_role_data" "jsonb",
    "signaturit_signature_id" "text",
    "signature_state" "public"."signature_state" DEFAULT 'requested'::"public"."signature_state",
    CONSTRAINT "pact_parties_user_or_org" CHECK (((("user_id" IS NOT NULL) AND ("organization_id" IS NULL)) OR (("user_id" IS NULL) AND ("organization_id" IS NOT NULL)) OR (("user_id" IS NOT NULL) AND ("organization_id" IS NOT NULL))))
);


ALTER TABLE "public"."pact_parties" OWNER TO "postgres";


COMMENT ON TABLE "public"."pact_parties" IS 'Relación user/org → pact con su rol. Snapshot inmutable de los datos al momento de la firma.';



CREATE TABLE IF NOT EXISTS "public"."pact_plan_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "ordinal" smallint NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "amount_cents" bigint NOT NULL,
    "percentage" numeric(5,2),
    "kind" "text" DEFAULT 'phase'::"text" NOT NULL,
    "source" "text" DEFAULT 'costpact'::"text" NOT NULL,
    "milestone_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "pact_plan_items_amount_cents_check" CHECK (("amount_cents" >= 0)),
    CONSTRAINT "pact_plan_items_kind_check" CHECK (("kind" = ANY (ARRAY['advance'::"text", 'phase'::"text", 'retention'::"text"])))
);


ALTER TABLE "public"."pact_plan_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pact_state_transitions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "from_state" "public"."pact_state",
    "to_state" "public"."pact_state" NOT NULL,
    "transitioned_by_user_id" "uuid",
    "reason" "text",
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pact_state_transitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "display_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "obra_address_line" "text" NOT NULL,
    "obra_postal_code" "text",
    "obra_city" "text" NOT NULL,
    "obra_province" "text",
    "obra_country_iso" character(2) DEFAULT 'ES'::"bpchar" NOT NULL,
    "obra_cadastral_ref" "text",
    "obra_type" "text",
    "total_amount_cents" bigint NOT NULL,
    "iva_rate_pct" numeric(4,2) DEFAULT 21.00 NOT NULL,
    "iva_included" boolean DEFAULT false NOT NULL,
    "total_with_iva_cents" bigint GENERATED ALWAYS AS (
CASE
    WHEN "iva_included" THEN ("total_amount_cents")::numeric
    ELSE (("total_amount_cents")::numeric + "round"(((("total_amount_cents")::numeric * "iva_rate_pct") / (100)::numeric)))
END) STORED,
    "platform_fee_pct" numeric(4,2) DEFAULT 1.00 NOT NULL,
    "estimated_start_date" "date",
    "estimated_end_date" "date",
    "state" "public"."pact_state" DEFAULT 'draft'::"public"."pact_state" NOT NULL,
    "state_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "funding_mode" "text" DEFAULT 'fund_first'::"text" NOT NULL,
    "mangopay_wallet_id" "text",
    "iban_custodia" "text",
    "master_contract_doc_id" "uuid",
    "created_by_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone,
    "pact_type" "public"."pact_type" DEFAULT 'obra_mayor'::"public"."pact_type" NOT NULL,
    "requires_tecnico" boolean DEFAULT true NOT NULL,
    "obra_menor_declaration_accepted_at" timestamp with time zone,
    "obra_menor_declaration_text_hash" "text",
    "deposit_required_pct" numeric(5,2) DEFAULT 30.00 NOT NULL,
    "deposit_current_cents" bigint DEFAULT 0 NOT NULL,
    "budget_consumed_cents" bigint DEFAULT 0 NOT NULL,
    "certification_frequency_text" "text",
    "insurance_premium_cents" bigint DEFAULT 0 NOT NULL,
    "model_version" "text" DEFAULT 'v1'::"text" NOT NULL,
    "advance_reserve_pct" numeric(5,2) DEFAULT 10.00 NOT NULL,
    "advance_released_cents" bigint DEFAULT 0 NOT NULL,
    "advance_outstanding_cents" bigint DEFAULT 0 NOT NULL,
    "is_demo_only" boolean DEFAULT false NOT NULL,
    "total_quality_holdback_cents" bigint DEFAULT 0 NOT NULL,
    "quality_settlement_state" "text",
    "ipc_enabled" boolean DEFAULT false NOT NULL,
    "ipc_base_month" "text",
    "ipc_base_value" numeric(8,3),
    CONSTRAINT "pacts_advance_outstanding_cents_check" CHECK (("advance_outstanding_cents" >= 0)),
    CONSTRAINT "pacts_advance_released_cents_check" CHECK (("advance_released_cents" >= 0)),
    CONSTRAINT "pacts_advance_reserve_pct_check" CHECK ((("advance_reserve_pct" >= (0)::numeric) AND ("advance_reserve_pct" <= (20)::numeric))),
    CONSTRAINT "pacts_budget_consumed_cents_check" CHECK (("budget_consumed_cents" >= 0)),
    CONSTRAINT "pacts_deposit_current_cents_check" CHECK (("deposit_current_cents" >= 0)),
    CONSTRAINT "pacts_deposit_required_pct_check" CHECK ((("deposit_required_pct" >= 15.00) AND ("deposit_required_pct" <= 40.00))),
    CONSTRAINT "pacts_funding_mode_check" CHECK (("funding_mode" = ANY (ARRAY['fund_first'::"text", 'pay_per_milestone'::"text"]))),
    CONSTRAINT "pacts_insurance_premium_cents_check" CHECK (("insurance_premium_cents" >= 0)),
    CONSTRAINT "pacts_iva_rate_valid" CHECK (("iva_rate_pct" = ANY (ARRAY[(0)::numeric, (4)::numeric, (10)::numeric, (21)::numeric]))),
    CONSTRAINT "pacts_obra_menor_requires_declaration" CHECK ((("pact_type" = 'obra_mayor'::"public"."pact_type") OR (("pact_type" = 'obra_menor'::"public"."pact_type") AND ("obra_menor_declaration_accepted_at" IS NOT NULL)))),
    CONSTRAINT "pacts_quality_settlement_state_check" CHECK (("quality_settlement_state" = ANY (ARRAY[NULL::"text", 'pending'::"text", 'released'::"text", 'partial_release'::"text", 'forfeited'::"text", 'under_review'::"text"]))),
    CONSTRAINT "pacts_total_amount_cents_check" CHECK (("total_amount_cents" > 0))
);


ALTER TABLE "public"."pacts" OWNER TO "postgres";


COMMENT ON TABLE "public"."pacts" IS 'Acuerdo tripartito. Fuente de verdad del estado del pacto. Las transiciones de state se validan por trigger.';



COMMENT ON COLUMN "public"."pacts"."platform_fee_pct" IS 'Comisión PactStream sobre cada hito liberado. Editable desde admin.';



COMMENT ON COLUMN "public"."pacts"."pact_type" IS 'obra_mayor (3 partes) | obra_menor (2 partes sin técnico). Default obra_mayor.';



COMMENT ON COLUMN "public"."pacts"."requires_tecnico" IS 'Derivado de pact_type vía trigger. true para obra_mayor, false para obra_menor.';



COMMENT ON COLUMN "public"."pacts"."obra_menor_declaration_accepted_at" IS 'Timestamp en que el promotor aceptó la declaración responsable de que la obra es menor y asume responsabilidad legal de la calificación.';



COMMENT ON COLUMN "public"."pacts"."advance_reserve_pct" IS 'v2.1 · Porcentaje fijo del presupuesto que queda custodiado como reserva de finiquito (default 10). El resto del adelanto se entrega al constructor.';



COMMENT ON COLUMN "public"."pacts"."advance_released_cents" IS 'v2.1 · Importe del adelanto efectivamente entregado al constructor el día 1 (= deposit_required_pct - advance_reserve_pct sobre el total).';



COMMENT ON COLUMN "public"."pacts"."advance_outstanding_cents" IS 'v2.1 · Saldo vivo del adelanto (cobertura activa de la póliza de caución). Decrece con cada certificación pagada en función de la amortización.';



COMMENT ON COLUMN "public"."pacts"."is_demo_only" IS 'IA · Si TRUE, el pacto está aislado para demos: nunca llama a la API real de IA, siempre sirve fixtures. Preserva el demo como activo reproducible sin coste. Solo admin puede flipar este campo vía RPC.';



COMMENT ON COLUMN "public"."pacts"."ipc_enabled" IS 'true si el pacto tiene cláusula de revisión por IPC';



COMMENT ON COLUMN "public"."pacts"."ipc_base_month" IS 'Mes de referencia para el cálculo IPC (YYYY-MM)';



COMMENT ON COLUMN "public"."pacts"."ipc_base_value" IS 'Valor del índice IPC en el mes base';



CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "milestone_id" "uuid",
    "payment_type" "public"."payment_type" NOT NULL,
    "amount_cents" bigint NOT NULL,
    "fee_cents" bigint DEFAULT 0 NOT NULL,
    "net_amount_cents" bigint GENERATED ALWAYS AS (("amount_cents" - "fee_cents")) STORED,
    "state" "public"."payment_state" DEFAULT 'created'::"public"."payment_state" NOT NULL,
    "source_user_id" "uuid",
    "source_org_id" "uuid",
    "destination_user_id" "uuid",
    "destination_org_id" "uuid",
    "mangopay_transaction_id" "text",
    "mangopay_wallet_id" "text",
    "idempotency_key" "text" NOT NULL,
    "last_webhook_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "succeeded_at" timestamp with time zone,
    "failed_at" timestamp with time zone,
    "failure_reason" "text"
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payouts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "mangopay_payout_id" "text",
    "mangopay_bank_account_id" "text",
    "amount_cents" bigint NOT NULL,
    "state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "succeeded_at" timestamp with time zone,
    "failed_at" timestamp with time zone,
    "failure_reason" "text"
);


ALTER TABLE "public"."payouts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quality_holdbacks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "amount_cents" bigint NOT NULL,
    "ai_score" smallint NOT NULL,
    "threshold_used" smallint NOT NULL,
    "holdback_pct_used" smallint NOT NULL,
    "state" "text" DEFAULT 'held'::"text" NOT NULL,
    "reason" "text" DEFAULT 'low_quality_score'::"text" NOT NULL,
    "released_at" timestamp with time zone,
    "released_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "quality_holdbacks_ai_score_check" CHECK ((("ai_score" >= 0) AND ("ai_score" <= 100))),
    CONSTRAINT "quality_holdbacks_amount_cents_check" CHECK (("amount_cents" > 0)),
    CONSTRAINT "quality_holdbacks_state_check" CHECK (("state" = ANY (ARRAY['held'::"text", 'released'::"text", 'forfeited'::"text", 'under_review'::"text"])))
);


ALTER TABLE "public"."quality_holdbacks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."signature_signers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "signature_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "signer_role" "public"."pact_party_role" NOT NULL,
    "ordinal" smallint NOT NULL,
    "signed_at" timestamp with time zone,
    "ip_address" "inet",
    "biometric_data_consent_at" timestamp with time zone,
    "signaturit_signer_id" "text"
);


ALTER TABLE "public"."signature_signers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."signatures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "document_id" "uuid" NOT NULL,
    "signaturit_doc_id" "text",
    "state" "public"."signature_state" DEFAULT 'requested'::"public"."signature_state" NOT NULL,
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "tsa_timestamp_token" "text",
    "tsa_provider" "text",
    "final_pdf_sha256" "text"
);


ALTER TABLE "public"."signatures" OWNER TO "postgres";


COMMENT ON COLUMN "public"."signatures"."signaturit_doc_id" IS 'Identificador del documento en el prestador de firma cualificada. NULL mientras no haya integración: la firma es trazable (PDF + SHA-256 + consentimiento registrado) pero no cualificada. No presuponer que existe.';



CREATE TABLE IF NOT EXISTS "public"."surety_policies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pact_id" "uuid" NOT NULL,
    "insurer_name" "text" NOT NULL,
    "policy_number" "text",
    "premium_cents" bigint,
    "initial_coverage_cents" bigint NOT NULL,
    "current_coverage_cents" bigint NOT NULL,
    "status" "public"."surety_policy_status" DEFAULT 'draft'::"public"."surety_policy_status" NOT NULL,
    "issued_at" timestamp with time zone,
    "released_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "claims" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "notes" "text",
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by_user_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "surety_policies_current_coverage_cents_check" CHECK (("current_coverage_cents" >= 0)),
    CONSTRAINT "surety_policies_initial_coverage_cents_check" CHECK (("initial_coverage_cents" > 0)),
    CONSTRAINT "surety_policies_premium_cents_check" CHECK ((("premium_cents" IS NULL) OR ("premium_cents" >= 0)))
);


ALTER TABLE "public"."surety_policies" OWNER TO "postgres";


COMMENT ON TABLE "public"."surety_policies" IS 'v2.1 · Póliza de caución que respalda el adelanto entregado al constructor. En MVP se rellena manualmente; en producción se sincronizará con la API de la aseguradora elegida.';



COMMENT ON COLUMN "public"."surety_policies"."current_coverage_cents" IS 'Saldo vivo de la cobertura (= initial_coverage_cents - amortizado). Se actualiza por trigger cuando una cert pasa a paid.';



CREATE TABLE IF NOT EXISTS "public"."user_reputations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."user_role" NOT NULL,
    "score" smallint NOT NULL,
    "tier" "text" NOT NULL,
    "components" "jsonb" NOT NULL,
    "pacts_total" smallint DEFAULT 0 NOT NULL,
    "pacts_completed" smallint DEFAULT 0 NOT NULL,
    "pacts_disputed" smallint DEFAULT 0 NOT NULL,
    "calculated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_reputations_score_check" CHECK ((("score" >= 0) AND ("score" <= 100))),
    CONSTRAINT "user_reputations_tier_check" CHECK (("tier" = ANY (ARRAY['bronce'::"text", 'plata'::"text", 'oro'::"text", 'platino'::"text", 'elite'::"text"])))
);


ALTER TABLE "public"."user_reputations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_provider" "text" DEFAULT 'supabase'::"text" NOT NULL,
    "auth_provider_id" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "email" "public"."citext" NOT NULL,
    "phone_e164" "text",
    "national_id" "text",
    "date_of_birth" "date",
    "address_line" "text",
    "postal_code" "text",
    "city" "text",
    "province" "text",
    "country_iso" character(2) DEFAULT 'ES'::"bpchar" NOT NULL,
    "primary_role" "public"."user_role",
    "profession" "text",
    "colegio" "text",
    "num_colegiacion" "text",
    "rc_certificate_url" "text",
    "organization_id" "uuid",
    "kyc_status" "public"."kyc_status" DEFAULT 'not_started'::"public"."kyc_status" NOT NULL,
    "kyc_verified_at" timestamp with time zone,
    "kyc_provider" "text" DEFAULT 'onfido'::"text",
    "kyc_external_id" "text",
    "mangopay_user_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_login_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "marketing_consent_at" timestamp with time zone,
    "kyc_session_url" "text",
    "avatar_url" "text",
    "locale" "text" DEFAULT 'es'::"text" NOT NULL,
    "escrow_owner_id" "text",
    "escrow_payer_id" "text",
    "mangopay_bank_account_id" "text",
    CONSTRAINT "users_email_lower" CHECK (("email" OPERATOR("public".=) ("lower"(("email")::"text"))::"public"."citext")),
    CONSTRAINT "users_escrow_owner_id_prefijo" CHECK ((("escrow_owner_id" IS NULL) OR ("escrow_owner_id" ~ '^acct_'::"text") OR ("escrow_owner_id" ~ '^[0-9]+$'::"text"))),
    CONSTRAINT "users_escrow_payer_id_prefijo" CHECK ((("escrow_payer_id" IS NULL) OR ("escrow_payer_id" ~ '^cus_'::"text") OR ("escrow_payer_id" ~ '^[0-9]+$'::"text"))),
    CONSTRAINT "users_locale_supported" CHECK (("locale" = ANY (ARRAY['es'::"text", 'es-419'::"text", 'en'::"text"])))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON TABLE "public"."users" IS 'Usuarios de la plataforma. Un usuario tiene un rol primario pero puede aparecer en distintos pactos con roles distintos.';



COMMENT ON COLUMN "public"."users"."national_id" IS 'Cifrado a nivel de aplicación. Solo accesible para Cloud Functions con permisos KYC.';



COMMENT ON COLUMN "public"."users"."primary_role" IS 'Rol primario. NULL para usuarios creados vía invitación a una organización (no son protagonistas de pactos, sólo miembros).';



COMMENT ON COLUMN "public"."users"."mangopay_user_id" IS 'DEPRECADA: sustituida por escrow_owner_id / escrow_payer_id (migracion 20260831090000). Ya no la escribe ningun flujo.';



COMMENT ON COLUMN "public"."users"."kyc_session_url" IS 'URL temporal de la sesión Veriff. Vacía cuando no hay sesión activa.';



COMMENT ON COLUMN "public"."users"."locale" IS 'Idioma de interfaz preferido (ISO 639-1). Independiente de country_iso, que resuelve moneda e identificación fiscal. Ampliar el CHECK al añadir un idioma nuevo a AppLanguage en el cliente Flutter.';



COMMENT ON COLUMN "public"."users"."escrow_owner_id" IS 'Cuenta conectada del proveedor de escrow con la que el usuario COBRA (acct_... en Stripe). La escribe escrow-onboard-link / escrow-onboard(OWNER).';



COMMENT ON COLUMN "public"."users"."escrow_payer_id" IS 'Identidad del proveedor de escrow con la que el usuario PAGA (cus_... en Stripe). La escribe escrow-onboard(PAYER).';



CREATE OR REPLACE VIEW "public"."v_my_pacts_summary" WITH ("security_invoker"='on') AS
 SELECT "p"."id",
    "p"."display_id",
    "p"."title",
    "p"."state",
    "p"."pact_type",
    "p"."total_amount_cents",
    "p"."requires_tecnico",
    "pp"."role" AS "my_role",
    "p"."created_at"
   FROM ("public"."pacts" "p"
     JOIN "public"."pact_parties" "pp" ON (("pp"."pact_id" = "p"."id")))
  WHERE (("pp"."user_id" = ( SELECT "users"."id"
           FROM "public"."users"
          WHERE ("users"."auth_provider_id" = ("auth"."uid"())::"text"))) AND ("p"."state" <> ALL (ARRAY['closed'::"public"."pact_state", 'cancelled'::"public"."pact_state"])));


ALTER VIEW "public"."v_my_pacts_summary" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_my_pacts_summary" IS 'Auditoria 2026-09-01 (P6): security_invoker=on + sin acceso anon. Aislamiento por la RLS de pacts/pact_parties (user_in_pact) ademas del filtro propio por auth.uid().';



CREATE OR REPLACE VIEW "public"."v_pact_financial_progress" WITH ("security_invoker"='on') AS
 SELECT "p"."id" AS "pact_id",
    "p"."total_amount_cents",
    COALESCE("sum"("m"."amount_cents") FILTER (WHERE ("m"."state" = 'paid'::"public"."milestone_state")), (0)::numeric) AS "paid_cents",
    COALESCE("sum"("m"."amount_cents") FILTER (WHERE ("m"."state" = ANY (ARRAY['approved_by_tech'::"public"."milestone_state", 'awaiting_promotor'::"public"."milestone_state"]))), (0)::numeric) AS "approved_pending_release_cents",
    COALESCE("sum"("m"."amount_cents") FILTER (WHERE ("m"."state" = 'disputed'::"public"."milestone_state")), (0)::numeric) AS "disputed_cents",
    COALESCE("sum"("m"."amount_cents") FILTER (WHERE ("m"."state" = ANY (ARRAY['pending'::"public"."milestone_state", 'in_execution'::"public"."milestone_state", 'ready_for_review'::"public"."milestone_state", 'in_validation'::"public"."milestone_state", 'info_requested'::"public"."milestone_state"]))), (0)::numeric) AS "in_custody_cents"
   FROM ("public"."pacts" "p"
     LEFT JOIN "public"."milestones" "m" ON (("m"."pact_id" = "p"."id")))
  GROUP BY "p"."id", "p"."total_amount_cents";


ALTER VIEW "public"."v_pact_financial_progress" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_pact_financial_progress" IS 'Auditoría 2026-07-13 C2: security_invoker=on. El progreso financiero se filtra por la RLS de pacts/milestones del llamante.';



CREATE OR REPLACE VIEW "public"."v_user_active_pacts" WITH ("security_invoker"='on') AS
 SELECT DISTINCT "p"."id",
    "p"."display_id",
    "p"."title",
    "p"."description",
    "p"."obra_address_line",
    "p"."obra_postal_code",
    "p"."obra_city",
    "p"."obra_province",
    "p"."obra_country_iso",
    "p"."obra_cadastral_ref",
    "p"."obra_type",
    "p"."total_amount_cents",
    "p"."iva_rate_pct",
    "p"."iva_included",
    "p"."total_with_iva_cents",
    "p"."platform_fee_pct",
    "p"."estimated_start_date",
    "p"."estimated_end_date",
    "p"."state",
    "p"."state_updated_at",
    "p"."funding_mode",
    "p"."mangopay_wallet_id",
    "p"."iban_custodia",
    "p"."master_contract_doc_id",
    "p"."created_by_user_id",
    "p"."created_at",
    "p"."updated_at",
    "p"."closed_at",
    "pp"."role" AS "my_role",
    "pp"."user_id" AS "my_user_id"
   FROM ("public"."pacts" "p"
     JOIN "public"."pact_parties" "pp" ON (("pp"."pact_id" = "p"."id")))
  WHERE (("p"."state" <> ALL (ARRAY['closed'::"public"."pact_state", 'cancelled'::"public"."pact_state"])) AND ("pp"."user_id" = ( SELECT "users"."id"
           FROM "public"."users"
          WHERE (("users"."auth_provider_id" = ("auth"."uid"())::"text") AND ("users"."deleted_at" IS NULL)))));


ALTER VIEW "public"."v_user_active_pacts" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_user_active_pacts" IS 'Auditoría 2026-07-13 C2: security_invoker=on + filtro por usuario actual. Solo devuelve pactos activos donde el llamante es parte.';



CREATE TABLE IF NOT EXISTS "public"."webhook_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider" "text" NOT NULL,
    "external_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "signature_valid" boolean,
    "processed_at" timestamp with time zone,
    "processed_result" "text",
    "received_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."webhook_events" OWNER TO "postgres";


ALTER TABLE ONLY "public"."acopio_items"
    ADD CONSTRAINT "acopio_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ai_assistant_messages"
    ADD CONSTRAINT "ai_assistant_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ai_fixtures"
    ADD CONSTRAINT "ai_fixtures_fixture_key_key" UNIQUE ("fixture_key");



ALTER TABLE ONLY "public"."ai_fixtures"
    ADD CONSTRAINT "ai_fixtures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ai_prompts"
    ADD CONSTRAINT "ai_prompts_key_version_unique" UNIQUE ("prompt_key", "version");



ALTER TABLE ONLY "public"."ai_prompts"
    ADD CONSTRAINT "ai_prompts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ai_runs"
    ADD CONSTRAINT "ai_runs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."api_key_usage"
    ADD CONSTRAINT "api_key_usage_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_key_hash_key" UNIQUE ("key_hash");



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cae_enlaces_cliente"
    ADD CONSTRAINT "cae_enlaces_cliente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cae_enlaces_cliente"
    ADD CONSTRAINT "cae_enlaces_cliente_token_sha256_key" UNIQUE ("token_sha256");



ALTER TABLE ONLY "public"."cae_expedientes"
    ADD CONSTRAINT "cae_expedientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cae_lotes"
    ADD CONSTRAINT "cae_lotes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cae_requisitos"
    ADD CONSTRAINT "cae_req_unico_por_expediente" UNIQUE ("expediente_id", "clave");



ALTER TABLE ONLY "public"."cae_requisitos"
    ADD CONSTRAINT "cae_requisitos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pact_unique" UNIQUE ("pact_id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deposit_movements"
    ADD CONSTRAINT "deposit_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispute_contributions"
    ADD CONSTRAINT "dispute_contributions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispute_escrows"
    ADD CONSTRAINT "dispute_escrows_milestone_id_key" UNIQUE ("milestone_id");



ALTER TABLE ONLY "public"."dispute_escrows"
    ADD CONSTRAINT "dispute_escrows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_display_id_key" UNIQUE ("display_id");



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ipc_indices"
    ADD CONSTRAINT "ipc_indices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ipc_indices"
    ADD CONSTRAINT "ipc_indices_year_month_key" UNIQUE ("year_month");



ALTER TABLE ONLY "public"."legal_consents"
    ADD CONSTRAINT "legal_consents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."milestone_ai_verifications"
    ADD CONSTRAINT "milestone_ai_verifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."milestone_evidences"
    ADD CONSTRAINT "milestone_evidences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."milestone_objections"
    ADD CONSTRAINT "milestone_objections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."milestone_state_transitions"
    ADD CONSTRAINT "milestone_state_transitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."milestone_validations"
    ADD CONSTRAINT "milestone_validations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."milestones"
    ADD CONSTRAINT "milestones_display_id_unique" UNIQUE ("display_id");



ALTER TABLE ONLY "public"."milestones"
    ADD CONSTRAINT "milestones_ordinal_per_pact" UNIQUE ("pact_id", "ordinal");



ALTER TABLE ONLY "public"."milestones"
    ADD CONSTRAINT "milestones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_members"
    ADD CONSTRAINT "org_member_unique_email_per_org" UNIQUE ("organization_id", "invited_email");



ALTER TABLE ONLY "public"."organization_members"
    ADD CONSTRAINT "organization_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_cif_key" UNIQUE ("cif");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_mangopay_user_id_key" UNIQUE ("mangopay_user_id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_one_per_owner" UNIQUE ("owner_user_id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_addendums"
    ADD CONSTRAINT "pact_addendums_display_id_key" UNIQUE ("display_id");



ALTER TABLE ONLY "public"."pact_addendums"
    ADD CONSTRAINT "pact_addendums_ordinal_per_pact" UNIQUE ("pact_id", "ordinal");



ALTER TABLE ONLY "public"."pact_addendums"
    ADD CONSTRAINT "pact_addendums_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_events"
    ADD CONSTRAINT "pact_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_health_scores"
    ADD CONSTRAINT "pact_health_scores_pact_calc" UNIQUE ("pact_id", "calculated_at");



ALTER TABLE ONLY "public"."pact_health_scores"
    ADD CONSTRAINT "pact_health_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_message_reads"
    ADD CONSTRAINT "pact_message_reads_pkey" PRIMARY KEY ("pact_id", "user_id");



ALTER TABLE ONLY "public"."pact_messages"
    ADD CONSTRAINT "pact_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_metadata"
    ADD CONSTRAINT "pact_metadata_pact_id_key_key" UNIQUE ("pact_id", "key");



ALTER TABLE ONLY "public"."pact_metadata"
    ADD CONSTRAINT "pact_metadata_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_parties"
    ADD CONSTRAINT "pact_parties_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_parties"
    ADD CONSTRAINT "pact_parties_unique_role_per_pact" UNIQUE ("pact_id", "role") DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."pact_plan_items"
    ADD CONSTRAINT "pact_plan_items_pact_id_ordinal_key" UNIQUE ("pact_id", "ordinal");



ALTER TABLE ONLY "public"."pact_plan_items"
    ADD CONSTRAINT "pact_plan_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pact_state_transitions"
    ADD CONSTRAINT "pact_state_transitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pacts"
    ADD CONSTRAINT "pacts_display_id_key" UNIQUE ("display_id");



ALTER TABLE ONLY "public"."pacts"
    ADD CONSTRAINT "pacts_mangopay_wallet_id_key" UNIQUE ("mangopay_wallet_id");



ALTER TABLE ONLY "public"."pacts"
    ADD CONSTRAINT "pacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_mangopay_transaction_id_key" UNIQUE ("mangopay_transaction_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_mangopay_payout_id_key" UNIQUE ("mangopay_payout_id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quality_holdbacks"
    ADD CONSTRAINT "quality_holdbacks_milestone_id_key" UNIQUE ("milestone_id");



ALTER TABLE ONLY "public"."quality_holdbacks"
    ADD CONSTRAINT "quality_holdbacks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."signature_signers"
    ADD CONSTRAINT "signature_signers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."signatures"
    ADD CONSTRAINT "signatures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."signatures"
    ADD CONSTRAINT "signatures_signaturit_doc_id_key" UNIQUE ("signaturit_doc_id");



ALTER TABLE ONLY "public"."surety_policies"
    ADD CONSTRAINT "surety_policies_one_active_per_pact" UNIQUE ("pact_id");



ALTER TABLE ONLY "public"."surety_policies"
    ADD CONSTRAINT "surety_policies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_reputations"
    ADD CONSTRAINT "user_reputations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_provider_id_key" UNIQUE ("auth_provider_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_mangopay_user_id_key" UNIQUE ("mangopay_user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_events"
    ADD CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_events"
    ADD CONSTRAINT "webhook_events_unique_per_provider" UNIQUE ("provider", "external_id");



CREATE INDEX "cae_enlaces_cliente_expediente_idx" ON "public"."cae_enlaces_cliente" USING "btree" ("expediente_id");



CREATE INDEX "idx_aam_pact_user_time" ON "public"."ai_assistant_messages" USING "btree" ("pact_id", "user_id", "created_at");



CREATE INDEX "idx_aam_tool_pending" ON "public"."ai_assistant_messages" USING "btree" ("tool_call_status") WHERE ("tool_call_status" = 'proposed'::"text");



CREATE INDEX "idx_acopio_items_milestone" ON "public"."acopio_items" USING "btree" ("milestone_id", "state");



CREATE INDEX "idx_ai_fixtures_type_active" ON "public"."ai_fixtures" USING "btree" ("fixture_type") WHERE ("is_active" = true);



CREATE INDEX "idx_ai_prompts_active" ON "public"."ai_prompts" USING "btree" ("prompt_key") WHERE ("is_active" = true);



CREATE INDEX "idx_ai_runs_created" ON "public"."ai_runs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_ai_runs_pact" ON "public"."ai_runs" USING "btree" ("pact_id", "created_at" DESC);



CREATE INDEX "idx_ai_runs_provider_day" ON "public"."ai_runs" USING "btree" ("provider", "created_at" DESC);



CREATE INDEX "idx_api_key_usage_rate" ON "public"."api_key_usage" USING "btree" ("api_key_id", "created_at" DESC);



CREATE INDEX "idx_audit_log_action" ON "public"."audit_log" USING "btree" ("action");



CREATE INDEX "idx_audit_log_actor" ON "public"."audit_log" USING "btree" ("actor_user_id", "occurred_at" DESC);



CREATE INDEX "idx_audit_log_entity" ON "public"."audit_log" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "idx_cae_exp_agrupa" ON "public"."cae_expedientes" USING "btree" ("organization_id", "comunidad_autonoma", "anio_ejecucion");



CREATE INDEX "idx_cae_exp_lote" ON "public"."cae_expedientes" USING "btree" ("lote_id");



CREATE INDEX "idx_cae_exp_pact" ON "public"."cae_expedientes" USING "btree" ("pact_id");



CREATE INDEX "idx_cae_lotes_org" ON "public"."cae_lotes" USING "btree" ("organization_id");



CREATE INDEX "idx_cae_req_actualizado_por" ON "public"."cae_requisitos" USING "btree" ("actualizado_por");



CREATE INDEX "idx_cae_req_documento" ON "public"."cae_requisitos" USING "btree" ("document_id");



CREATE INDEX "idx_deposit_movements_pact" ON "public"."deposit_movements" USING "btree" ("pact_id", "occurred_at" DESC);



CREATE INDEX "idx_deposit_movements_type" ON "public"."deposit_movements" USING "btree" ("movement_type");



CREATE INDEX "idx_dispute_contributions_dispute" ON "public"."dispute_contributions" USING "btree" ("dispute_id");



CREATE INDEX "idx_dispute_escrows_pact" ON "public"."dispute_escrows" USING "btree" ("pact_id", "state");



CREATE INDEX "idx_disputes_milestone" ON "public"."disputes" USING "btree" ("milestone_id");



CREATE INDEX "idx_disputes_pact" ON "public"."disputes" USING "btree" ("pact_id");



CREATE INDEX "idx_disputes_state" ON "public"."disputes" USING "btree" ("state");



CREATE INDEX "idx_documents_pact" ON "public"."documents" USING "btree" ("pact_id");



CREATE INDEX "idx_documents_type" ON "public"."documents" USING "btree" ("doc_type");



CREATE INDEX "idx_ipc_year_month" ON "public"."ipc_indices" USING "btree" ("year_month");



CREATE INDEX "idx_legal_consents_user" ON "public"."legal_consents" USING "btree" ("user_id", "doc_type");



CREATE UNIQUE INDEX "idx_legal_consents_user_doc_active" ON "public"."legal_consents" USING "btree" ("user_id", "doc_type") WHERE ("revoked_at" IS NULL);



CREATE INDEX "idx_mai_verifications_milestone" ON "public"."milestone_ai_verifications" USING "btree" ("milestone_id", "created_at" DESC);



CREATE INDEX "idx_mai_verifications_pact" ON "public"."milestone_ai_verifications" USING "btree" ("pact_id", "created_at" DESC);



CREATE INDEX "idx_mai_verifications_verdict" ON "public"."milestone_ai_verifications" USING "btree" ("verdict") WHERE ("verdict" <> 'ok'::"public"."ai_verdict");



CREATE INDEX "idx_messages_conversation" ON "public"."messages" USING "btree" ("conversation_id", "created_at");



CREATE INDEX "idx_messages_sender" ON "public"."messages" USING "btree" ("sender_user_id");



CREATE INDEX "idx_milestone_evidences_active" ON "public"."milestone_evidences" USING "btree" ("milestone_id") WHERE (NOT "is_superseded");



CREATE INDEX "idx_milestone_evidences_milestone" ON "public"."milestone_evidences" USING "btree" ("milestone_id");



CREATE INDEX "idx_milestone_evidences_uploader" ON "public"."milestone_evidences" USING "btree" ("uploaded_by_user_id");



CREATE INDEX "idx_milestone_state_transitions_milestone" ON "public"."milestone_state_transitions" USING "btree" ("milestone_id", "occurred_at");



CREATE INDEX "idx_milestone_validations_milestone" ON "public"."milestone_validations" USING "btree" ("milestone_id");



CREATE INDEX "idx_milestone_validations_validator" ON "public"."milestone_validations" USING "btree" ("validator_user_id");



CREATE INDEX "idx_milestones_category" ON "public"."milestones" USING "btree" ("pact_id", "category");



CREATE INDEX "idx_milestones_pact" ON "public"."milestones" USING "btree" ("pact_id");



CREATE INDEX "idx_milestones_previous_version" ON "public"."milestones" USING "btree" ("previous_version_id") WHERE ("previous_version_id" IS NOT NULL);



CREATE INDEX "idx_milestones_state" ON "public"."milestones" USING "btree" ("state");



CREATE INDEX "idx_milestones_target_date" ON "public"."milestones" USING "btree" ("target_date");



CREATE INDEX "idx_notifications_unread" ON "public"."notifications" USING "btree" ("user_id") WHERE ("read_at" IS NULL);



CREATE INDEX "idx_notifications_user" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_org_members_active" ON "public"."organization_members" USING "btree" ("organization_id") WHERE ("state" = 'active'::"public"."org_member_state");



CREATE INDEX "idx_org_members_org" ON "public"."organization_members" USING "btree" ("organization_id");



CREATE INDEX "idx_org_members_state" ON "public"."organization_members" USING "btree" ("state");



CREATE INDEX "idx_org_members_token" ON "public"."organization_members" USING "btree" ("invitation_token");



CREATE INDEX "idx_org_members_user" ON "public"."organization_members" USING "btree" ("user_id") WHERE ("user_id" IS NOT NULL);



CREATE INDEX "idx_organizations_kyb_status" ON "public"."organizations" USING "btree" ("kyb_status") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_organizations_owner" ON "public"."organizations" USING "btree" ("owner_user_id");



CREATE INDEX "idx_organizations_type" ON "public"."organizations" USING "btree" ("org_type");



CREATE INDEX "idx_pact_addendums_pact" ON "public"."pact_addendums" USING "btree" ("pact_id");



CREATE INDEX "idx_pact_addendums_proposed_by" ON "public"."pact_addendums" USING "btree" ("proposed_by_user_id");



CREATE INDEX "idx_pact_addendums_state" ON "public"."pact_addendums" USING "btree" ("state");



CREATE INDEX "idx_pact_events_pact" ON "public"."pact_events" USING "btree" ("pact_id", "occurred_at");



CREATE INDEX "idx_pact_events_type" ON "public"."pact_events" USING "btree" ("event_type");



CREATE INDEX "idx_pact_health_scores_pact" ON "public"."pact_health_scores" USING "btree" ("pact_id", "calculated_at" DESC);



CREATE INDEX "idx_pact_messages_pact_created" ON "public"."pact_messages" USING "btree" ("pact_id", "created_at" DESC);



CREATE INDEX "idx_pact_metadata_lookup" ON "public"."pact_metadata" USING "btree" ("key", "value");



CREATE INDEX "idx_pact_metadata_pact" ON "public"."pact_metadata" USING "btree" ("pact_id");



CREATE INDEX "idx_pact_parties_org" ON "public"."pact_parties" USING "btree" ("organization_id");



CREATE INDEX "idx_pact_parties_pact" ON "public"."pact_parties" USING "btree" ("pact_id");



CREATE INDEX "idx_pact_parties_user" ON "public"."pact_parties" USING "btree" ("user_id");



CREATE INDEX "idx_pact_plan_items_pact" ON "public"."pact_plan_items" USING "btree" ("pact_id");



CREATE INDEX "idx_pact_state_transitions_pact" ON "public"."pact_state_transitions" USING "btree" ("pact_id", "occurred_at");



CREATE INDEX "idx_pacts_created_by" ON "public"."pacts" USING "btree" ("created_by_user_id");



CREATE INDEX "idx_pacts_obra_city" ON "public"."pacts" USING "btree" ("obra_city");



CREATE INDEX "idx_pacts_state" ON "public"."pacts" USING "btree" ("state");



CREATE INDEX "idx_payments_milestone" ON "public"."payments" USING "btree" ("milestone_id");



CREATE INDEX "idx_payments_pact" ON "public"."payments" USING "btree" ("pact_id");



CREATE INDEX "idx_payments_state" ON "public"."payments" USING "btree" ("state");



CREATE INDEX "idx_payments_type" ON "public"."payments" USING "btree" ("payment_type");



CREATE INDEX "idx_payouts_state" ON "public"."payouts" USING "btree" ("state");



CREATE INDEX "idx_payouts_user" ON "public"."payouts" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_quality_holdbacks_pact" ON "public"."quality_holdbacks" USING "btree" ("pact_id", "state");



CREATE INDEX "idx_surety_policies_pact" ON "public"."surety_policies" USING "btree" ("pact_id");



CREATE INDEX "idx_surety_policies_status" ON "public"."surety_policies" USING "btree" ("status");



CREATE INDEX "idx_user_reputations_tier" ON "public"."user_reputations" USING "btree" ("tier");



CREATE INDEX "idx_user_reputations_user" ON "public"."user_reputations" USING "btree" ("user_id", "calculated_at" DESC);



CREATE INDEX "idx_users_country" ON "public"."users" USING "btree" ("country_iso") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_users_kyc_status" ON "public"."users" USING "btree" ("kyc_status") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_users_organization" ON "public"."users" USING "btree" ("organization_id") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_users_primary_role" ON "public"."users" USING "btree" ("primary_role") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_webhook_events_external_id" ON "public"."webhook_events" USING "btree" ("external_id");



CREATE INDEX "idx_webhook_events_provider" ON "public"."webhook_events" USING "btree" ("provider", "processed_at");



CREATE INDEX "idx_webhook_events_unprocessed" ON "public"."webhook_events" USING "btree" ("provider") WHERE ("processed_at" IS NULL);



CREATE UNIQUE INDEX "organizations_escrow_owner_id_key" ON "public"."organizations" USING "btree" ("escrow_owner_id") WHERE ("escrow_owner_id" IS NOT NULL);



CREATE UNIQUE INDEX "organizations_escrow_payer_id_key" ON "public"."organizations" USING "btree" ("escrow_payer_id") WHERE ("escrow_payer_id" IS NOT NULL);



CREATE UNIQUE INDEX "uq_pact_parties_pact_user" ON "public"."pact_parties" USING "btree" ("pact_id", "user_id") WHERE ("user_id" IS NOT NULL);



CREATE UNIQUE INDEX "uq_pact_plan_items_milestone" ON "public"."pact_plan_items" USING "btree" ("milestone_id") WHERE ("milestone_id" IS NOT NULL);



CREATE UNIQUE INDEX "users_escrow_owner_id_key" ON "public"."users" USING "btree" ("escrow_owner_id") WHERE ("escrow_owner_id" IS NOT NULL);



CREATE UNIQUE INDEX "users_escrow_payer_id_key" ON "public"."users" USING "btree" ("escrow_payer_id") WHERE ("escrow_payer_id" IS NOT NULL);



CREATE INDEX "users_locale_idx" ON "public"."users" USING "btree" ("locale");



CREATE OR REPLACE TRIGGER "trg_addendum_active_update_total" BEFORE UPDATE OF "state" ON "public"."pact_addendums" FOR EACH ROW WHEN ((("new"."state" = 'active'::"public"."addendum_state") AND ("old"."state" <> 'active'::"public"."addendum_state"))) EXECUTE FUNCTION "public"."handle_addendum_active"();



CREATE OR REPLACE TRIGGER "trg_block_ai_verification_mutations" BEFORE DELETE OR UPDATE ON "public"."milestone_ai_verifications" FOR EACH ROW EXECUTE FUNCTION "public"."fn_block_ai_verification_mutations"();



CREATE OR REPLACE TRIGGER "trg_cae_documento_exige_fichero" BEFORE INSERT ON "public"."documents" FOR EACH ROW EXECUTE FUNCTION "public"."fn_cae_documento_exige_fichero"();



CREATE OR REPLACE TRIGGER "trg_cae_entregado_terminal" BEFORE UPDATE ON "public"."cae_expedientes" FOR EACH ROW EXECUTE FUNCTION "public"."fn_cae_expediente_entregado_es_terminal"();



CREATE OR REPLACE TRIGGER "trg_cae_exp_updated_at" BEFORE UPDATE ON "public"."cae_expedientes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_cae_expediente_inmutables" BEFORE UPDATE ON "public"."cae_expedientes" FOR EACH ROW EXECUTE FUNCTION "public"."fn_cae_expediente_inmutables"();



CREATE OR REPLACE TRIGGER "trg_cae_lote_identidad" BEFORE UPDATE ON "public"."cae_lotes" FOR EACH ROW EXECUTE FUNCTION "public"."fn_cae_lote_identidad_inmutable"();



CREATE OR REPLACE TRIGGER "trg_cae_lotes_updated_at" BEFORE UPDATE ON "public"."cae_lotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_cae_puerta_certificado_previo" BEFORE INSERT OR UPDATE ON "public"."cae_expedientes" FOR EACH ROW EXECUTE FUNCTION "public"."fn_cae_puerta_certificado_previo"();



CREATE OR REPLACE TRIGGER "trg_cae_valida_lote" BEFORE INSERT OR UPDATE ON "public"."cae_expedientes" FOR EACH ROW EXECUTE FUNCTION "public"."fn_cae_valida_lote"();



CREATE OR REPLACE TRIGGER "trg_create_owner_member" AFTER INSERT ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."fn_create_owner_member"();



CREATE OR REPLACE TRIGGER "trg_deposit_low_alert" AFTER UPDATE OF "deposit_current_cents" ON "public"."pacts" FOR EACH ROW EXECUTE FUNCTION "public"."handle_deposit_low_alert"();



CREATE OR REPLACE TRIGGER "trg_deposit_movements_append_only" BEFORE DELETE OR UPDATE ON "public"."deposit_movements" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_deposit_movement_modification"();



CREATE OR REPLACE TRIGGER "trg_dispute_escrow_auto" AFTER UPDATE ON "public"."milestones" FOR EACH ROW EXECUTE FUNCTION "public"."fn_dispute_escrow_auto_create"();



CREATE OR REPLACE TRIGGER "trg_events_immutable" BEFORE DELETE OR UPDATE ON "public"."pact_events" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_event_modification"();



CREATE OR REPLACE TRIGGER "trg_evidence_immutable" BEFORE DELETE OR UPDATE ON "public"."milestone_evidences" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_evidence_modification"();



CREATE OR REPLACE TRIGGER "trg_link_pending_invitations" AFTER INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_link_pending_invitations"();



CREATE OR REPLACE TRIGGER "trg_milestone_paid_progress" AFTER UPDATE OF "state" ON "public"."milestones" FOR EACH ROW WHEN ((("new"."state" = 'paid'::"public"."milestone_state") AND ("old"."state" <> 'paid'::"public"."milestone_state"))) EXECUTE FUNCTION "public"."handle_milestone_paid_progress"();



CREATE OR REPLACE TRIGGER "trg_milestone_paid_surety_decrement" AFTER UPDATE OF "state" ON "public"."milestones" FOR EACH ROW EXECUTE FUNCTION "public"."handle_milestone_paid_surety_decrement"();



CREATE OR REPLACE TRIGGER "trg_milestone_quality_check" AFTER UPDATE ON "public"."milestones" FOR EACH ROW EXECUTE FUNCTION "public"."fn_milestone_quality_check"();



CREATE OR REPLACE TRIGGER "trg_milestone_state_recalc_health" AFTER UPDATE OF "state" ON "public"."milestones" FOR EACH ROW EXECUTE FUNCTION "public"."handle_milestone_state_recalc_health"();



CREATE OR REPLACE TRIGGER "trg_milestone_state_transition" BEFORE UPDATE OF "state" ON "public"."milestones" FOR EACH ROW EXECUTE FUNCTION "public"."validate_milestone_state_transition"();



CREATE OR REPLACE TRIGGER "trg_notifications_from_event" AFTER INSERT ON "public"."pact_events" FOR EACH ROW EXECUTE FUNCTION "public"."fn_notifications_from_event"();



CREATE OR REPLACE TRIGGER "trg_organizations_updated_at" BEFORE UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_pact_event_notify" AFTER INSERT ON "public"."pact_events" FOR EACH ROW EXECUTE FUNCTION "public"."handle_pact_event_notify"();



CREATE OR REPLACE TRIGGER "trg_pact_state_transition" BEFORE UPDATE OF "state" ON "public"."pacts" FOR EACH ROW EXECUTE FUNCTION "public"."validate_pact_state_transition"();



CREATE OR REPLACE TRIGGER "trg_pacts_updated_at" BEFORE UPDATE ON "public"."pacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_party_invited_notify" AFTER INSERT ON "public"."pact_parties" FOR EACH ROW WHEN (("new"."accepted_at" IS NULL)) EXECUTE FUNCTION "public"."handle_party_invited_notify"();



CREATE OR REPLACE TRIGGER "trg_sync_pact_type_requires_tecnico" BEFORE INSERT OR UPDATE OF "pact_type" ON "public"."pacts" FOR EACH ROW EXECUTE FUNCTION "public"."sync_pact_type_requires_tecnico"();



CREATE OR REPLACE TRIGGER "trg_users_enforce_privileged_columns" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_users_privileged_columns"();



CREATE OR REPLACE TRIGGER "trg_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_validate_org_single_owner" BEFORE INSERT OR UPDATE ON "public"."organization_members" FOR EACH ROW EXECUTE FUNCTION "public"."fn_validate_org_single_owner"();



ALTER TABLE ONLY "public"."acopio_items"
    ADD CONSTRAINT "acopio_items_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."acopio_items"
    ADD CONSTRAINT "acopio_items_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_assistant_messages"
    ADD CONSTRAINT "ai_assistant_messages_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_assistant_messages"
    ADD CONSTRAINT "ai_assistant_messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."ai_prompts"
    ADD CONSTRAINT "ai_prompts_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."ai_runs"
    ADD CONSTRAINT "ai_runs_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ai_runs"
    ADD CONSTRAINT "ai_runs_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."api_key_usage"
    ADD CONSTRAINT "api_key_usage_api_key_id_fkey" FOREIGN KEY ("api_key_id") REFERENCES "public"."api_keys"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_updated_by_user_id_fkey" FOREIGN KEY ("updated_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."cae_enlaces_cliente"
    ADD CONSTRAINT "cae_enlaces_cliente_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."cae_enlaces_cliente"
    ADD CONSTRAINT "cae_enlaces_cliente_expediente_id_fkey" FOREIGN KEY ("expediente_id") REFERENCES "public"."cae_expedientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cae_expedientes"
    ADD CONSTRAINT "cae_expedientes_lote_id_fkey" FOREIGN KEY ("lote_id") REFERENCES "public"."cae_lotes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cae_expedientes"
    ADD CONSTRAINT "cae_expedientes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cae_expedientes"
    ADD CONSTRAINT "cae_expedientes_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cae_lotes"
    ADD CONSTRAINT "cae_lotes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cae_requisitos"
    ADD CONSTRAINT "cae_requisitos_actualizado_por_fkey" FOREIGN KEY ("actualizado_por") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cae_requisitos"
    ADD CONSTRAINT "cae_requisitos_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cae_requisitos"
    ADD CONSTRAINT "cae_requisitos_expediente_id_fkey" FOREIGN KEY ("expediente_id") REFERENCES "public"."cae_expedientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deposit_movements"
    ADD CONSTRAINT "deposit_movements_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."deposit_movements"
    ADD CONSTRAINT "deposit_movements_related_addendum_id_fkey" FOREIGN KEY ("related_addendum_id") REFERENCES "public"."pact_addendums"("id");



ALTER TABLE ONLY "public"."deposit_movements"
    ADD CONSTRAINT "deposit_movements_related_milestone_id_fkey" FOREIGN KEY ("related_milestone_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."deposit_movements"
    ADD CONSTRAINT "deposit_movements_triggered_by_user_id_fkey" FOREIGN KEY ("triggered_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."dispute_contributions"
    ADD CONSTRAINT "dispute_contributions_contributor_user_id_fkey" FOREIGN KEY ("contributor_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."dispute_contributions"
    ADD CONSTRAINT "dispute_contributions_dispute_id_fkey" FOREIGN KEY ("dispute_id") REFERENCES "public"."disputes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispute_escrows"
    ADD CONSTRAINT "dispute_escrows_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispute_escrows"
    ADD CONSTRAINT "dispute_escrows_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id");



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_resolution_doc_fk" FOREIGN KEY ("resolution_doc_id") REFERENCES "public"."documents"("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_signature_fk" FOREIGN KEY ("signature_id") REFERENCES "public"."signatures"("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_uploaded_by_user_id_fkey" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."legal_consents"
    ADD CONSTRAINT "legal_consents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_user_id_fkey" FOREIGN KEY ("sender_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."milestone_ai_verifications"
    ADD CONSTRAINT "milestone_ai_verifications_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."milestone_ai_verifications"
    ADD CONSTRAINT "milestone_ai_verifications_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."milestone_ai_verifications"
    ADD CONSTRAINT "milestone_ai_verifications_reviewed_by_user_id_fkey" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."milestone_evidences"
    ADD CONSTRAINT "milestone_evidences_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."milestone_evidences"
    ADD CONSTRAINT "milestone_evidences_uploaded_by_user_id_fkey" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."milestone_objections"
    ADD CONSTRAINT "milestone_objections_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."milestone_objections"
    ADD CONSTRAINT "milestone_objections_raised_by_user_id_fkey" FOREIGN KEY ("raised_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."milestone_state_transitions"
    ADD CONSTRAINT "milestone_state_transitions_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."milestone_state_transitions"
    ADD CONSTRAINT "milestone_state_transitions_transitioned_by_user_id_fkey" FOREIGN KEY ("transitioned_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."milestone_validations"
    ADD CONSTRAINT "milestone_validations_certificate_fk" FOREIGN KEY ("certificate_doc_id") REFERENCES "public"."documents"("id");



ALTER TABLE ONLY "public"."milestone_validations"
    ADD CONSTRAINT "milestone_validations_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."milestone_validations"
    ADD CONSTRAINT "milestone_validations_validator_user_id_fkey" FOREIGN KEY ("validator_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."milestones"
    ADD CONSTRAINT "milestones_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."milestones"
    ADD CONSTRAINT "milestones_payment_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id");



ALTER TABLE ONLY "public"."milestones"
    ADD CONSTRAINT "milestones_previous_version_id_fkey" FOREIGN KEY ("previous_version_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."milestone_objections"
    ADD CONSTRAINT "objections_dispute_fk" FOREIGN KEY ("resulting_dispute_id") REFERENCES "public"."disputes"("id");



ALTER TABLE ONLY "public"."organization_members"
    ADD CONSTRAINT "organization_members_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."organization_members"
    ADD CONSTRAINT "organization_members_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_members"
    ADD CONSTRAINT "organization_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pact_addendums"
    ADD CONSTRAINT "pact_addendums_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_addendums"
    ADD CONSTRAINT "pact_addendums_proposed_by_user_id_fkey" FOREIGN KEY ("proposed_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pact_events"
    ADD CONSTRAINT "pact_events_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pact_events"
    ADD CONSTRAINT "pact_events_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_health_scores"
    ADD CONSTRAINT "pact_health_scores_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_message_reads"
    ADD CONSTRAINT "pact_message_reads_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_message_reads"
    ADD CONSTRAINT "pact_message_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_messages"
    ADD CONSTRAINT "pact_messages_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_messages"
    ADD CONSTRAINT "pact_messages_sender_user_id_fkey" FOREIGN KEY ("sender_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pact_metadata"
    ADD CONSTRAINT "pact_metadata_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_parties"
    ADD CONSTRAINT "pact_parties_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pact_parties"
    ADD CONSTRAINT "pact_parties_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."pact_parties"
    ADD CONSTRAINT "pact_parties_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_parties"
    ADD CONSTRAINT "pact_parties_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pact_plan_items"
    ADD CONSTRAINT "pact_plan_items_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pact_plan_items"
    ADD CONSTRAINT "pact_plan_items_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_state_transitions"
    ADD CONSTRAINT "pact_state_transitions_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pact_state_transitions"
    ADD CONSTRAINT "pact_state_transitions_transitioned_by_user_id_fkey" FOREIGN KEY ("transitioned_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pacts"
    ADD CONSTRAINT "pacts_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."pacts"
    ADD CONSTRAINT "pacts_master_contract_fk" FOREIGN KEY ("master_contract_doc_id") REFERENCES "public"."documents"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_destination_org_id_fkey" FOREIGN KEY ("destination_org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_destination_user_id_fkey" FOREIGN KEY ("destination_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_source_org_id_fkey" FOREIGN KEY ("source_org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_source_user_id_fkey" FOREIGN KEY ("source_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."quality_holdbacks"
    ADD CONSTRAINT "quality_holdbacks_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "public"."milestones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quality_holdbacks"
    ADD CONSTRAINT "quality_holdbacks_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quality_holdbacks"
    ADD CONSTRAINT "quality_holdbacks_released_by_fkey" FOREIGN KEY ("released_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."signature_signers"
    ADD CONSTRAINT "signature_signers_signature_id_fkey" FOREIGN KEY ("signature_id") REFERENCES "public"."signatures"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."signature_signers"
    ADD CONSTRAINT "signature_signers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."signatures"
    ADD CONSTRAINT "signatures_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id");



ALTER TABLE ONLY "public"."surety_policies"
    ADD CONSTRAINT "surety_policies_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."surety_policies"
    ADD CONSTRAINT "surety_policies_pact_id_fkey" FOREIGN KEY ("pact_id") REFERENCES "public"."pacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_reputations"
    ADD CONSTRAINT "user_reputations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_organization_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



CREATE POLICY "Users can view milestone transitions of their pacts" ON "public"."milestone_state_transitions" FOR SELECT USING (("milestone_id" IN ( SELECT "m"."id"
   FROM ("public"."milestones" "m"
     JOIN "public"."pact_parties" "pp" ON (("pp"."pact_id" = "m"."pact_id")))
  WHERE ("pp"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view own audit entries" ON "public"."audit_log" FOR SELECT USING (("actor_user_id" = "auth"."uid"()));



CREATE POLICY "Users can view transitions of their pacts" ON "public"."pact_state_transitions" FOR SELECT USING (("pact_id" IN ( SELECT "pact_parties"."pact_id"
   FROM "public"."pact_parties"
  WHERE ("pact_parties"."user_id" = "auth"."uid"()))));



CREATE POLICY "aam_select_own" ON "public"."ai_assistant_messages" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "ai_assistant_messages"."user_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



COMMENT ON POLICY "aam_select_own" ON "public"."ai_assistant_messages" IS 'Auditoría 16-jul: los hilos del asistente IA son estrictamente del usuario que los generó. Antes cualquier parte del pacto los leía.';



ALTER TABLE "public"."acopio_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "acopio_read_party" ON "public"."acopio_items" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."pact_parties" "pp"
  WHERE (("pp"."pact_id" = "acopio_items"."pact_id") AND ("pp"."user_id" = ( SELECT "u"."id"
           FROM "public"."users" "u"
          WHERE ("u"."auth_provider_id" = ("auth"."uid"())::"text")
         LIMIT 1))))));



ALTER TABLE "public"."ai_assistant_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ai_fixtures" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ai_fixtures_select_active" ON "public"."ai_fixtures" FOR SELECT TO "authenticated" USING (("is_active" = true));



ALTER TABLE "public"."ai_prompts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ai_prompts_service_only" ON "public"."ai_prompts" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."ai_runs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."api_key_usage" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."api_keys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cae_enlaces_cliente" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cae_enlaces_todo_miembro" ON "public"."cae_enlaces_cliente" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_enlaces_cliente"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_enlaces_cliente"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id")))));



CREATE POLICY "cae_exp_todo_miembro" ON "public"."cae_expedientes" TO "authenticated" USING ("public"."fn_is_org_active_member"("organization_id")) WITH CHECK ("public"."fn_is_org_active_member"("organization_id"));



ALTER TABLE "public"."cae_expedientes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cae_lotes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cae_lotes_todo_miembro" ON "public"."cae_lotes" TO "authenticated" USING ("public"."fn_is_org_active_member"("organization_id")) WITH CHECK ("public"."fn_is_org_active_member"("organization_id"));



CREATE POLICY "cae_req_actualizar" ON "public"."cae_requisitos" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_requisitos"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id"))))) WITH CHECK ((("estado" <> 'verificado'::"public"."cae_estado_requisito") AND (EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_requisitos"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id"))))));



CREATE POLICY "cae_req_borrar" ON "public"."cae_requisitos" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_requisitos"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id")))));



CREATE POLICY "cae_req_crear" ON "public"."cae_requisitos" FOR INSERT TO "authenticated" WITH CHECK ((("estado" <> 'verificado'::"public"."cae_estado_requisito") AND (EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_requisitos"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id"))))));



CREATE POLICY "cae_req_leer" ON "public"."cae_requisitos" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."cae_expedientes" "e"
  WHERE (("e"."id" = "cae_requisitos"."expediente_id") AND "public"."fn_is_org_active_member"("e"."organization_id")))));



ALTER TABLE "public"."cae_requisitos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "de_read_party" ON "public"."dispute_escrows" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."pact_parties" "pp"
  WHERE (("pp"."pact_id" = "dispute_escrows"."pact_id") AND ("pp"."user_id" = ( SELECT "u"."id"
           FROM "public"."users" "u"
          WHERE ("u"."auth_provider_id" = ("auth"."uid"())::"text")
         LIMIT 1))))));



ALTER TABLE "public"."deposit_movements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "deposit_movements_select_party" ON "public"."deposit_movements" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."pact_parties" "pp"
     JOIN "public"."users" "u" ON (("u"."id" = "pp"."user_id")))
  WHERE (("pp"."pact_id" = "deposit_movements"."pact_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



ALTER TABLE "public"."dispute_contributions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dispute_escrows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."disputes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "documents_cae_delete" ON "public"."documents" FOR DELETE TO "authenticated" USING ("public"."fn_is_org_active_member"("public"."fn_cae_org_de_ruta"("storage_path")));



CREATE POLICY "documents_cae_insert" ON "public"."documents" FOR INSERT TO "authenticated" WITH CHECK ((("pact_id" IS NULL) AND "public"."fn_is_org_active_member"("public"."fn_cae_org_de_ruta"("storage_path")) AND ("uploaded_by_user_id" = "public"."current_user_id"())));



CREATE POLICY "documents_cae_select" ON "public"."documents" FOR SELECT TO "authenticated" USING ("public"."fn_is_org_active_member"("public"."fn_cae_org_de_ruta"("storage_path")));



CREATE POLICY "evidences_constructor_insert" ON "public"."milestone_evidences" FOR INSERT WITH CHECK ((("uploaded_by_user_id" = "public"."current_user_id"()) AND (EXISTS ( SELECT 1
   FROM ("public"."milestones" "m"
     JOIN "public"."pact_parties" "pp" ON (("pp"."pact_id" = "m"."pact_id")))
  WHERE (("m"."id" = "milestone_evidences"."milestone_id") AND ("pp"."role" = 'constructor'::"public"."pact_party_role") AND (("pp"."user_id" = "public"."current_user_id"()) OR ("pp"."organization_id" IN ( SELECT "users"."organization_id"
           FROM "public"."users"
          WHERE ("users"."id" = "public"."current_user_id"())))))))));



CREATE POLICY "evidences_party_select" ON "public"."milestone_evidences" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."milestones" "m"
  WHERE (("m"."id" = "milestone_evidences"."milestone_id") AND "public"."user_in_pact"("m"."pact_id", "public"."current_user_id"())))));



ALTER TABLE "public"."ipc_indices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ipc_read_all" ON "public"."ipc_indices" FOR SELECT USING (true);



ALTER TABLE "public"."legal_consents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "mai_verifications_select_party" ON "public"."milestone_ai_verifications" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."pact_parties" "pp"
     JOIN "public"."users" "u" ON (("u"."id" = "pp"."user_id")))
  WHERE (("pp"."pact_id" = "milestone_ai_verifications"."pact_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."milestone_ai_verifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."milestone_evidences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."milestone_objections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."milestone_state_transitions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."milestone_validations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."milestones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "milestones_party_select" ON "public"."milestones" FOR SELECT USING ("public"."user_in_pact"("pact_id", "public"."current_user_id"()));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_self_select" ON "public"."notifications" FOR SELECT USING (("user_id" = "public"."current_user_id"()));



CREATE POLICY "notifications_self_update" ON "public"."notifications" FOR UPDATE USING (("user_id" = "public"."current_user_id"()));



CREATE POLICY "org_member_select" ON "public"."organization_members" FOR SELECT TO "authenticated" USING ("public"."fn_is_org_active_member"("organization_id"));



CREATE POLICY "org_select_member" ON "public"."organizations" FOR SELECT TO "authenticated" USING ("public"."fn_is_org_active_member"("id"));



ALTER TABLE "public"."organization_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pact_addendums" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pact_addendums_select_party" ON "public"."pact_addendums" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."pact_parties" "pp"
     JOIN "public"."users" "u" ON (("u"."id" = "pp"."user_id")))
  WHERE (("pp"."pact_id" = "pact_addendums"."pact_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



ALTER TABLE "public"."pact_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pact_health_scores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pact_health_select" ON "public"."pact_health_scores" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."pact_parties" "pp"
     JOIN "public"."users" "u" ON (("u"."id" = "pp"."user_id")))
  WHERE (("pp"."pact_id" = "pact_health_scores"."pact_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



ALTER TABLE "public"."pact_message_reads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pact_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pact_metadata" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pact_metadata_read" ON "public"."pact_metadata" FOR SELECT USING ("public"."user_in_pact"("pact_id", "public"."current_user_id"()));



ALTER TABLE "public"."pact_parties" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pact_parties_party_select" ON "public"."pact_parties" FOR SELECT USING ("public"."user_in_pact"("pact_id", "public"."current_user_id"()));



ALTER TABLE "public"."pact_plan_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pact_plan_items_party_select" ON "public"."pact_plan_items" FOR SELECT USING ("public"."user_in_pact"("pact_id", "public"."current_user_id"()));



ALTER TABLE "public"."pact_state_transitions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pacts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pacts_creator_insert" ON "public"."pacts" FOR INSERT WITH CHECK (("created_by_user_id" = "public"."current_user_id"()));



CREATE POLICY "pacts_no_direct_update" ON "public"."pacts" FOR UPDATE USING (false);



CREATE POLICY "pacts_party_select" ON "public"."pacts" FOR SELECT USING ("public"."user_in_pact"("id", "public"."current_user_id"()));



ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payments_select_party" ON "public"."payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."pact_parties" "pp"
     JOIN "public"."users" "u" ON (("u"."id" = "pp"."user_id")))
  WHERE (("pp"."pact_id" = "payments"."pact_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



ALTER TABLE "public"."payouts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payouts_select_own" ON "public"."payouts" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "payouts"."user_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text")))));



CREATE POLICY "qh_read_party" ON "public"."quality_holdbacks" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."pact_parties" "pp"
  WHERE (("pp"."pact_id" = "quality_holdbacks"."pact_id") AND ("pp"."user_id" = ( SELECT "u"."id"
           FROM "public"."users" "u"
          WHERE ("u"."auth_provider_id" = ("auth"."uid"())::"text")
         LIMIT 1))))));



ALTER TABLE "public"."quality_holdbacks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."signature_signers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."signatures" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."surety_policies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "surety_policies_select_party" ON "public"."surety_policies" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."pact_parties" "pp"
     JOIN "public"."users" "u" ON (("u"."id" = "pp"."user_id")))
  WHERE (("pp"."pact_id" = "surety_policies"."pact_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))));



CREATE POLICY "user_rep_select" ON "public"."user_reputations" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "user_reputations"."user_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL)))) OR (EXISTS ( SELECT 1
   FROM (("public"."pact_parties" "pp1"
     JOIN "public"."pact_parties" "pp2" ON (("pp2"."pact_id" = "pp1"."pact_id")))
     JOIN "public"."users" "u" ON (("u"."id" = "pp1"."user_id")))
  WHERE (("pp2"."user_id" = "user_reputations"."user_id") AND ("u"."auth_provider_id" = ("auth"."uid"())::"text") AND ("u"."deleted_at" IS NULL))))));



ALTER TABLE "public"."user_reputations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_self_select" ON "public"."users" FOR SELECT USING (("auth_provider_id" = ("auth"."uid"())::"text"));



COMMENT ON POLICY "users_self_select" ON "public"."users" IS 'Cada usuario solo puede leer su propia fila. Compara auth_provider_id (texto del JWT sub) con auth.uid().';



CREATE POLICY "users_self_update" ON "public"."users" FOR UPDATE USING (("auth_provider_id" = ("auth"."uid"())::"text")) WITH CHECK (("auth_provider_id" = ("auth"."uid"())::"text"));



COMMENT ON POLICY "users_self_update" ON "public"."users" IS 'Auditoría 2026-07-13 C1: el usuario solo actualiza su propia fila (USING) y no puede reasignarla a otro auth_provider_id (WITH CHECK). El alcance por columna lo imponen los GRANT y el trigger enforce_users_privileged_columns.';



ALTER TABLE "public"."webhook_events" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT ALL ON SCHEMA "public" TO PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."_enqueue_notification"("p_user_id" "uuid", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_channel" "public"."notification_channel", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_enqueue_notification"("p_user_id" "uuid", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_channel" "public"."notification_channel", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_notify_users"("p_user_ids" "uuid"[], "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_prefix" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_notify_users"("p_user_ids" "uuid"[], "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_cta_url" "text", "p_idempotency_prefix" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."_sf_milestone_release_ledger"("p_milestone_id" "uuid", "p_actor" "uuid", "p_transfer_id" "text", "p_via" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_sf_milestone_release_ledger"("p_milestone_id" "uuid", "p_actor" "uuid", "p_transfer_id" "text", "p_via" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_kyc_verified"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_kyc_verified"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_users_privileged_columns"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_users_privileged_columns"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_block_ai_verification_mutations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_block_ai_verification_mutations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_clave_certificado_previo"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_clave_certificado_previo"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_documento_exige_fichero"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_documento_exige_fichero"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_expediente_entregado_es_terminal"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_expediente_entregado_es_terminal"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_expediente_inmutables"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_expediente_inmutables"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_lote_identidad_inmutable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_lote_identidad_inmutable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_org_de_ruta"("p_ruta" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_org_de_ruta"("p_ruta" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_puerta_certificado_previo"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_puerta_certificado_previo"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_cae_valida_lote"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_valida_lote"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."fn_cae_vista_cliente"("p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fn_cae_vista_cliente"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_cae_vista_cliente"("p_token" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."fn_cae_vista_cliente"("p_token" "text") TO "anon";



GRANT ALL ON FUNCTION "public"."fn_create_notifications"("p_user_ids" "uuid"[], "p_notification_type" "text", "p_title" "text", "p_body" "text", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_cta_url" "text", "p_priority" "text", "p_idempotency_root" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_create_notifications"("p_user_ids" "uuid"[], "p_notification_type" "text", "p_title" "text", "p_body" "text", "p_pact_id" "uuid", "p_milestone_id" "uuid", "p_cta_url" "text", "p_priority" "text", "p_idempotency_root" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_create_owner_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_create_owner_member"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_dispute_escrow_auto_create"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_dispute_escrow_auto_create"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_is_org_active_member"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_is_org_active_member"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_milestone_quality_check"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_milestone_quality_check"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_notification_recipients"("p_pact_id" "uuid", "p_target_roles" "text"[], "p_economic" boolean, "p_exclude_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_notification_recipients"("p_pact_id" "uuid", "p_target_roles" "text"[], "p_economic" boolean, "p_exclude_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_notifications_from_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_notifications_from_event"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."fn_notify_pact_message"("p_pact_id" "uuid", "p_sender_id" "uuid", "p_message_id" "uuid", "p_preview" "text", "p_event_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fn_notify_pact_message"("p_pact_id" "uuid", "p_sender_id" "uuid", "p_message_id" "uuid", "p_preview" "text", "p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_notify_pact_message"("p_pact_id" "uuid", "p_sender_id" "uuid", "p_message_id" "uuid", "p_preview" "text", "p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_user_acts_as_constructor_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_user_acts_as_constructor_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_user_can_act_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_user_can_act_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_user_can_move_money"("p_pact_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_user_can_move_money"("p_pact_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_user_can_view_economics_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_user_can_view_economics_on_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_user_in_pact"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_user_in_pact"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_validate_org_single_owner"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_validate_org_single_owner"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_reputation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_reputation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_notification_target"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_notification_target"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pact_health"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pact_health"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_reputation"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_reputation"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_addendum_active"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_addendum_active"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_deposit_low_alert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_deposit_low_alert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_link_pending_invitations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_link_pending_invitations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_milestone_paid_progress"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_milestone_paid_progress"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_milestone_paid_surety_decrement"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_milestone_paid_surety_decrement"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_milestone_state_recalc_health"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_milestone_state_recalc_health"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_pact_event_notify"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_pact_event_notify"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_party_invited_notify"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_party_invited_notify"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_notification_failed"("p_notification_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notification_failed"("p_notification_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_notification_sent"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notification_sent"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_deposit_movement_modification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_deposit_movement_modification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_event_modification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_event_modification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_evidence_modification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_evidence_modification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_accept_invitation"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_accept_invitation"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_accept_org_invite"("p_invitation_token" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_accept_org_invite"("p_invitation_token" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_add_milestone"("p_pact_id" "uuid", "p_ordinal" smallint, "p_name" "text", "p_amount_cents" bigint, "p_description" "text", "p_target_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_add_milestone"("p_pact_id" "uuid", "p_ordinal" smallint, "p_name" "text", "p_amount_cents" bigint, "p_description" "text", "p_target_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_addendum_create"("p_pact_id" "uuid", "p_title" "text", "p_extra_amount_cents" bigint, "p_description" "text", "p_extra_days" smallint, "p_justification" "text", "p_detailed_doc_storage_path" "text", "p_detailed_doc_sha256" "text", "p_detailed_doc_mime_type" "text", "p_detailed_doc_size_bytes" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_addendum_create"("p_pact_id" "uuid", "p_title" "text", "p_extra_amount_cents" bigint, "p_description" "text", "p_extra_days" smallint, "p_justification" "text", "p_detailed_doc_storage_path" "text", "p_detailed_doc_sha256" "text", "p_detailed_doc_mime_type" "text", "p_detailed_doc_size_bytes" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_addendum_sign"("p_addendum_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_addendum_sign"("p_addendum_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_ai_month_cost_cents"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_ai_month_cost_cents"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_ai_today_cost_cents"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_ai_today_cost_cents"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_apply_ipc_to_milestone"("p_milestone_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_apply_ipc_to_milestone"("p_milestone_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_attach_cert_doc"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_mime_type" "text", "p_size_bytes" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_attach_cert_doc"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_mime_type" "text", "p_size_bytes" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_attach_cert_invoice"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_invoice_number" "text", "p_size_bytes" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_attach_cert_invoice"("p_cert_id" "uuid", "p_storage_path" "text", "p_sha256" "text", "p_invoice_number" "text", "p_size_bytes" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_calc_ipc_adjustment"("p_base_month" "text", "p_current_month" "text", "p_amount_cents" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_calc_ipc_adjustment"("p_base_month" "text", "p_current_month" "text", "p_amount_cents" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_check_predeposit_deadlines"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_check_predeposit_deadlines"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_check_quality_holdback"("p_milestone_id" "uuid", "p_pact_id" "uuid", "p_amount_cents" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_check_quality_holdback"("p_milestone_id" "uuid", "p_pact_id" "uuid", "p_amount_cents" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_constructor_create_cert"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_constructor_create_cert"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_constructor_create_cert_v21"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_constructor_create_cert_v21"("p_pact_id" "uuid", "p_name" "text", "p_amount_cents" bigint, "p_description" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_constructor_edit_cert"("p_cert_id" "uuid", "p_name" "text", "p_description" "text", "p_amount_cents" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_constructor_edit_cert"("p_cert_id" "uuid", "p_name" "text", "p_description" "text", "p_amount_cents" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_count_unread_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_count_unread_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_create_acopio_milestone"("p_pact_id" "uuid", "p_name" "text", "p_total_cents" bigint, "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_create_acopio_milestone"("p_pact_id" "uuid", "p_name" "text", "p_total_cents" bigint, "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_create_organization"("p_legal_name" "text", "p_cif" "text", "p_description" "text", "p_org_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_create_organization"("p_legal_name" "text", "p_cif" "text", "p_description" "text", "p_org_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_create_pact_draft"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_obra_menor_declaration_accepted" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_create_pact_draft"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_obra_menor_declaration_accepted" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_create_pact_v2"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_deposit_required_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_create_pact_v2"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_deposit_required_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_create_pact_v21"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_advance_pct" numeric, "p_advance_reserve_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_create_pact_v21"("p_title" "text", "p_obra_address_line" "text", "p_total_amount_cents" bigint, "p_description" "text", "p_pact_type" "text", "p_obra_postal_code" "text", "p_obra_city" "text", "p_obra_province" "text", "p_obra_type" "text", "p_iva_rate_pct" numeric, "p_iva_included" boolean, "p_estimated_start_date" "date", "p_estimated_end_date" "date", "p_advance_pct" numeric, "p_advance_reserve_pct" numeric, "p_certification_frequency" "text", "p_obra_menor_declaration_accepted" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_delete_my_account"("p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_delete_my_account"("p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_delete_pact_message"("p_message_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_delete_pact_message"("p_message_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_deposit_dispute_escrow"("p_milestone_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_deposit_dispute_escrow"("p_milestone_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_finalize_pact_draft"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_finalize_pact_draft"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_finalize_pact_v2"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_finalize_pact_v2"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_finalize_pact_v21"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_finalize_pact_v21"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_dashboard_data"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_dashboard_data"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_invite_preview"("p_token" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_invite_preview"("p_token" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."sf_get_invite_preview"("p_token" "uuid") TO "anon";



GRANT ALL ON FUNCTION "public"."sf_get_milestone_detail"("p_milestone_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_milestone_detail"("p_milestone_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_get_monthly_series"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_get_monthly_series"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_monthly_series"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_my_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_my_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_my_profile_extended"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_my_profile_extended"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_org_members"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_org_members"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_pact_ai_context"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_pact_ai_context"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_pact_detail"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_pact_detail"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_get_quality_summary"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_get_quality_summary"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_import_budget_as_pact"("p_api_key" "text", "p_payload" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_import_budget_as_pact"("p_api_key" "text", "p_payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_invite_org_member"("p_org_id" "uuid", "p_invited_email" "text", "p_full_name" "text", "p_can_view_economics" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_invite_org_member"("p_org_id" "uuid", "p_invited_email" "text", "p_full_name" "text", "p_can_view_economics" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_invite_party"("p_pact_id" "uuid", "p_role" "text", "p_email" "text", "p_full_name" "text", "p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_invite_party"("p_pact_id" "uuid", "p_role" "text", "p_email" "text", "p_full_name" "text", "p_phone" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_link_cert_to_plan_item"("p_milestone_id" "uuid", "p_plan_item_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_link_cert_to_plan_item"("p_milestone_id" "uuid", "p_plan_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_link_cert_to_plan_item"("p_milestone_id" "uuid", "p_plan_item_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_link_costpact_budget"("p_pact_id" "uuid", "p_presupuesto_id" "text", "p_items" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_link_costpact_budget"("p_pact_id" "uuid", "p_presupuesto_id" "text", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_link_costpact_budget"("p_pact_id" "uuid", "p_presupuesto_id" "text", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_list_my_notifications"("p_limit" integer, "p_only_unread" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_list_my_notifications"("p_limit" integer, "p_only_unread" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_list_my_orgs"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_list_my_orgs"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_list_my_pacts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_list_my_pacts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_list_pact_messages"("p_pact_id" "uuid", "p_limit" integer, "p_before_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_list_pact_messages"("p_pact_id" "uuid", "p_limit" integer, "p_before_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_mark_all_notifications_read"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_mark_all_notifications_read"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_mark_notification_read"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_mark_notification_read"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_mark_pact_read"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_mark_pact_read"("p_pact_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_milestone_confirm_release"("p_milestone_id" "uuid", "p_amount_cents" bigint, "p_transfer_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_milestone_confirm_release"("p_milestone_id" "uuid", "p_amount_cents" bigint, "p_transfer_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_milestone_force_advance"("p_milestone_id" "uuid", "p_disclaimer_accepted" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_milestone_force_advance"("p_milestone_id" "uuid", "p_disclaimer_accepted" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_milestone_promotor_decide"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_milestone_promotor_decide"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_milestone_tech_review"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_milestone_tech_review"("p_milestone_id" "uuid", "p_decision" "text", "p_rationale" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_my_milestone_releases"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_my_milestone_releases"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_my_milestone_releases"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_pact_finalize_settlement"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_pact_finalize_settlement"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_pact_fund_initial"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_pact_fund_initial"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_pact_predeposit_milestone"("p_milestone_id" "uuid", "p_amount_cents" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_pact_predeposit_milestone"("p_milestone_id" "uuid", "p_amount_cents" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_pact_replenish_deposit"("p_pact_id" "uuid", "p_amount_cents" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_pact_replenish_deposit"("p_pact_id" "uuid", "p_amount_cents" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_pact_setup_advance"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_pact_setup_advance"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_plan_item_kind"("p_trigger" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_plan_item_kind"("p_trigger" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_recalc_pact_health"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_recalc_pact_health"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_recalc_user_reputation"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_recalc_user_reputation"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_record_ai_verification"("p_milestone_id" "uuid", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_hash" "text", "p_evidences_count" smallint, "p_documents_count" smallint, "p_score" smallint, "p_verdict" "text", "p_summary" "text", "p_findings" "jsonb", "p_checklist_match" "jsonb", "p_recommendation" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cache_read_tokens" integer, "p_cost_cents" bigint, "p_duration_ms" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_record_ai_verification"("p_milestone_id" "uuid", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_hash" "text", "p_evidences_count" smallint, "p_documents_count" smallint, "p_score" smallint, "p_verdict" "text", "p_summary" "text", "p_findings" "jsonb", "p_checklist_match" "jsonb", "p_recommendation" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cache_read_tokens" integer, "p_cost_cents" bigint, "p_duration_ms" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_record_ai_verification"("p_milestone_id" "uuid", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_hash" "text", "p_evidences_count" smallint, "p_documents_count" smallint, "p_score" smallint, "p_verdict" "text", "p_summary" "text", "p_findings" "jsonb", "p_checklist_match" "jsonb", "p_recommendation" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cache_read_tokens" integer, "p_cost_cents" bigint, "p_duration_ms" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_record_assistant_turn"("p_pact_id" "uuid", "p_user_message" "text", "p_assistant_content" "text", "p_assistant_blocks" "jsonb", "p_tool_call_name" "text", "p_tool_call_input" "jsonb", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cost_cents" bigint, "p_latency_ms" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_record_assistant_turn"("p_pact_id" "uuid", "p_user_message" "text", "p_assistant_content" "text", "p_assistant_blocks" "jsonb", "p_tool_call_name" "text", "p_tool_call_input" "jsonb", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cost_cents" bigint, "p_latency_ms" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_record_assistant_turn"("p_pact_id" "uuid", "p_user_message" "text", "p_assistant_content" "text", "p_assistant_blocks" "jsonb", "p_tool_call_name" "text", "p_tool_call_input" "jsonb", "p_provider" "text", "p_model" "text", "p_prompt_version" "text", "p_input_tokens" integer, "p_output_tokens" integer, "p_cost_cents" bigint, "p_latency_ms" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_record_milestone_evidence"("p_milestone_id" "uuid", "p_evidence_type" "text", "p_storage_path" "text", "p_sha256_hash" "text", "p_file_size_bytes" bigint, "p_mime_type" "text", "p_gps_latitude" double precision, "p_gps_longitude" double precision, "p_gps_accuracy_meters" double precision, "p_client_timestamp" timestamp with time zone, "p_description" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_record_milestone_evidence"("p_milestone_id" "uuid", "p_evidence_type" "text", "p_storage_path" "text", "p_sha256_hash" "text", "p_file_size_bytes" bigint, "p_mime_type" "text", "p_gps_latitude" double precision, "p_gps_longitude" double precision, "p_gps_accuracy_meters" double precision, "p_client_timestamp" timestamp with time zone, "p_description" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_release_acopio_item"("p_item_id" "uuid", "p_amount_cents" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_release_acopio_item"("p_item_id" "uuid", "p_amount_cents" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_resolve_dispute_escrow"("p_milestone_id" "uuid", "p_resolution" "text", "p_promotor_pct" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_resolve_dispute_escrow"("p_milestone_id" "uuid", "p_resolution" "text", "p_promotor_pct" numeric, "p_note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_revoke_org_member"("p_member_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_revoke_org_member"("p_member_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_send_pact_message"("p_pact_id" "uuid", "p_body" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_send_pact_message"("p_pact_id" "uuid", "p_body" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_set_my_locale"("p_locale" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_set_my_locale"("p_locale" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_set_my_locale"("p_locale" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_sign_contract"("p_pact_id" "uuid", "p_consent_text_hash" "text", "p_user_agent" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_sign_contract"("p_pact_id" "uuid", "p_consent_text_hash" "text", "p_user_agent" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_submit_milestone_for_review"("p_milestone_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_submit_milestone_for_review"("p_milestone_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_unread_pact_messages_count"("p_pact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_unread_pact_messages_count"("p_pact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_update_member_permissions"("p_member_id" "uuid", "p_can_view_economics" boolean, "p_receive_notifications" boolean, "p_receive_economic_notifications" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_update_member_permissions"("p_member_id" "uuid", "p_can_view_economics" boolean, "p_receive_notifications" boolean, "p_receive_economic_notifications" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sf_update_my_profile"("p_full_name" "text", "p_phone_e164" "text", "p_avatar_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sf_update_my_profile"("p_full_name" "text", "p_phone_e164" "text", "p_avatar_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sf_write_pact_plan"("p_pact_id" "uuid", "p_items" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sf_write_pact_plan"("p_pact_id" "uuid", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_pact_type_requires_tecnico"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_pact_type_requires_tecnico"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_in_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_in_pact"("p_pact_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_milestone_state_transition"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_milestone_state_transition"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_pact_state_transition"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_pact_state_transition"() TO "service_role";
























GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."acopio_items" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."acopio_items" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_assistant_messages" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_assistant_messages" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_fixtures" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_fixtures" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_prompts" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_runs" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ai_runs" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."api_key_usage" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."api_key_usage" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."api_keys" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."api_keys" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."app_settings" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."app_settings" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."audit_log" TO "service_role";
GRANT SELECT ON TABLE "public"."audit_log" TO "authenticated";
GRANT SELECT ON TABLE "public"."audit_log" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_enlaces_cliente" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_enlaces_cliente" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_expedientes" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_expedientes" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_lotes" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_lotes" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_requisitos" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."cae_requisitos" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."conversations" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."conversations" TO "authenticated";
GRANT SELECT ON TABLE "public"."conversations" TO "anon";



GRANT SELECT,INSERT ON TABLE "public"."deposit_movements" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."deposit_movements" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."dispute_contributions" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."dispute_contributions" TO "authenticated";
GRANT SELECT ON TABLE "public"."dispute_contributions" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."dispute_escrows" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."dispute_escrows" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."disputes" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."disputes" TO "authenticated";
GRANT SELECT ON TABLE "public"."disputes" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."documents" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."documents" TO "authenticated";
GRANT SELECT ON TABLE "public"."documents" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ipc_indices" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ipc_indices" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."legal_consents" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."legal_consents" TO "authenticated";
GRANT SELECT ON TABLE "public"."legal_consents" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."messages" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."messages" TO "authenticated";
GRANT SELECT ON TABLE "public"."messages" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_ai_verifications" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_ai_verifications" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_evidences" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_evidences" TO "authenticated";
GRANT SELECT ON TABLE "public"."milestone_evidences" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_objections" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_objections" TO "authenticated";
GRANT SELECT ON TABLE "public"."milestone_objections" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_state_transitions" TO "service_role";
GRANT SELECT ON TABLE "public"."milestone_state_transitions" TO "authenticated";
GRANT SELECT ON TABLE "public"."milestone_state_transitions" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_validations" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestone_validations" TO "authenticated";
GRANT SELECT ON TABLE "public"."milestone_validations" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestones" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."milestones" TO "authenticated";
GRANT SELECT ON TABLE "public"."milestones" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."notifications" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."notifications" TO "authenticated";
GRANT SELECT ON TABLE "public"."notifications" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."organization_members" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."organization_members" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."organizations" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."organizations" TO "authenticated";
GRANT SELECT ON TABLE "public"."organizations" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_addendums" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_addendums" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_events" TO "service_role";
GRANT SELECT,INSERT ON TABLE "public"."pact_events" TO "authenticated";
GRANT SELECT ON TABLE "public"."pact_events" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_health_scores" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_health_scores" TO "authenticated";
GRANT SELECT ON TABLE "public"."pact_health_scores" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_message_reads" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_message_reads" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_messages" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_messages" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_metadata" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_metadata" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_parties" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_parties" TO "authenticated";
GRANT SELECT ON TABLE "public"."pact_parties" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_plan_items" TO "service_role";
GRANT SELECT ON TABLE "public"."pact_plan_items" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pact_state_transitions" TO "service_role";
GRANT SELECT ON TABLE "public"."pact_state_transitions" TO "authenticated";
GRANT SELECT ON TABLE "public"."pact_state_transitions" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pacts" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."pacts" TO "authenticated";
GRANT SELECT ON TABLE "public"."pacts" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."payments" TO "service_role";
GRANT SELECT ON TABLE "public"."payments" TO "authenticated";
GRANT SELECT ON TABLE "public"."payments" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."payouts" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."payouts" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."quality_holdbacks" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."quality_holdbacks" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."signature_signers" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."signature_signers" TO "authenticated";
GRANT SELECT ON TABLE "public"."signature_signers" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."signatures" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."signatures" TO "authenticated";
GRANT SELECT ON TABLE "public"."signatures" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."surety_policies" TO "authenticated";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."surety_policies" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."user_reputations" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."user_reputations" TO "authenticated";
GRANT SELECT ON TABLE "public"."user_reputations" TO "anon";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."users" TO "service_role";
GRANT SELECT,INSERT,DELETE ON TABLE "public"."users" TO "authenticated";
GRANT SELECT ON TABLE "public"."users" TO "anon";



GRANT UPDATE("full_name") ON TABLE "public"."users" TO "authenticated";



GRANT UPDATE("phone_e164") ON TABLE "public"."users" TO "authenticated";



GRANT UPDATE("marketing_consent_at") ON TABLE "public"."users" TO "authenticated";



GRANT UPDATE("avatar_url") ON TABLE "public"."users" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_my_pacts_summary" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_my_pacts_summary" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_pact_financial_progress" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_pact_financial_progress" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_user_active_pacts" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_user_active_pacts" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."webhook_events" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,USAGE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,USAGE ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO "service_role";

-- =====================================================================
-- 2 · Fuera de public
-- =====================================================================

-- El volcado deja search_path vacío; las políticas de Storage referencian
-- funciones de public sin esquema (así las devuelve pg_policies).
SELECT pg_catalog.set_config('search_path', 'public, extensions', false);

-- Alta de perfil al crear usuario en Auth
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- Buckets de Storage
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('milestone-evidences', 'milestone-evidences', false, 20971520, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'video/mp4', 'video/quicktime', 'application/pdf']::text[])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('cae-documentos', 'cae-documentos', false, 20971520, ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic']::text[])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Políticas de Storage (storage.objects)
DROP POLICY IF EXISTS "Avatars owner delete" ON storage.objects;
CREATE POLICY "Avatars owner delete" ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated
  USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
DROP POLICY IF EXISTS "Avatars owner update" ON storage.objects;
CREATE POLICY "Avatars owner update" ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
DROP POLICY IF EXISTS "Avatars owner upload" ON storage.objects;
CREATE POLICY "Avatars owner upload" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
DROP POLICY IF EXISTS "Avatars public read" ON storage.objects;
CREATE POLICY "Avatars public read" ON storage.objects AS PERMISSIVE FOR SELECT TO public
  USING ((bucket_id = 'avatars'::text));
DROP POLICY IF EXISTS "cae_documentos_borrar" ON storage.objects;
CREATE POLICY "cae_documentos_borrar" ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated
  USING (((bucket_id = 'cae-documentos'::text) AND fn_is_org_active_member(fn_cae_org_de_ruta(('cae-documentos/'::text || name)))));
DROP POLICY IF EXISTS "cae_documentos_leer" ON storage.objects;
CREATE POLICY "cae_documentos_leer" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated
  USING (((bucket_id = 'cae-documentos'::text) AND fn_is_org_active_member(fn_cae_org_de_ruta(('cae-documentos/'::text || name)))));
DROP POLICY IF EXISTS "cae_documentos_subir" ON storage.objects;
CREATE POLICY "cae_documentos_subir" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'cae-documentos'::text) AND fn_is_org_active_member(fn_cae_org_de_ruta(('cae-documentos/'::text || name)))));
DROP POLICY IF EXISTS "milestone_evidences_insert_party_or_member" ON storage.objects;
CREATE POLICY "milestone_evidences_insert_party_or_member" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'milestone-evidences'::text) AND ((EXISTS ( SELECT 1
   FROM (pact_parties pp
     JOIN users u ON ((u.id = pp.user_id)))
  WHERE ((u.auth_provider_id = (auth.uid())::text) AND ((pp.role)::text = 'constructor'::text) AND ((pp.pact_id)::text = split_part(objects.name, '/'::text, 1))))) OR (EXISTS ( SELECT 1
   FROM (((pact_parties pp
     JOIN organizations o ON (((o.owner_user_id = pp.user_id) AND (o.deleted_at IS NULL))))
     JOIN organization_members om ON ((om.organization_id = o.id)))
     JOIN users u ON ((u.id = om.user_id)))
  WHERE ((u.auth_provider_id = (auth.uid())::text) AND ((pp.role)::text = 'constructor'::text) AND ((pp.pact_id)::text = split_part(objects.name, '/'::text, 1)) AND (om.state = 'active'::org_member_state)))))));
DROP POLICY IF EXISTS "milestone_evidences_no_delete" ON storage.objects;
CREATE POLICY "milestone_evidences_no_delete" ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated
  USING (false);
DROP POLICY IF EXISTS "milestone_evidences_no_update" ON storage.objects;
CREATE POLICY "milestone_evidences_no_update" ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated
  USING (false);
DROP POLICY IF EXISTS "milestone_evidences_select_party_or_member" ON storage.objects;
CREATE POLICY "milestone_evidences_select_party_or_member" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated
  USING (((bucket_id = 'milestone-evidences'::text) AND ((EXISTS ( SELECT 1
   FROM (pact_parties pp
     JOIN users u ON ((u.id = pp.user_id)))
  WHERE ((u.auth_provider_id = (auth.uid())::text) AND ((pp.pact_id)::text = split_part(objects.name, '/'::text, 1))))) OR (EXISTS ( SELECT 1
   FROM (((pact_parties pp
     JOIN organizations o ON (((o.owner_user_id = pp.user_id) AND (o.deleted_at IS NULL))))
     JOIN organization_members om ON ((om.organization_id = o.id)))
     JOIN users u ON ((u.id = om.user_id)))
  WHERE ((u.auth_provider_id = (auth.uid())::text) AND ((pp.pact_id)::text = split_part(objects.name, '/'::text, 1)) AND ((pp.role)::text = ANY (ARRAY['constructor'::text, 'tecnico'::text])) AND (om.state = 'active'::org_member_state)))))));

-- Tareas programadas (pg_cron)
SELECT cron.unschedule('check-predeposit-deadlines') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-predeposit-deadlines');
SELECT cron.schedule('check-predeposit-deadlines', '0 * * * *', 'SELECT public.sf_check_predeposit_deadlines();');

-- =====================================================================
-- 3 · Datos de configuración (sin usuarios: *_by_user_id = NULL)
-- =====================================================================
INSERT INTO public.ai_fixtures
SELECT * FROM jsonb_populate_recordset(NULL::public.ai_fixtures, $cfg$[{"created_at": "2026-05-26T13:21:20.442643+00:00", "description": "Fallback genérico · dictamen review", "fixture_key": "vision_default_review", "fixture_type": "vision", "id": "bcc15f46-d3d3-4ffd-b565-11ce5e8012ca", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": true, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": false, "note": "No se observa foto del estado tras limpieza.", "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 12400, "findings": [{"evidence_ref": "evidences/m3/photo_03.jpg", "id": "f1", "message": "La foto 03 muestra parcialmente otra estancia (parece pasillo). El alcance del hito es solado del salón. Verifica que la imagen corresponde al área certificada o reemplázala por una vista clara del salón.", "severity": "amber", "type": "photo"}, {"evidence_ref": "evidences/m3/invoice_b.pdf", "id": "f2", "message": "La factura invoice_b.pdf describe instalación sanitaria (1.240 € — Fontanería del Sur SL), no solado. Además el emisor no coincide con la constructora del pacto (Construcciones Pérez SL). No procede adjuntarla a este hito.", "severity": "red", "type": "invoice"}], "recommendation": "Sustituye invoice_b.pdf por la factura correcta del solado emitida por Construcciones Pérez SL. Reemplaza o complementa la foto 03 con una vista clara del salón. Añade una foto post-limpieza. El resto del hito es correcto y puede firmarse una vez resueltos los hallazgos.", "score": 78, "summary": "Las 6 fotos documentan el solado del salón con buena cobertura del proceso (replanteo, pegado, rejuntado, vista final). Detectamos una foto parcialmente ambigua y una factura que no encaja con este hito.", "verdict": "review_needed"}, "updated_at": "2026-05-26T13:21:20.442643+00:00"}, {"created_at": "2026-05-26T13:21:20.442643+00:00", "description": "Fallback genérico · dictamen ok", "fixture_key": "vision_default_ok", "fixture_type": "vision", "id": "2bec5bea-3865-40c3-a071-5af7abd1b3ba", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": true, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": true, "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 11200, "findings": [], "recommendation": "Hito listo para firmar. Sin objeciones.", "score": 91, "summary": "Las 6 fotos y la factura del hito Solado salón están completas y coherentes. Emisor de la factura coincide con Construcciones Pérez SL, importe dentro del presupuesto del hito (12.000 €).", "verdict": "ok"}, "updated_at": "2026-05-26T13:21:20.442643+00:00"}, {"created_at": "2026-05-26T13:21:20.442643+00:00", "description": "Fallback genérico · dictamen block", "fixture_key": "vision_default_block", "fixture_type": "vision", "id": "fd7f29fe-3858-44ee-85f5-08535e68950f", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": false, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": false, "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 13700, "findings": [{"evidence_ref": "evidences/m3/photo_03.jpg", "id": "f1", "message": "Las fotos 03 y 04 parecen la misma imagen con ligera variación de ángulo. No constituyen evidencia adicional del proceso.", "severity": "red", "type": "photo"}, {"evidence_ref": "evidences/m3/invoice_b.pdf", "id": "f2", "message": "Factura emitida por Fontanería del Sur SL, no por la constructora del pacto. No procede para este hito.", "severity": "red", "type": "invoice"}, {"id": "f3", "message": "No hay ninguna foto que documente la limpieza final del solado, tarea explícita del checklist.", "severity": "red", "type": "checklist"}], "recommendation": "No procede firmar la certificación hasta sustituir la factura, eliminar la foto duplicada y aportar evidencia de la limpieza final.", "score": 42, "summary": "Las evidencias subidas son insuficientes y presentan inconsistencias graves: dos fotos del checklist están duplicadas y la factura corresponde a otro hito.", "verdict": "block"}, "updated_at": "2026-05-26T13:21:20.442643+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 1 (demoliciones) dictamen ok", "fixture_key": "vision_default_m1_ok", "fixture_type": "vision", "id": "5ff4c354-dda5-4b6f-9085-07443ffe1788", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Desmontaje sanitario y mobiliario"}, {"evidence_ok": true, "task_id": "t2", "title": "Picado de azulejos en baño y cocina"}, {"evidence_ok": true, "task_id": "t3", "title": "Retirada de escombros a punto limpio"}], "demo_simulated_latency_ms": 9300, "findings": [], "recommendation": "Hito listo para firmar. Las evidencias son completas y coherentes.", "score": 92, "summary": "Las 3 fotos documentan correctamente la demolición de baño y cocina y la salida de escombros. La factura del punto limpio coincide con el alcance del hito.", "verdict": "ok"}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 2 (albañilería) dictamen ok", "fixture_key": "vision_default_m2_ok", "fixture_type": "vision", "id": "0bc46482-775f-40ae-ab41-66d6c6bc685f", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Tabiques pladur dormitorio principal"}, {"evidence_ok": true, "task_id": "t2", "title": "Apertura hueco salón-cocina"}, {"evidence_ok": true, "task_id": "t3", "title": "Refuerzo dintel"}], "demo_simulated_latency_ms": 10800, "findings": [{"evidence_ref": "evidences/m2/photo_02.jpg", "id": "f1", "message": "La foto muestra el hueco abierto pero no permite verificar el solape de la viga sobre el muro. Sugerimos guardar el plano de detalle como evidencia adicional para el Libro del Edificio.", "severity": "green", "type": "photo"}], "recommendation": "Hito listo para firmar. La nota sobre el plano de detalle es opcional, no bloqueante.", "score": 88, "summary": "Tabiquería y apertura de hueco salón-cocina ejecutadas según plano. Refuerzo del dintel visible y correctamente armado.", "verdict": "ok"}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 3 (solado salón) dictamen ok · VARIANTE happy path", "fixture_key": "vision_default_m3_ok", "fixture_type": "vision", "id": "9e1072cf-2544-4883-89f0-a1d4841b78b9", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": true, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": true, "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 11200, "findings": [], "recommendation": "Hito listo para firmar. Sin objeciones.", "score": 91, "summary": "Las 6 fotos y la factura del hito Solado salón están completas y coherentes. Emisor de la factura coincide con Construcciones Pérez SL, importe dentro del presupuesto del hito (12.000 €).", "verdict": "ok"}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Fallback canónico cuando no hay match de intent", "fixture_key": "assistant_fallback_default", "fixture_type": "assistant_fallback", "id": "65eb5680-b418-467b-a793-28618e97b05a", "is_active": true, "payload": {"response": {"text": "Para esta pregunta concreta prefiero que lo veas con soporte humano de PactStream — te abro un ticket con el contexto del pacto si quieres. Mientras tanto, ¿puedo ayudarte con algo del estado del pacto, los hitos pendientes o el último dictamen?"}}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 3 (solado salón) dictamen review_needed · VARIANTE PRINCIPAL", "fixture_key": "vision_default_m3_review", "fixture_type": "vision", "id": "0e80a95d-f628-4c77-806d-f4e54f019f5c", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": true, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": false, "note": "No se observa foto del estado tras limpieza.", "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 12400, "findings": [{"evidence_ref": "evidences/m3/photo_03.jpg", "id": "f1", "message": "La foto 03 muestra parcialmente otra estancia (parece pasillo). El alcance del hito es solado del salón. Verifica que la imagen corresponde al área certificada o reemplázala por una vista clara del salón.", "severity": "amber", "type": "photo"}, {"evidence_ref": "evidences/m3/invoice_b.pdf", "id": "f2", "message": "La factura invoice_b.pdf describe instalación sanitaria (1.240 € — Fontanería del Sur SL), no solado. Además el emisor no coincide con la constructora del pacto (Construcciones Pérez SL). No procede adjuntarla a este hito.", "severity": "red", "type": "invoice"}], "recommendation": "Sustituye invoice_b.pdf por la factura correcta del solado emitida por Construcciones Pérez SL. Reemplaza o complementa la foto 03 con una vista clara del salón. Añade una foto post-limpieza. El resto del hito es correcto y puede firmarse una vez resueltos los hallazgos.", "score": 78, "summary": "Las 6 fotos documentan el solado del salón con buena cobertura del proceso (replanteo, pegado, rejuntado, vista final). Detectamos una foto parcialmente ambigua y una factura que no encaja con este hito.", "verdict": "review_needed"}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 3 (solado salón) dictamen block · VARIANTE crítica", "fixture_key": "vision_default_m3_block", "fixture_type": "vision", "id": "7c7d4845-8252-4862-9bb3-600299164e27", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": false, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": false, "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 13700, "findings": [{"evidence_ref": "evidences/m3/photo_03.jpg", "id": "f1", "message": "Las fotos 03 y 04 parecen la misma imagen con ligera variación de ángulo. No constituyen evidencia adicional del proceso.", "severity": "red", "type": "photo"}, {"evidence_ref": "evidences/m3/invoice_b.pdf", "id": "f2", "message": "Factura emitida por Fontanería del Sur SL, no por la constructora del pacto. No procede para este hito.", "severity": "red", "type": "invoice"}, {"id": "f3", "message": "No hay ninguna foto que documente la limpieza final del solado, tarea explícita del checklist.", "severity": "red", "type": "checklist"}], "recommendation": "No procede firmar la certificación hasta sustituir la factura, eliminar la foto duplicada y aportar evidencia de la limpieza final.", "score": 42, "summary": "Las evidencias subidas son insuficientes y presentan inconsistencias graves: dos fotos del checklist están duplicadas y la factura corresponde a otro hito.", "verdict": "block"}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: estado actual del pacto", "fixture_key": "intent_estado_pacto", "fixture_type": "assistant_intent", "id": "c57e51a3-27ab-4a63-861f-43304d7dd8c0", "is_active": true, "payload": {"applies_to_roles": ["promotor", "constructor", "tecnico", "admin"], "response": {"text": "Vais por el Hito 3 · Solado salón (12.000 €). Está marcado como listo para certificar por Construcciones Pérez pero el técnico aún no ha firmado. La IA detectó dos hallazgos a revisar antes de firmar: una foto ambigua y una factura que no corresponde a este hito.\n\nLlevamos 22.000 € liberados de 80.000 €, escrow en 36.500 € disponible. Quedan 3 hitos por arrancar tras este.\n\n¿Quieres que te explique los hallazgos o que se los pida a la constructora?"}, "trigger_keywords": ["en que hito", "en qué hito", "que falta", "qué falta", "como va", "cómo va", "estado", "donde vamos", "donde estamos"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: explicar dictamen Vision", "fixture_key": "intent_explicar_dictamen", "fixture_type": "assistant_intent", "id": "e9f16875-890a-4bd6-ad33-25a131064102", "is_active": true, "payload": {"applies_to_roles": ["promotor", "constructor", "tecnico", "admin"], "response": {"text": "Hay dos cosas en el Hito 3:\n\n1. Foto 03 (ámbar). La imagen muestra parcialmente el pasillo, no el salón. No es grave, pero conviene reemplazarla por una vista clara del salón para que el Libro del Edificio quede limpio.\n\n2. Factura invoice_b.pdf (rojo). Es de Fontanería del Sur SL por 1.240 €, instalación sanitaria. No corresponde a este hito (Solado salón) y además no la emite la constructora del pacto. Esa factura no debería estar aquí.\n\nLa recomendación es sustituir la factura por la correcta del solado y reemplazar la foto. El resto del hito está bien."}, "trigger_keywords": ["por que", "por qué", "porque", "hallazgo", "explica el dictamen", "que dice la ia", "qué dice la ia", "marco la foto", "marcó la foto", "factura incorrecta"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: pedir evidencia a la constructora · con tool call", "fixture_key": "intent_pedir_evidencia", "fixture_type": "assistant_intent", "id": "c67fb70d-6b58-4623-9190-afaca2797d49", "is_active": true, "payload": {"applies_to_roles": ["promotor", "tecnico", "admin"], "response": {"text": "Voy a notificar a la constructora con los 2 ítems pendientes:\n\n• Foto adicional del salón (sustituyendo la foto 03).\n• Factura correcta del Hito 3 · Solado salón, emitida por Construcciones Pérez SL.\n\n¿Confirmas la solicitud?"}, "tool_call_proposed": {"input": {"items": ["Foto adicional del salón post-limpieza (hallazgo f1)", "Factura correcta del Hito 3 Solado salón emitida por Construcciones Pérez SL (hallazgo f2)"], "milestone_ordinal": 3, "to_role": "constructor"}, "name": "request_evidence"}, "trigger_keywords": ["pidelo", "pídelo", "pideselo", "pídeselo", "pedir a la constructora", "pedir evidencia", "que la cambien", "sustituir factura", "que lo arreglen"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: cuánto queda por liberar", "fixture_key": "intent_cuanto_falta_liberar", "fixture_type": "assistant_intent", "id": "c89082d0-863a-42b8-8a11-ddf5053fdb8c", "is_active": true, "payload": {"applies_to_roles": ["promotor", "constructor", "tecnico", "admin"], "response": {"text": "Saldo en escrow: 36.500 € disponibles (de los 80.000 € iniciales). Liberados: 22.000 € (hitos 1 y 2). Bloqueados por disputa: 0 €.\n\nEn cuanto se firme el Hito 3 (12.000 €) y pasen las 24 h de objeción, se libera automáticamente. Quedarían entonces 24.500 € repartidos en los hitos 4-5-6."}, "trigger_keywords": ["cuanto queda", "cuánto queda", "cuanto falta", "cuánto falta", "saldo escrow", "que saldo", "qué saldo", "presupuesto restante", "cuanto hay"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: cómo objetar · con tool call", "fixture_key": "intent_como_objetar", "fixture_type": "assistant_intent", "id": "0073240a-94e2-484a-805d-98944672b1b1", "is_active": true, "payload": {"applies_to_roles": ["promotor", "admin"], "response": {"text": "Si quieres objetar la certificación del Hito 3 antes de que se libere, tienes 24 h desde la firma del técnico. La objeción cambia el hito a estado DISPUTA y retiene los fondos 10 días para mediación.\n\nMi sugerencia antes de objetar: dado que la IA ya marcó la factura como incorrecta, suele ser más rápido pedir la corrección que abrir disputa. Pero la decisión es tuya. Si decides objetar, indícame brevemente el motivo y lo registro."}, "tool_call_proposed": {"input": {"milestone_ordinal": 3, "reason_template": "[Pendiente: motivo del promotor]"}, "name": "raise_objection"}, "trigger_keywords": ["como objeto", "cómo objeto", "como lo objeto", "cómo lo objeto", "no estoy conforme", "no acepto", "quiero parar", "quiero objetar"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: qué evidencia subir para certificar", "fixture_key": "intent_que_evidencia_subo", "fixture_type": "assistant_intent", "id": "d6ebb5a3-1e5f-4f6e-86a3-5e5e96459e47", "is_active": true, "payload": {"applies_to_roles": ["tecnico", "constructor"], "response": {"text": "Para el Hito 3 · Solado salón, el checklist pide 3 tareas. Te recomiendo subir:\n\n• 1 foto de replanteo y nivelación antes de pegar.\n• 1-2 fotos del pegado en curso (muestra el material y la junta).\n• 1 foto del rejuntado completo.\n• 1 foto post-limpieza final (la que falta hoy).\n• 1 factura emitida por Construcciones Pérez SL con concepto solado e importe ≤ 12.000 €.\n\nLas fotos las puedes hacer con el móvil, la app redimensiona automáticamente antes de subir."}, "trigger_keywords": ["que subo", "qué subo", "que evidencia", "qué evidencia", "que fotos", "qué fotos", "que necesito"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: resumen ejecutivo del pacto · con tool call", "fixture_key": "intent_resumen_pacto", "fixture_type": "assistant_intent", "id": "54ccccda-0465-457a-be03-203aedd3d2b4", "is_active": true, "payload": {"applies_to_roles": ["promotor", "constructor", "tecnico", "admin"], "response": {"text": "Reforma integral piso Marta Vega — Madrid. 80.000 € total, 6 hitos, escrow Mangopay activo. Partes: Marta (promotor), Jorge Almazán (técnico aparejador), Construcciones Pérez SL.\n\nProgreso: 2 hitos cerrados (22.000 € liberados), 1 hito en certificación (12.000 €, con 2 hallazgos a revisar), 3 hitos pendientes.\n\nFirmado el 18/06, fondos depositados el 22/06. Sin disputas abiertas. Cierre estimado en diciembre 2026.\n\n¿Quieres que te genere el PDF descargable con el detalle?"}, "tool_call_proposed": {"input": {"format": "pdf_exec_summary"}, "name": "summarize_pact"}, "trigger_keywords": ["resumen", "resúmeme", "resumeme", "resumen ejecutivo", "dame el resumen", "pdf del pacto", "dame un resumen"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: coste IA (solo admin)", "fixture_key": "intent_coste_ia", "fixture_type": "assistant_intent", "id": "5bf2afee-7a95-44bd-bc7f-d69d34826a78", "is_active": true, "payload": {"applies_to_roles": ["admin"], "response": {"text": "Coste medio por dictamen Vision en obras tipo (10 fotos + 1 factura): 0,09 - 0,12 €. Coste por turno del asistente: 0,01 - 0,02 €. En este pacto llevamos gastados 0,21 € en total de IA. El modelo de costes queda muy holgado respecto a la comisión escrow del 1,8 %."}, "trigger_keywords": ["cuanto cuesta la ia", "cuánto cuesta la ia", "coste ia", "que cuesta esto", "qué cuesta esto"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: saludo", "fixture_key": "intent_saludo", "fixture_type": "assistant_intent", "id": "048b3b33-cacb-45a5-ba66-6b8fd850b8b9", "is_active": true, "payload": {"applies_to_roles": ["promotor", "constructor", "tecnico", "admin"], "response": {"text": "Hola. Soy Pact, el asistente de PactStream para este pacto. Puedo explicarte el estado, los hitos, lo que detecta la IA en las evidencias o ayudarte a tomar acciones (pedir evidencia, objetar, generar resumen). ¿Por dónde empezamos?"}, "trigger_keywords": ["hola", "buenas", "buenos dias", "buenos días", "que tal", "qué tal"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Intent: legal · guardrail derivar a soporte", "fixture_key": "intent_legal_fuera_alcance", "fixture_type": "assistant_intent", "id": "de2487ef-a649-4e59-86ab-cff1442cdf24", "is_active": true, "payload": {"applies_to_roles": ["promotor", "constructor", "tecnico", "admin"], "response": {"text": "Para temas legales prefiero no responder por mí mismo — depende de tu contrato, jurisdicción y circunstancias. Te puedo abrir un ticket con soporte humano de PactStream y adjuntar el contexto del pacto si quieres."}, "trigger_keywords": ["es legal", "esto es legal", "puedo demandar", "denunciar", "abogado", "tribunal", "juicio"]}, "updated_at": "2026-05-26T11:28:44.238173+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 1 vinculada por milestone_id", "fixture_key": "vision_00000000-0000-0000-0000-00000000ee01_ok", "fixture_type": "vision", "id": "5a780567-30a0-40b1-bdb6-b3dada73a4a6", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Desmontaje sanitario y mobiliario"}, {"evidence_ok": true, "task_id": "t2", "title": "Picado de azulejos en baño y cocina"}, {"evidence_ok": true, "task_id": "t3", "title": "Retirada de escombros a punto limpio"}], "demo_simulated_latency_ms": 9300, "findings": [], "recommendation": "Hito listo para firmar. Las evidencias son completas y coherentes.", "score": 92, "summary": "Las 3 fotos documentan correctamente la demolición de baño y cocina y la salida de escombros. La factura del punto limpio coincide con el alcance del hito.", "verdict": "ok"}, "updated_at": "2026-05-22T18:57:25.27415+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 2 vinculada por milestone_id", "fixture_key": "vision_00000000-0000-0000-0000-00000000ee02_ok", "fixture_type": "vision", "id": "a0d43552-da8a-4412-b8cd-af49779d98e0", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Tabiques pladur dormitorio principal"}, {"evidence_ok": true, "task_id": "t2", "title": "Apertura hueco salón-cocina"}, {"evidence_ok": true, "task_id": "t3", "title": "Refuerzo dintel"}], "demo_simulated_latency_ms": 10800, "findings": [{"evidence_ref": "evidences/m2/photo_02.jpg", "id": "f1", "message": "La foto muestra el hueco abierto pero no permite verificar el solape de la viga sobre el muro. Sugerimos guardar el plano de detalle como evidencia adicional para el Libro del Edificio.", "severity": "green", "type": "photo"}], "recommendation": "Hito listo para firmar. La nota sobre el plano de detalle es opcional, no bloqueante.", "score": 88, "summary": "Tabiquería y apertura de hueco salón-cocina ejecutadas según plano. Refuerzo del dintel visible y correctamente armado.", "verdict": "ok"}, "updated_at": "2026-05-22T18:57:25.27415+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 3 review vinculada por milestone_id", "fixture_key": "vision_00000000-0000-0000-0000-00000000ee03_review", "fixture_type": "vision", "id": "7ae784d4-91b8-4c46-939e-ebed5409af6c", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": true, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": false, "note": "No se observa foto del estado tras limpieza.", "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 12400, "findings": [{"evidence_ref": "evidences/m3/photo_03.jpg", "id": "f1", "message": "La foto 03 muestra parcialmente otra estancia (parece pasillo). El alcance del hito es solado del salón. Verifica que la imagen corresponde al área certificada o reemplázala por una vista clara del salón.", "severity": "amber", "type": "photo"}, {"evidence_ref": "evidences/m3/invoice_b.pdf", "id": "f2", "message": "La factura invoice_b.pdf describe instalación sanitaria (1.240 € — Fontanería del Sur SL), no solado. Además el emisor no coincide con la constructora del pacto (Construcciones Pérez SL). No procede adjuntarla a este hito.", "severity": "red", "type": "invoice"}], "recommendation": "Sustituye invoice_b.pdf por la factura correcta del solado emitida por Construcciones Pérez SL. Reemplaza o complementa la foto 03 con una vista clara del salón. Añade una foto post-limpieza. El resto del hito es correcto y puede firmarse una vez resueltos los hallazgos.", "score": 78, "summary": "Las 6 fotos documentan el solado del salón con buena cobertura del proceso (replanteo, pegado, rejuntado, vista final). Detectamos una foto parcialmente ambigua y una factura que no encaja con este hito.", "verdict": "review_needed"}, "updated_at": "2026-05-22T18:57:25.27415+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 3 ok vinculada por milestone_id", "fixture_key": "vision_00000000-0000-0000-0000-00000000ee03_ok", "fixture_type": "vision", "id": "708795a4-c3a0-44b0-89df-7c228ec124a4", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": true, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": true, "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 11200, "findings": [], "recommendation": "Hito listo para firmar. Sin objeciones.", "score": 91, "summary": "Las 6 fotos y la factura del hito Solado salón están completas y coherentes. Emisor de la factura coincide con Construcciones Pérez SL, importe dentro del presupuesto del hito (12.000 €).", "verdict": "ok"}, "updated_at": "2026-05-22T18:57:25.27415+00:00"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "description": "Demo · Hito 3 block vinculada por milestone_id", "fixture_key": "vision_00000000-0000-0000-0000-00000000ee03_block", "fixture_type": "vision", "id": "a6ba7687-9659-43e9-8f90-f88990724581", "is_active": true, "payload": {"checklist_match": [{"evidence_ok": true, "task_id": "t1", "title": "Replanteo y nivelación"}, {"evidence_ok": false, "task_id": "t2", "title": "Pegado y rejuntado"}, {"evidence_ok": false, "task_id": "t3", "title": "Limpieza final"}], "demo_simulated_latency_ms": 13700, "findings": [{"evidence_ref": "evidences/m3/photo_03.jpg", "id": "f1", "message": "Las fotos 03 y 04 parecen la misma imagen con ligera variación de ángulo. No constituyen evidencia adicional del proceso.", "severity": "red", "type": "photo"}, {"evidence_ref": "evidences/m3/invoice_b.pdf", "id": "f2", "message": "Factura emitida por Fontanería del Sur SL, no por la constructora del pacto. No procede para este hito.", "severity": "red", "type": "invoice"}, {"id": "f3", "message": "No hay ninguna foto que documente la limpieza final del solado, tarea explícita del checklist.", "severity": "red", "type": "checklist"}], "recommendation": "No procede firmar la certificación hasta sustituir la factura, eliminar la foto duplicada y aportar evidencia de la limpieza final.", "score": 42, "summary": "Las evidencias subidas son insuficientes y presentan inconsistencias graves: dos fotos del checklist están duplicadas y la factura corresponde a otro hito.", "verdict": "block"}, "updated_at": "2026-05-22T18:57:25.27415+00:00"}]$cfg$::jsonb)
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_prompts
SELECT * FROM jsonb_populate_recordset(NULL::public.ai_prompts, $cfg$[{"created_at": "2026-05-22T18:57:25.27415+00:00", "created_by_user_id": null, "id": "6bb98be2-887f-4c66-8a12-6dfc26f5be1a", "is_active": true, "notes": "Prompt inicial v1 · activo desde Sprint 7", "prompt_key": "assistant", "schema": {"properties": {"text": {"type": "string"}, "tool_call": {"properties": {"input": {"type": "object"}, "name": {"type": "string"}}, "type": "object"}}, "type": "object"}, "system_prompt": "Eres Pact, el asistente de PactStream. Solo hablas del pacto cuya\r\ninformación recibes en CONTEXT_BLOCK. Tono profesional, cercano, sin emojis,\r\nen español de España (es-ES).\r\n\r\nREGLAS DURAS\r\n1. Nunca des información sobre pactos distintos al actual.\r\n2. Nunca prometas una liberación de fondos. Solo explicas el estado y los\r\n   siguientes pasos posibles.\r\n3. Si te piden algo legal/fiscal complejo, deriva a soporte humano.\r\n4. Si la pregunta requiere una acción (objetar, pedir evidencia, resumen),\r\n   propón la acción usando la tool correspondiente y espera la confirmación\r\n   del usuario antes de ejecutar.\r\n5. Si no sabes algo, dilo. No inventes nombres, importes ni fechas.\r\n\r\nFORMATO\r\n- Respuestas de 3-6 líneas máx. salvo que pidan un resumen.\r\n- Cuando cites una certificación, usa \"Hito {N} · {nombre}\".\r\n- Cuando cites un importe, usa formato EUR con separador miles.\r\n- Si propones una acción, finaliza con un bloque [ACCION:tool_name].\r\n\r\nTOOLS DISPONIBLES\r\n- request_evidence(milestone_id, items[]) — pedir evidencia faltante a la otra parte\r\n- raise_objection(milestone_id, reason)   — objetar una certificación (solo promotor)\r\n- summarize_pact()                         — generar resumen ejecutivo del pacto\r\n- explain_verification(milestone_id)       — explicar dictamen Vision en lenguaje natural", "version": "v1"}, {"created_at": "2026-05-22T18:57:25.27415+00:00", "created_by_user_id": null, "id": "02bfb1b5-f449-49f3-b338-ac4c4dc77126", "is_active": true, "notes": "Prompt inicial v1 · activo desde Sprint 7", "prompt_key": "vision", "schema": {"properties": {"checklist_match": {"type": "array"}, "findings": {"type": "array"}, "recommendation": {"type": "string"}, "score": {"maximum": 100, "minimum": 0, "type": "integer"}, "summary": {"type": "string"}, "verdict": {"enum": ["ok", "review_needed", "block"]}}, "required": ["score", "verdict", "summary", "findings", "checklist_match", "recommendation"], "type": "object"}, "system_prompt": "Eres un asistente de PactStream especializado en certificación de obra\r\nresidencial en España. Tu trabajo NO es decidir si liberar fondos. Recibes:\r\n  - La definición de la certificación (nombre, descripción, checklist).\r\n  - Las evidencias subidas (fotos + documentos adjuntos incluyendo factura).\r\n  - El alcance del pacto (presupuesto total, partes, hitos anteriores).\r\n\r\nComprueba:\r\n  1. Que cada evidencia (foto/documento) corresponde al hito descrito.\r\n  2. Coherencia básica: el emisor de la factura coincide con la constructora\r\n     del pacto, el importe no supera el importe del hito, la fecha es plausible.\r\n  3. Si faltan evidencias del checklist o hay duplicados que no aportan valor.\r\n\r\nResponde SIEMPRE en JSON válido conforme al esquema dictum_schema_v1. Nunca\r\ninventes hallazgos. Si no hay evidencia para una tarea del checklist, dilo\r\nexplícitamente. Tono profesional, breve, en español de España.\r\n\r\nSeveridades:\r\n  - green: la evidencia es correcta, sin observaciones.\r\n  - amber: hay algo que el técnico debería revisar pero no es bloqueante.\r\n  - red:   incoherencia clara que debe corregirse antes de firmar.\r\n\r\nVerdict:\r\n  - ok            (score >= 80, ningún red).\r\n  - review_needed (60-79 o algún amber).\r\n  - block         (< 60 o cualquier red).\r\n\r\nRecuerda: tú asistes al técnico director de obra; él toma la decisión final.", "version": "v1"}]$cfg$::jsonb)
ON CONFLICT DO NOTHING;

INSERT INTO public.app_settings
SELECT * FROM jsonb_populate_recordset(NULL::public.app_settings, $cfg$[{"description": "Multiplicador de latencia simulada en demo.", "key": "ai_demo_latency_mult", "updated_at": "2026-05-22T18:11:56.383871+00:00", "updated_by_user_id": null, "value": 1}, {"description": "review | ok | block · Variante del Hito 3 demo.", "key": "ai_demo_variant_m3", "updated_at": "2026-05-22T18:11:56.383871+00:00", "updated_by_user_id": null, "value": "review"}, {"description": "Array auth_provider_id que fuerzan live.", "key": "ai_live_for_user_uids", "updated_at": "2026-05-22T18:11:56.383871+00:00", "updated_by_user_id": null, "value": []}, {"description": "Kill switch coste/día en euros.", "key": "ai_max_cost_eur_day", "updated_at": "2026-05-22T18:11:56.383871+00:00", "updated_by_user_id": null, "value": 5}, {"description": "Tope de gasto IA acumulado en el mes natural (EUR). Si SUM(cost_cents) del mes supera este valor, el gateway fuerza demo. 0 = sin tope mensual. Fijado a 20 en fase de pruebas (22-jul-2026); revisar antes del lanzamiento publico.", "key": "ai_max_cost_eur_month", "updated_at": "2026-07-22T15:03:51.989408+00:00", "updated_by_user_id": null, "value": 20}, {"description": "demo | live · Modo global del gateway IA.", "key": "ai_provider", "updated_at": "2026-07-22T15:00:05.412793+00:00", "updated_by_user_id": null, "value": "live"}, {"description": "Streaming SSE token a token.", "key": "ai_streaming_enabled", "updated_at": "2026-05-22T18:11:56.383871+00:00", "updated_by_user_id": null, "value": true}, {"description": null, "key": "dispute_escrow_max_cents", "updated_at": "2026-06-11T16:09:10.963916+00:00", "updated_by_user_id": null, "value": 500000}, {"description": null, "key": "dispute_escrow_min_cents", "updated_at": "2026-06-11T16:09:10.963916+00:00", "updated_by_user_id": null, "value": 50000}, {"description": null, "key": "dispute_escrow_pct", "updated_at": "2026-06-11T16:09:10.963916+00:00", "updated_by_user_id": null, "value": 10}, {"description": null, "key": "quality_grace_period_days", "updated_at": "2026-06-11T16:09:10.6884+00:00", "updated_by_user_id": null, "value": 14}, {"description": null, "key": "quality_holdback_pct", "updated_at": "2026-06-11T16:09:10.6884+00:00", "updated_by_user_id": null, "value": 15}, {"description": null, "key": "quality_holdback_threshold", "updated_at": "2026-06-11T16:09:10.6884+00:00", "updated_by_user_id": null, "value": 75}, {"description": null, "key": "quality_release_threshold", "updated_at": "2026-06-11T16:09:10.6884+00:00", "updated_by_user_id": null, "value": 70}]$cfg$::jsonb)
ON CONFLICT DO NOTHING;

INSERT INTO public.ipc_indices
SELECT * FROM jsonb_populate_recordset(NULL::public.ipc_indices, $cfg$[{"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "8238dc0e-4631-468d-aab6-871f22099671", "index_value": 112.876, "published_at": null, "source": "INE", "variation_annual_pct": 3.4, "variation_monthly_pct": null, "year_month": "2025-06"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "7c2d43be-876d-4d26-b94c-5fd51d5fbb98", "index_value": 112.54, "published_at": null, "source": "INE", "variation_annual_pct": 2.8, "variation_monthly_pct": null, "year_month": "2025-07"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "11780818-2909-45db-a2a2-78decf586965", "index_value": 112.332, "published_at": null, "source": "INE", "variation_annual_pct": 2.4, "variation_monthly_pct": null, "year_month": "2025-08"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "ceb037e5-c68e-41b2-9bad-1856590f4028", "index_value": 112.754, "published_at": null, "source": "INE", "variation_annual_pct": 2.6, "variation_monthly_pct": null, "year_month": "2025-09"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "e385a10d-2664-4de4-82a9-1031879e7188", "index_value": 113.21, "published_at": null, "source": "INE", "variation_annual_pct": 2.9, "variation_monthly_pct": null, "year_month": "2025-10"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "c4fd123b-9b8f-436a-9dc4-6c776ecb347b", "index_value": 113.456, "published_at": null, "source": "INE", "variation_annual_pct": 2.7, "variation_monthly_pct": null, "year_month": "2025-11"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "38aee048-0970-4ad6-af02-1efbc6d20897", "index_value": 113.89, "published_at": null, "source": "INE", "variation_annual_pct": 2.5, "variation_monthly_pct": null, "year_month": "2025-12"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "ec7da166-982e-4034-9edf-b7679d585f60", "index_value": 113.12, "published_at": null, "source": "INE", "variation_annual_pct": 2.2, "variation_monthly_pct": null, "year_month": "2026-01"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "c0c91bb4-2540-49a0-a4e2-755a9ca8e84d", "index_value": 113.34, "published_at": null, "source": "INE", "variation_annual_pct": 2.3, "variation_monthly_pct": null, "year_month": "2026-02"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "0e300999-aebe-46e7-8152-584bdd748362", "index_value": 113.78, "published_at": null, "source": "INE", "variation_annual_pct": 2.5, "variation_monthly_pct": null, "year_month": "2026-03"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "b36f063f-8f25-402d-a1b6-ede1eeec7b60", "index_value": 114.12, "published_at": null, "source": "INE", "variation_annual_pct": 2.8, "variation_monthly_pct": null, "year_month": "2026-04"}, {"created_at": "2026-06-11T16:09:11.058314+00:00", "id": "8a9c10da-d3fa-4fb2-86d2-80c0babfff54", "index_value": 114.45, "published_at": null, "source": "INE", "variation_annual_pct": 3, "variation_monthly_pct": null, "year_month": "2026-05"}]$cfg$::jsonb)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 4 · Permisos como en dev (generado con `supabase db diff --linked` contra
--     una base construida con las secciones 1-3)
-- =====================================================================
-- Supabase concede por defecto todo a anon/authenticated/service_role en
-- tablas nuevas; dev los tiene recortados (grant hardening). Se recortan igual.
revoke delete on table "public"."acopio_items" from "anon";
revoke insert on table "public"."acopio_items" from "anon";
revoke references on table "public"."acopio_items" from "anon";
revoke select on table "public"."acopio_items" from "anon";
revoke trigger on table "public"."acopio_items" from "anon";
revoke truncate on table "public"."acopio_items" from "anon";
revoke update on table "public"."acopio_items" from "anon";
revoke references on table "public"."acopio_items" from "authenticated";
revoke trigger on table "public"."acopio_items" from "authenticated";
revoke truncate on table "public"."acopio_items" from "authenticated";
revoke references on table "public"."acopio_items" from "service_role";
revoke trigger on table "public"."acopio_items" from "service_role";
revoke truncate on table "public"."acopio_items" from "service_role";
revoke delete on table "public"."ai_assistant_messages" from "anon";
revoke insert on table "public"."ai_assistant_messages" from "anon";
revoke references on table "public"."ai_assistant_messages" from "anon";
revoke select on table "public"."ai_assistant_messages" from "anon";
revoke trigger on table "public"."ai_assistant_messages" from "anon";
revoke truncate on table "public"."ai_assistant_messages" from "anon";
revoke update on table "public"."ai_assistant_messages" from "anon";
revoke references on table "public"."ai_assistant_messages" from "authenticated";
revoke trigger on table "public"."ai_assistant_messages" from "authenticated";
revoke truncate on table "public"."ai_assistant_messages" from "authenticated";
revoke references on table "public"."ai_assistant_messages" from "service_role";
revoke trigger on table "public"."ai_assistant_messages" from "service_role";
revoke truncate on table "public"."ai_assistant_messages" from "service_role";
revoke delete on table "public"."ai_fixtures" from "anon";
revoke insert on table "public"."ai_fixtures" from "anon";
revoke references on table "public"."ai_fixtures" from "anon";
revoke select on table "public"."ai_fixtures" from "anon";
revoke trigger on table "public"."ai_fixtures" from "anon";
revoke truncate on table "public"."ai_fixtures" from "anon";
revoke update on table "public"."ai_fixtures" from "anon";
revoke references on table "public"."ai_fixtures" from "authenticated";
revoke trigger on table "public"."ai_fixtures" from "authenticated";
revoke truncate on table "public"."ai_fixtures" from "authenticated";
revoke references on table "public"."ai_fixtures" from "service_role";
revoke trigger on table "public"."ai_fixtures" from "service_role";
revoke truncate on table "public"."ai_fixtures" from "service_role";
revoke delete on table "public"."ai_prompts" from "anon";
revoke insert on table "public"."ai_prompts" from "anon";
revoke references on table "public"."ai_prompts" from "anon";
revoke select on table "public"."ai_prompts" from "anon";
revoke trigger on table "public"."ai_prompts" from "anon";
revoke truncate on table "public"."ai_prompts" from "anon";
revoke update on table "public"."ai_prompts" from "anon";
revoke delete on table "public"."ai_prompts" from "authenticated";
revoke insert on table "public"."ai_prompts" from "authenticated";
revoke references on table "public"."ai_prompts" from "authenticated";
revoke select on table "public"."ai_prompts" from "authenticated";
revoke trigger on table "public"."ai_prompts" from "authenticated";
revoke truncate on table "public"."ai_prompts" from "authenticated";
revoke update on table "public"."ai_prompts" from "authenticated";
revoke references on table "public"."ai_prompts" from "service_role";
revoke trigger on table "public"."ai_prompts" from "service_role";
revoke truncate on table "public"."ai_prompts" from "service_role";
revoke delete on table "public"."ai_runs" from "anon";
revoke insert on table "public"."ai_runs" from "anon";
revoke references on table "public"."ai_runs" from "anon";
revoke select on table "public"."ai_runs" from "anon";
revoke trigger on table "public"."ai_runs" from "anon";
revoke truncate on table "public"."ai_runs" from "anon";
revoke update on table "public"."ai_runs" from "anon";
revoke references on table "public"."ai_runs" from "authenticated";
revoke trigger on table "public"."ai_runs" from "authenticated";
revoke truncate on table "public"."ai_runs" from "authenticated";
revoke references on table "public"."ai_runs" from "service_role";
revoke trigger on table "public"."ai_runs" from "service_role";
revoke truncate on table "public"."ai_runs" from "service_role";
revoke delete on table "public"."api_key_usage" from "anon";
revoke insert on table "public"."api_key_usage" from "anon";
revoke references on table "public"."api_key_usage" from "anon";
revoke select on table "public"."api_key_usage" from "anon";
revoke trigger on table "public"."api_key_usage" from "anon";
revoke truncate on table "public"."api_key_usage" from "anon";
revoke update on table "public"."api_key_usage" from "anon";
revoke references on table "public"."api_key_usage" from "authenticated";
revoke trigger on table "public"."api_key_usage" from "authenticated";
revoke truncate on table "public"."api_key_usage" from "authenticated";
revoke references on table "public"."api_key_usage" from "service_role";
revoke trigger on table "public"."api_key_usage" from "service_role";
revoke truncate on table "public"."api_key_usage" from "service_role";
revoke delete on table "public"."api_keys" from "anon";
revoke insert on table "public"."api_keys" from "anon";
revoke references on table "public"."api_keys" from "anon";
revoke select on table "public"."api_keys" from "anon";
revoke trigger on table "public"."api_keys" from "anon";
revoke truncate on table "public"."api_keys" from "anon";
revoke update on table "public"."api_keys" from "anon";
revoke references on table "public"."api_keys" from "authenticated";
revoke trigger on table "public"."api_keys" from "authenticated";
revoke truncate on table "public"."api_keys" from "authenticated";
revoke references on table "public"."api_keys" from "service_role";
revoke trigger on table "public"."api_keys" from "service_role";
revoke truncate on table "public"."api_keys" from "service_role";
revoke delete on table "public"."app_settings" from "anon";
revoke insert on table "public"."app_settings" from "anon";
revoke references on table "public"."app_settings" from "anon";
revoke select on table "public"."app_settings" from "anon";
revoke trigger on table "public"."app_settings" from "anon";
revoke truncate on table "public"."app_settings" from "anon";
revoke update on table "public"."app_settings" from "anon";
revoke references on table "public"."app_settings" from "authenticated";
revoke trigger on table "public"."app_settings" from "authenticated";
revoke truncate on table "public"."app_settings" from "authenticated";
revoke references on table "public"."app_settings" from "service_role";
revoke trigger on table "public"."app_settings" from "service_role";
revoke truncate on table "public"."app_settings" from "service_role";
revoke delete on table "public"."audit_log" from "anon";
revoke insert on table "public"."audit_log" from "anon";
revoke references on table "public"."audit_log" from "anon";
revoke trigger on table "public"."audit_log" from "anon";
revoke truncate on table "public"."audit_log" from "anon";
revoke update on table "public"."audit_log" from "anon";
revoke delete on table "public"."audit_log" from "authenticated";
revoke insert on table "public"."audit_log" from "authenticated";
revoke references on table "public"."audit_log" from "authenticated";
revoke trigger on table "public"."audit_log" from "authenticated";
revoke truncate on table "public"."audit_log" from "authenticated";
revoke update on table "public"."audit_log" from "authenticated";
revoke references on table "public"."audit_log" from "service_role";
revoke trigger on table "public"."audit_log" from "service_role";
revoke truncate on table "public"."audit_log" from "service_role";
revoke delete on table "public"."cae_enlaces_cliente" from "anon";
revoke insert on table "public"."cae_enlaces_cliente" from "anon";
revoke references on table "public"."cae_enlaces_cliente" from "anon";
revoke select on table "public"."cae_enlaces_cliente" from "anon";
revoke trigger on table "public"."cae_enlaces_cliente" from "anon";
revoke truncate on table "public"."cae_enlaces_cliente" from "anon";
revoke update on table "public"."cae_enlaces_cliente" from "anon";
revoke references on table "public"."cae_enlaces_cliente" from "authenticated";
revoke trigger on table "public"."cae_enlaces_cliente" from "authenticated";
revoke truncate on table "public"."cae_enlaces_cliente" from "authenticated";
revoke references on table "public"."cae_enlaces_cliente" from "service_role";
revoke trigger on table "public"."cae_enlaces_cliente" from "service_role";
revoke truncate on table "public"."cae_enlaces_cliente" from "service_role";
revoke delete on table "public"."cae_expedientes" from "anon";
revoke insert on table "public"."cae_expedientes" from "anon";
revoke references on table "public"."cae_expedientes" from "anon";
revoke select on table "public"."cae_expedientes" from "anon";
revoke trigger on table "public"."cae_expedientes" from "anon";
revoke truncate on table "public"."cae_expedientes" from "anon";
revoke update on table "public"."cae_expedientes" from "anon";
revoke references on table "public"."cae_expedientes" from "authenticated";
revoke trigger on table "public"."cae_expedientes" from "authenticated";
revoke truncate on table "public"."cae_expedientes" from "authenticated";
revoke references on table "public"."cae_expedientes" from "service_role";
revoke trigger on table "public"."cae_expedientes" from "service_role";
revoke truncate on table "public"."cae_expedientes" from "service_role";
revoke delete on table "public"."cae_lotes" from "anon";
revoke insert on table "public"."cae_lotes" from "anon";
revoke references on table "public"."cae_lotes" from "anon";
revoke select on table "public"."cae_lotes" from "anon";
revoke trigger on table "public"."cae_lotes" from "anon";
revoke truncate on table "public"."cae_lotes" from "anon";
revoke update on table "public"."cae_lotes" from "anon";
revoke references on table "public"."cae_lotes" from "authenticated";
revoke trigger on table "public"."cae_lotes" from "authenticated";
revoke truncate on table "public"."cae_lotes" from "authenticated";
revoke references on table "public"."cae_lotes" from "service_role";
revoke trigger on table "public"."cae_lotes" from "service_role";
revoke truncate on table "public"."cae_lotes" from "service_role";
revoke delete on table "public"."cae_requisitos" from "anon";
revoke insert on table "public"."cae_requisitos" from "anon";
revoke references on table "public"."cae_requisitos" from "anon";
revoke select on table "public"."cae_requisitos" from "anon";
revoke trigger on table "public"."cae_requisitos" from "anon";
revoke truncate on table "public"."cae_requisitos" from "anon";
revoke update on table "public"."cae_requisitos" from "anon";
revoke references on table "public"."cae_requisitos" from "authenticated";
revoke trigger on table "public"."cae_requisitos" from "authenticated";
revoke truncate on table "public"."cae_requisitos" from "authenticated";
revoke references on table "public"."cae_requisitos" from "service_role";
revoke trigger on table "public"."cae_requisitos" from "service_role";
revoke truncate on table "public"."cae_requisitos" from "service_role";
revoke delete on table "public"."conversations" from "anon";
revoke insert on table "public"."conversations" from "anon";
revoke references on table "public"."conversations" from "anon";
revoke trigger on table "public"."conversations" from "anon";
revoke truncate on table "public"."conversations" from "anon";
revoke update on table "public"."conversations" from "anon";
revoke references on table "public"."conversations" from "authenticated";
revoke trigger on table "public"."conversations" from "authenticated";
revoke truncate on table "public"."conversations" from "authenticated";
revoke references on table "public"."conversations" from "service_role";
revoke trigger on table "public"."conversations" from "service_role";
revoke truncate on table "public"."conversations" from "service_role";
revoke delete on table "public"."deposit_movements" from "anon";
revoke insert on table "public"."deposit_movements" from "anon";
revoke references on table "public"."deposit_movements" from "anon";
revoke select on table "public"."deposit_movements" from "anon";
revoke trigger on table "public"."deposit_movements" from "anon";
revoke truncate on table "public"."deposit_movements" from "anon";
revoke update on table "public"."deposit_movements" from "anon";
revoke delete on table "public"."deposit_movements" from "authenticated";
revoke references on table "public"."deposit_movements" from "authenticated";
revoke trigger on table "public"."deposit_movements" from "authenticated";
revoke truncate on table "public"."deposit_movements" from "authenticated";
revoke update on table "public"."deposit_movements" from "authenticated";
revoke references on table "public"."deposit_movements" from "service_role";
revoke trigger on table "public"."deposit_movements" from "service_role";
revoke truncate on table "public"."deposit_movements" from "service_role";
revoke delete on table "public"."dispute_contributions" from "anon";
revoke insert on table "public"."dispute_contributions" from "anon";
revoke references on table "public"."dispute_contributions" from "anon";
revoke trigger on table "public"."dispute_contributions" from "anon";
revoke truncate on table "public"."dispute_contributions" from "anon";
revoke update on table "public"."dispute_contributions" from "anon";
revoke references on table "public"."dispute_contributions" from "authenticated";
revoke trigger on table "public"."dispute_contributions" from "authenticated";
revoke truncate on table "public"."dispute_contributions" from "authenticated";
revoke references on table "public"."dispute_contributions" from "service_role";
revoke trigger on table "public"."dispute_contributions" from "service_role";
revoke truncate on table "public"."dispute_contributions" from "service_role";
revoke delete on table "public"."dispute_escrows" from "anon";
revoke insert on table "public"."dispute_escrows" from "anon";
revoke references on table "public"."dispute_escrows" from "anon";
revoke select on table "public"."dispute_escrows" from "anon";
revoke trigger on table "public"."dispute_escrows" from "anon";
revoke truncate on table "public"."dispute_escrows" from "anon";
revoke update on table "public"."dispute_escrows" from "anon";
revoke references on table "public"."dispute_escrows" from "authenticated";
revoke trigger on table "public"."dispute_escrows" from "authenticated";
revoke truncate on table "public"."dispute_escrows" from "authenticated";
revoke references on table "public"."dispute_escrows" from "service_role";
revoke trigger on table "public"."dispute_escrows" from "service_role";
revoke truncate on table "public"."dispute_escrows" from "service_role";
revoke delete on table "public"."disputes" from "anon";
revoke insert on table "public"."disputes" from "anon";
revoke references on table "public"."disputes" from "anon";
revoke trigger on table "public"."disputes" from "anon";
revoke truncate on table "public"."disputes" from "anon";
revoke update on table "public"."disputes" from "anon";
revoke references on table "public"."disputes" from "authenticated";
revoke trigger on table "public"."disputes" from "authenticated";
revoke truncate on table "public"."disputes" from "authenticated";
revoke references on table "public"."disputes" from "service_role";
revoke trigger on table "public"."disputes" from "service_role";
revoke truncate on table "public"."disputes" from "service_role";
revoke delete on table "public"."documents" from "anon";
revoke insert on table "public"."documents" from "anon";
revoke references on table "public"."documents" from "anon";
revoke trigger on table "public"."documents" from "anon";
revoke truncate on table "public"."documents" from "anon";
revoke update on table "public"."documents" from "anon";
revoke references on table "public"."documents" from "authenticated";
revoke trigger on table "public"."documents" from "authenticated";
revoke truncate on table "public"."documents" from "authenticated";
revoke references on table "public"."documents" from "service_role";
revoke trigger on table "public"."documents" from "service_role";
revoke truncate on table "public"."documents" from "service_role";
revoke delete on table "public"."ipc_indices" from "anon";
revoke insert on table "public"."ipc_indices" from "anon";
revoke references on table "public"."ipc_indices" from "anon";
revoke select on table "public"."ipc_indices" from "anon";
revoke trigger on table "public"."ipc_indices" from "anon";
revoke truncate on table "public"."ipc_indices" from "anon";
revoke update on table "public"."ipc_indices" from "anon";
revoke references on table "public"."ipc_indices" from "authenticated";
revoke trigger on table "public"."ipc_indices" from "authenticated";
revoke truncate on table "public"."ipc_indices" from "authenticated";
revoke references on table "public"."ipc_indices" from "service_role";
revoke trigger on table "public"."ipc_indices" from "service_role";
revoke truncate on table "public"."ipc_indices" from "service_role";
revoke delete on table "public"."legal_consents" from "anon";
revoke insert on table "public"."legal_consents" from "anon";
revoke references on table "public"."legal_consents" from "anon";
revoke trigger on table "public"."legal_consents" from "anon";
revoke truncate on table "public"."legal_consents" from "anon";
revoke update on table "public"."legal_consents" from "anon";
revoke references on table "public"."legal_consents" from "authenticated";
revoke trigger on table "public"."legal_consents" from "authenticated";
revoke truncate on table "public"."legal_consents" from "authenticated";
revoke references on table "public"."legal_consents" from "service_role";
revoke trigger on table "public"."legal_consents" from "service_role";
revoke truncate on table "public"."legal_consents" from "service_role";
revoke delete on table "public"."messages" from "anon";
revoke insert on table "public"."messages" from "anon";
revoke references on table "public"."messages" from "anon";
revoke trigger on table "public"."messages" from "anon";
revoke truncate on table "public"."messages" from "anon";
revoke update on table "public"."messages" from "anon";
revoke references on table "public"."messages" from "authenticated";
revoke trigger on table "public"."messages" from "authenticated";
revoke truncate on table "public"."messages" from "authenticated";
revoke references on table "public"."messages" from "service_role";
revoke trigger on table "public"."messages" from "service_role";
revoke truncate on table "public"."messages" from "service_role";
revoke delete on table "public"."milestone_ai_verifications" from "anon";
revoke insert on table "public"."milestone_ai_verifications" from "anon";
revoke references on table "public"."milestone_ai_verifications" from "anon";
revoke select on table "public"."milestone_ai_verifications" from "anon";
revoke trigger on table "public"."milestone_ai_verifications" from "anon";
revoke truncate on table "public"."milestone_ai_verifications" from "anon";
revoke update on table "public"."milestone_ai_verifications" from "anon";
revoke references on table "public"."milestone_ai_verifications" from "authenticated";
revoke trigger on table "public"."milestone_ai_verifications" from "authenticated";
revoke truncate on table "public"."milestone_ai_verifications" from "authenticated";
revoke references on table "public"."milestone_ai_verifications" from "service_role";
revoke trigger on table "public"."milestone_ai_verifications" from "service_role";
revoke truncate on table "public"."milestone_ai_verifications" from "service_role";
revoke delete on table "public"."milestone_evidences" from "anon";
revoke insert on table "public"."milestone_evidences" from "anon";
revoke references on table "public"."milestone_evidences" from "anon";
revoke trigger on table "public"."milestone_evidences" from "anon";
revoke truncate on table "public"."milestone_evidences" from "anon";
revoke update on table "public"."milestone_evidences" from "anon";
revoke references on table "public"."milestone_evidences" from "authenticated";
revoke trigger on table "public"."milestone_evidences" from "authenticated";
revoke truncate on table "public"."milestone_evidences" from "authenticated";
revoke references on table "public"."milestone_evidences" from "service_role";
revoke trigger on table "public"."milestone_evidences" from "service_role";
revoke truncate on table "public"."milestone_evidences" from "service_role";
revoke delete on table "public"."milestone_objections" from "anon";
revoke insert on table "public"."milestone_objections" from "anon";
revoke references on table "public"."milestone_objections" from "anon";
revoke trigger on table "public"."milestone_objections" from "anon";
revoke truncate on table "public"."milestone_objections" from "anon";
revoke update on table "public"."milestone_objections" from "anon";
revoke references on table "public"."milestone_objections" from "authenticated";
revoke trigger on table "public"."milestone_objections" from "authenticated";
revoke truncate on table "public"."milestone_objections" from "authenticated";
revoke references on table "public"."milestone_objections" from "service_role";
revoke trigger on table "public"."milestone_objections" from "service_role";
revoke truncate on table "public"."milestone_objections" from "service_role";
revoke delete on table "public"."milestone_state_transitions" from "anon";
revoke insert on table "public"."milestone_state_transitions" from "anon";
revoke references on table "public"."milestone_state_transitions" from "anon";
revoke trigger on table "public"."milestone_state_transitions" from "anon";
revoke truncate on table "public"."milestone_state_transitions" from "anon";
revoke update on table "public"."milestone_state_transitions" from "anon";
revoke delete on table "public"."milestone_state_transitions" from "authenticated";
revoke insert on table "public"."milestone_state_transitions" from "authenticated";
revoke references on table "public"."milestone_state_transitions" from "authenticated";
revoke trigger on table "public"."milestone_state_transitions" from "authenticated";
revoke truncate on table "public"."milestone_state_transitions" from "authenticated";
revoke update on table "public"."milestone_state_transitions" from "authenticated";
revoke references on table "public"."milestone_state_transitions" from "service_role";
revoke trigger on table "public"."milestone_state_transitions" from "service_role";
revoke truncate on table "public"."milestone_state_transitions" from "service_role";
revoke delete on table "public"."milestone_validations" from "anon";
revoke insert on table "public"."milestone_validations" from "anon";
revoke references on table "public"."milestone_validations" from "anon";
revoke trigger on table "public"."milestone_validations" from "anon";
revoke truncate on table "public"."milestone_validations" from "anon";
revoke update on table "public"."milestone_validations" from "anon";
revoke references on table "public"."milestone_validations" from "authenticated";
revoke trigger on table "public"."milestone_validations" from "authenticated";
revoke truncate on table "public"."milestone_validations" from "authenticated";
revoke references on table "public"."milestone_validations" from "service_role";
revoke trigger on table "public"."milestone_validations" from "service_role";
revoke truncate on table "public"."milestone_validations" from "service_role";
revoke delete on table "public"."milestones" from "anon";
revoke insert on table "public"."milestones" from "anon";
revoke references on table "public"."milestones" from "anon";
revoke trigger on table "public"."milestones" from "anon";
revoke truncate on table "public"."milestones" from "anon";
revoke update on table "public"."milestones" from "anon";
revoke references on table "public"."milestones" from "authenticated";
revoke trigger on table "public"."milestones" from "authenticated";
revoke truncate on table "public"."milestones" from "authenticated";
revoke references on table "public"."milestones" from "service_role";
revoke trigger on table "public"."milestones" from "service_role";
revoke truncate on table "public"."milestones" from "service_role";
revoke delete on table "public"."notifications" from "anon";
revoke insert on table "public"."notifications" from "anon";
revoke references on table "public"."notifications" from "anon";
revoke trigger on table "public"."notifications" from "anon";
revoke truncate on table "public"."notifications" from "anon";
revoke update on table "public"."notifications" from "anon";
revoke references on table "public"."notifications" from "authenticated";
revoke trigger on table "public"."notifications" from "authenticated";
revoke truncate on table "public"."notifications" from "authenticated";
revoke references on table "public"."notifications" from "service_role";
revoke trigger on table "public"."notifications" from "service_role";
revoke truncate on table "public"."notifications" from "service_role";
revoke delete on table "public"."organization_members" from "anon";
revoke insert on table "public"."organization_members" from "anon";
revoke references on table "public"."organization_members" from "anon";
revoke select on table "public"."organization_members" from "anon";
revoke trigger on table "public"."organization_members" from "anon";
revoke truncate on table "public"."organization_members" from "anon";
revoke update on table "public"."organization_members" from "anon";
revoke references on table "public"."organization_members" from "authenticated";
revoke trigger on table "public"."organization_members" from "authenticated";
revoke truncate on table "public"."organization_members" from "authenticated";
revoke references on table "public"."organization_members" from "service_role";
revoke trigger on table "public"."organization_members" from "service_role";
revoke truncate on table "public"."organization_members" from "service_role";
revoke delete on table "public"."organizations" from "anon";
revoke insert on table "public"."organizations" from "anon";
revoke references on table "public"."organizations" from "anon";
revoke trigger on table "public"."organizations" from "anon";
revoke truncate on table "public"."organizations" from "anon";
revoke update on table "public"."organizations" from "anon";
revoke references on table "public"."organizations" from "authenticated";
revoke trigger on table "public"."organizations" from "authenticated";
revoke truncate on table "public"."organizations" from "authenticated";
revoke references on table "public"."organizations" from "service_role";
revoke trigger on table "public"."organizations" from "service_role";
revoke truncate on table "public"."organizations" from "service_role";
revoke delete on table "public"."pact_addendums" from "anon";
revoke insert on table "public"."pact_addendums" from "anon";
revoke references on table "public"."pact_addendums" from "anon";
revoke select on table "public"."pact_addendums" from "anon";
revoke trigger on table "public"."pact_addendums" from "anon";
revoke truncate on table "public"."pact_addendums" from "anon";
revoke update on table "public"."pact_addendums" from "anon";
revoke references on table "public"."pact_addendums" from "authenticated";
revoke trigger on table "public"."pact_addendums" from "authenticated";
revoke truncate on table "public"."pact_addendums" from "authenticated";
revoke references on table "public"."pact_addendums" from "service_role";
revoke trigger on table "public"."pact_addendums" from "service_role";
revoke truncate on table "public"."pact_addendums" from "service_role";
revoke delete on table "public"."pact_events" from "anon";
revoke insert on table "public"."pact_events" from "anon";
revoke references on table "public"."pact_events" from "anon";
revoke trigger on table "public"."pact_events" from "anon";
revoke truncate on table "public"."pact_events" from "anon";
revoke update on table "public"."pact_events" from "anon";
revoke delete on table "public"."pact_events" from "authenticated";
revoke references on table "public"."pact_events" from "authenticated";
revoke trigger on table "public"."pact_events" from "authenticated";
revoke truncate on table "public"."pact_events" from "authenticated";
revoke update on table "public"."pact_events" from "authenticated";
revoke references on table "public"."pact_events" from "service_role";
revoke trigger on table "public"."pact_events" from "service_role";
revoke truncate on table "public"."pact_events" from "service_role";
revoke delete on table "public"."pact_health_scores" from "anon";
revoke insert on table "public"."pact_health_scores" from "anon";
revoke references on table "public"."pact_health_scores" from "anon";
revoke trigger on table "public"."pact_health_scores" from "anon";
revoke truncate on table "public"."pact_health_scores" from "anon";
revoke update on table "public"."pact_health_scores" from "anon";
revoke references on table "public"."pact_health_scores" from "authenticated";
revoke trigger on table "public"."pact_health_scores" from "authenticated";
revoke truncate on table "public"."pact_health_scores" from "authenticated";
revoke references on table "public"."pact_health_scores" from "service_role";
revoke trigger on table "public"."pact_health_scores" from "service_role";
revoke truncate on table "public"."pact_health_scores" from "service_role";
revoke delete on table "public"."pact_message_reads" from "anon";
revoke insert on table "public"."pact_message_reads" from "anon";
revoke references on table "public"."pact_message_reads" from "anon";
revoke select on table "public"."pact_message_reads" from "anon";
revoke trigger on table "public"."pact_message_reads" from "anon";
revoke truncate on table "public"."pact_message_reads" from "anon";
revoke update on table "public"."pact_message_reads" from "anon";
revoke references on table "public"."pact_message_reads" from "authenticated";
revoke trigger on table "public"."pact_message_reads" from "authenticated";
revoke truncate on table "public"."pact_message_reads" from "authenticated";
revoke references on table "public"."pact_message_reads" from "service_role";
revoke trigger on table "public"."pact_message_reads" from "service_role";
revoke truncate on table "public"."pact_message_reads" from "service_role";
revoke delete on table "public"."pact_messages" from "anon";
revoke insert on table "public"."pact_messages" from "anon";
revoke references on table "public"."pact_messages" from "anon";
revoke select on table "public"."pact_messages" from "anon";
revoke trigger on table "public"."pact_messages" from "anon";
revoke truncate on table "public"."pact_messages" from "anon";
revoke update on table "public"."pact_messages" from "anon";
revoke references on table "public"."pact_messages" from "authenticated";
revoke trigger on table "public"."pact_messages" from "authenticated";
revoke truncate on table "public"."pact_messages" from "authenticated";
revoke references on table "public"."pact_messages" from "service_role";
revoke trigger on table "public"."pact_messages" from "service_role";
revoke truncate on table "public"."pact_messages" from "service_role";
revoke delete on table "public"."pact_metadata" from "anon";
revoke insert on table "public"."pact_metadata" from "anon";
revoke references on table "public"."pact_metadata" from "anon";
revoke select on table "public"."pact_metadata" from "anon";
revoke trigger on table "public"."pact_metadata" from "anon";
revoke truncate on table "public"."pact_metadata" from "anon";
revoke update on table "public"."pact_metadata" from "anon";
revoke references on table "public"."pact_metadata" from "authenticated";
revoke trigger on table "public"."pact_metadata" from "authenticated";
revoke truncate on table "public"."pact_metadata" from "authenticated";
revoke references on table "public"."pact_metadata" from "service_role";
revoke trigger on table "public"."pact_metadata" from "service_role";
revoke truncate on table "public"."pact_metadata" from "service_role";
revoke delete on table "public"."pact_parties" from "anon";
revoke insert on table "public"."pact_parties" from "anon";
revoke references on table "public"."pact_parties" from "anon";
revoke trigger on table "public"."pact_parties" from "anon";
revoke truncate on table "public"."pact_parties" from "anon";
revoke update on table "public"."pact_parties" from "anon";
revoke references on table "public"."pact_parties" from "authenticated";
revoke trigger on table "public"."pact_parties" from "authenticated";
revoke truncate on table "public"."pact_parties" from "authenticated";
revoke references on table "public"."pact_parties" from "service_role";
revoke trigger on table "public"."pact_parties" from "service_role";
revoke truncate on table "public"."pact_parties" from "service_role";
revoke delete on table "public"."pact_plan_items" from "anon";
revoke insert on table "public"."pact_plan_items" from "anon";
revoke references on table "public"."pact_plan_items" from "anon";
revoke select on table "public"."pact_plan_items" from "anon";
revoke trigger on table "public"."pact_plan_items" from "anon";
revoke truncate on table "public"."pact_plan_items" from "anon";
revoke update on table "public"."pact_plan_items" from "anon";
revoke delete on table "public"."pact_plan_items" from "authenticated";
revoke insert on table "public"."pact_plan_items" from "authenticated";
revoke references on table "public"."pact_plan_items" from "authenticated";
revoke trigger on table "public"."pact_plan_items" from "authenticated";
revoke truncate on table "public"."pact_plan_items" from "authenticated";
revoke update on table "public"."pact_plan_items" from "authenticated";
revoke references on table "public"."pact_plan_items" from "service_role";
revoke trigger on table "public"."pact_plan_items" from "service_role";
revoke truncate on table "public"."pact_plan_items" from "service_role";
revoke delete on table "public"."pact_state_transitions" from "anon";
revoke insert on table "public"."pact_state_transitions" from "anon";
revoke references on table "public"."pact_state_transitions" from "anon";
revoke trigger on table "public"."pact_state_transitions" from "anon";
revoke truncate on table "public"."pact_state_transitions" from "anon";
revoke update on table "public"."pact_state_transitions" from "anon";
revoke delete on table "public"."pact_state_transitions" from "authenticated";
revoke insert on table "public"."pact_state_transitions" from "authenticated";
revoke references on table "public"."pact_state_transitions" from "authenticated";
revoke trigger on table "public"."pact_state_transitions" from "authenticated";
revoke truncate on table "public"."pact_state_transitions" from "authenticated";
revoke update on table "public"."pact_state_transitions" from "authenticated";
revoke references on table "public"."pact_state_transitions" from "service_role";
revoke trigger on table "public"."pact_state_transitions" from "service_role";
revoke truncate on table "public"."pact_state_transitions" from "service_role";
revoke delete on table "public"."pacts" from "anon";
revoke insert on table "public"."pacts" from "anon";
revoke references on table "public"."pacts" from "anon";
revoke trigger on table "public"."pacts" from "anon";
revoke truncate on table "public"."pacts" from "anon";
revoke update on table "public"."pacts" from "anon";
revoke references on table "public"."pacts" from "authenticated";
revoke trigger on table "public"."pacts" from "authenticated";
revoke truncate on table "public"."pacts" from "authenticated";
revoke references on table "public"."pacts" from "service_role";
revoke trigger on table "public"."pacts" from "service_role";
revoke truncate on table "public"."pacts" from "service_role";
revoke delete on table "public"."payments" from "anon";
revoke insert on table "public"."payments" from "anon";
revoke references on table "public"."payments" from "anon";
revoke trigger on table "public"."payments" from "anon";
revoke truncate on table "public"."payments" from "anon";
revoke update on table "public"."payments" from "anon";
revoke delete on table "public"."payments" from "authenticated";
revoke insert on table "public"."payments" from "authenticated";
revoke references on table "public"."payments" from "authenticated";
revoke trigger on table "public"."payments" from "authenticated";
revoke truncate on table "public"."payments" from "authenticated";
revoke update on table "public"."payments" from "authenticated";
revoke references on table "public"."payments" from "service_role";
revoke trigger on table "public"."payments" from "service_role";
revoke truncate on table "public"."payments" from "service_role";
revoke delete on table "public"."payouts" from "anon";
revoke insert on table "public"."payouts" from "anon";
revoke references on table "public"."payouts" from "anon";
revoke select on table "public"."payouts" from "anon";
revoke trigger on table "public"."payouts" from "anon";
revoke truncate on table "public"."payouts" from "anon";
revoke update on table "public"."payouts" from "anon";
revoke references on table "public"."payouts" from "authenticated";
revoke trigger on table "public"."payouts" from "authenticated";
revoke truncate on table "public"."payouts" from "authenticated";
revoke references on table "public"."payouts" from "service_role";
revoke trigger on table "public"."payouts" from "service_role";
revoke truncate on table "public"."payouts" from "service_role";
revoke delete on table "public"."quality_holdbacks" from "anon";
revoke insert on table "public"."quality_holdbacks" from "anon";
revoke references on table "public"."quality_holdbacks" from "anon";
revoke select on table "public"."quality_holdbacks" from "anon";
revoke trigger on table "public"."quality_holdbacks" from "anon";
revoke truncate on table "public"."quality_holdbacks" from "anon";
revoke update on table "public"."quality_holdbacks" from "anon";
revoke references on table "public"."quality_holdbacks" from "authenticated";
revoke trigger on table "public"."quality_holdbacks" from "authenticated";
revoke truncate on table "public"."quality_holdbacks" from "authenticated";
revoke references on table "public"."quality_holdbacks" from "service_role";
revoke trigger on table "public"."quality_holdbacks" from "service_role";
revoke truncate on table "public"."quality_holdbacks" from "service_role";
revoke delete on table "public"."signature_signers" from "anon";
revoke insert on table "public"."signature_signers" from "anon";
revoke references on table "public"."signature_signers" from "anon";
revoke trigger on table "public"."signature_signers" from "anon";
revoke truncate on table "public"."signature_signers" from "anon";
revoke update on table "public"."signature_signers" from "anon";
revoke references on table "public"."signature_signers" from "authenticated";
revoke trigger on table "public"."signature_signers" from "authenticated";
revoke truncate on table "public"."signature_signers" from "authenticated";
revoke references on table "public"."signature_signers" from "service_role";
revoke trigger on table "public"."signature_signers" from "service_role";
revoke truncate on table "public"."signature_signers" from "service_role";
revoke delete on table "public"."signatures" from "anon";
revoke insert on table "public"."signatures" from "anon";
revoke references on table "public"."signatures" from "anon";
revoke trigger on table "public"."signatures" from "anon";
revoke truncate on table "public"."signatures" from "anon";
revoke update on table "public"."signatures" from "anon";
revoke references on table "public"."signatures" from "authenticated";
revoke trigger on table "public"."signatures" from "authenticated";
revoke truncate on table "public"."signatures" from "authenticated";
revoke references on table "public"."signatures" from "service_role";
revoke trigger on table "public"."signatures" from "service_role";
revoke truncate on table "public"."signatures" from "service_role";
revoke delete on table "public"."surety_policies" from "anon";
revoke insert on table "public"."surety_policies" from "anon";
revoke references on table "public"."surety_policies" from "anon";
revoke select on table "public"."surety_policies" from "anon";
revoke trigger on table "public"."surety_policies" from "anon";
revoke truncate on table "public"."surety_policies" from "anon";
revoke update on table "public"."surety_policies" from "anon";
revoke references on table "public"."surety_policies" from "authenticated";
revoke trigger on table "public"."surety_policies" from "authenticated";
revoke truncate on table "public"."surety_policies" from "authenticated";
revoke references on table "public"."surety_policies" from "service_role";
revoke trigger on table "public"."surety_policies" from "service_role";
revoke truncate on table "public"."surety_policies" from "service_role";
revoke delete on table "public"."user_reputations" from "anon";
revoke insert on table "public"."user_reputations" from "anon";
revoke references on table "public"."user_reputations" from "anon";
revoke trigger on table "public"."user_reputations" from "anon";
revoke truncate on table "public"."user_reputations" from "anon";
revoke update on table "public"."user_reputations" from "anon";
revoke references on table "public"."user_reputations" from "authenticated";
revoke trigger on table "public"."user_reputations" from "authenticated";
revoke truncate on table "public"."user_reputations" from "authenticated";
revoke references on table "public"."user_reputations" from "service_role";
revoke trigger on table "public"."user_reputations" from "service_role";
revoke truncate on table "public"."user_reputations" from "service_role";
revoke delete on table "public"."users" from "anon";
revoke insert on table "public"."users" from "anon";
revoke references on table "public"."users" from "anon";
revoke trigger on table "public"."users" from "anon";
revoke truncate on table "public"."users" from "anon";
revoke update on table "public"."users" from "anon";
revoke references on table "public"."users" from "authenticated";
revoke trigger on table "public"."users" from "authenticated";
revoke truncate on table "public"."users" from "authenticated";
revoke update on table "public"."users" from "authenticated";
revoke references on table "public"."users" from "service_role";
revoke trigger on table "public"."users" from "service_role";
revoke truncate on table "public"."users" from "service_role";
revoke delete on table "public"."webhook_events" from "anon";
revoke insert on table "public"."webhook_events" from "anon";
revoke references on table "public"."webhook_events" from "anon";
revoke select on table "public"."webhook_events" from "anon";
revoke trigger on table "public"."webhook_events" from "anon";
revoke truncate on table "public"."webhook_events" from "anon";
revoke update on table "public"."webhook_events" from "anon";
revoke delete on table "public"."webhook_events" from "authenticated";
revoke insert on table "public"."webhook_events" from "authenticated";
revoke references on table "public"."webhook_events" from "authenticated";
revoke select on table "public"."webhook_events" from "authenticated";
revoke trigger on table "public"."webhook_events" from "authenticated";
revoke truncate on table "public"."webhook_events" from "authenticated";
revoke update on table "public"."webhook_events" from "authenticated";
revoke references on table "public"."webhook_events" from "service_role";
revoke trigger on table "public"."webhook_events" from "service_role";
revoke truncate on table "public"."webhook_events" from "service_role";

NOTIFY pgrst, 'reload schema';
