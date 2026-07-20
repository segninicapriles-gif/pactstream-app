-- ---------------------------------------------------------------------------
-- 20260720000001_import_budget_bridge.sql
--
-- PUENTE CostPact → PactStream (envío de datos de una app a otra).
--
-- Hasta ahora la integración era una maqueta: los botones de CostPact estaban
-- deshabilitados, y las tablas `api_keys` / `pact_metadata` existían pero
-- NINGUNA función las consumía. Esta migración cablea el puente por primera vez.
--
-- Flujo: CostPact exporta un presupuesto como JSON y llama a esta RPC con una
-- api-key de partner. La RPC:
--   1. Autentica la api-key (hash SHA-256 contra `api_keys`, activa, scope
--      'import:budget').
--   2. Resuelve el promotor POR EMAIL (modelo elegido): busca el usuario de
--      PactStream con rol 'promotor' y ese email. (El handoff SSO de producción
--      —cómo se prueba esa identidad entre apps— queda como pieza pendiente.)
--   3. Impersona a ese promotor (set request.jwt.claims → auth.uid()) y crea el
--      pacto con `sf_create_pact_v21`, reutilizando toda la lógica de negocio y
--      validaciones existentes en vez de insertar a mano.
--   4. Añade los hitos del presupuesto con `sf_add_milestone`.
--   5. Registra el enlace en `pact_metadata` (costpact_presupuesto_id → pact_id)
--      y el uso en `api_key_usage`.
--
-- SEGURIDAD: SECURITY DEFINER con search_path fijado. La impersonación está
-- estrictamente gateada por una api-key válida+activa+con scope. Solo crea
-- pactos a nombre de un promotor que YA existe en PactStream con ese email —
-- no puede crear usuarios ni asignar a cuentas arbitrarias.
--
-- Proyecto: dev (erqglsrnknhwqhfupckf). Idempotente vía CREATE OR REPLACE.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sf_import_budget_as_pact(
  p_api_key text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key_id        uuid;
  v_partner       text;
  v_scopes        text[];
  v_hash          text;
  v_email         text;
  v_promotor_id   uuid;      -- users.id
  v_promotor_auth text;      -- users.auth_provider_id (= auth.uid()::text)
  v_pact_id       uuid;
  v_display_id    text;
  v_ms            jsonb;
  v_ordinal       smallint := 0;
  v_ms_count      int := 0;
  v_presu_id      text;
BEGIN
  -- 1. Autenticar api-key ────────────────────────────────────────────────────
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

  -- 2. Resolver promotor por email ───────────────────────────────────────────
  v_email := lower(trim(p_payload ->> 'promotor_email'));
  IF v_email IS NULL OR v_email = '' THEN
    RAISE EXCEPTION 'payload sin promotor_email';
  END IF;

  SELECT id, auth_provider_id INTO v_promotor_id, v_promotor_auth
  FROM public.users
  WHERE lower(email) = v_email AND primary_role = 'promotor' AND deleted_at IS NULL
  LIMIT 1;

  IF v_promotor_id IS NULL THEN
    -- Modelo email: en producción aquí iría la invitación/vinculación de cuenta.
    RAISE EXCEPTION 'no existe un promotor de PactStream con email %; requiere invitación/vinculación', v_email
      USING errcode = 'P0002';
  END IF;

  -- 3. Impersonar al promotor y crear el pacto ───────────────────────────────
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

  -- 4. Añadir hitos ──────────────────────────────────────────────────────────
  FOR v_ms IN SELECT * FROM jsonb_array_elements(coalesce(p_payload -> 'milestones', '[]'::jsonb))
  LOOP
    v_ordinal := v_ordinal + 1;
    PERFORM public.sf_add_milestone(
      p_pact_id      => v_pact_id,
      p_ordinal      => v_ordinal,
      p_name         => coalesce(v_ms ->> 'name', 'Hito '||v_ordinal),
      p_amount_cents => (v_ms ->> 'amount_cents')::bigint,
      p_description  => v_ms ->> 'description',
      p_target_date  => nullif(v_ms ->> 'target_date','')::date
    );
    v_ms_count := v_ms_count + 1;
  END LOOP;

  -- 5. Enlace + auditoría (como definer, sin impersonación no hace falta) ─────
  v_presu_id := p_payload ->> 'costpact_presupuesto_id';
  INSERT INTO public.pact_metadata (pact_id, key, value) VALUES
    (v_pact_id, 'source', 'costpact'),
    (v_pact_id, 'costpact_presupuesto_id', coalesce(v_presu_id,'')),
    (v_pact_id, 'partner_id', v_partner);

  INSERT INTO public.api_key_usage (api_key_id, partner_id, endpoint)
  VALUES (v_key_id, v_partner, 'sf_import_budget_as_pact');

  RETURN jsonb_build_object(
    'ok', true,
    'pact_id', v_pact_id,
    'display_id', v_display_id,
    'promotor_email', v_email,
    'milestones_created', v_ms_count,
    'partner_id', v_partner
  );
END;
$$;

-- Solo service_role la invoca (la llamará el backend de CostPact, no el cliente).
REVOKE ALL     ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) FROM anon;
REVOKE ALL     ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) TO service_role;
