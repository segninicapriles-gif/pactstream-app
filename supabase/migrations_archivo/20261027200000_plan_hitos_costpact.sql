-- ---------------------------------------------------------------------------
-- 20261027200000_plan_hitos_costpact.sql
--
-- PLAN DE HITOS importado de CostPact (opción A, decidida el 27-oct-2026).
--
-- Problema: en el modelo v2.1 todo hito no pagado resta del techo de
-- presupuesto (`sf_constructor_create_cert_v21`). Si los hitos del presupuesto
-- de CostPact se crean como `milestones`, suman el total y ninguna
-- certificación cabe. Por eso el presupuesto llega como PLAN: no consume
-- techo, y cada certificación se crea eligiendo un elemento del plan.
--
-- Contenido (aditivo; no borra ni modifica datos existentes):
--   1. Tabla `pact_plan_items` (+ RLS por pertenencia al pacto + GRANTs).
--   2. RPC `sf_link_costpact_budget`: la app guarda el enlace y el plan al
--      crear el pacto importado (solo el creador, solo en borrador).
--   3. RPC `sf_link_cert_to_plan_item`: enlaza una certificación con su
--      elemento del plan (solo el constructor del pacto).
--   4. `sf_import_budget_as_pact` (puente de servidor) deja de crear
--      `milestones` y guarda el plan.
--   5. Corrige la política de lectura de `pact_metadata`, que comparaba
--      `pact_parties.user_id` (users.id) con `auth.uid()` y nunca coincidía.
--
-- Proyecto: dev (erqglsrnknhwqhfupckf).
-- ---------------------------------------------------------------------------

-- 1. Tabla del plan ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pact_plan_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id       uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  ordinal       smallint NOT NULL,
  name          text NOT NULL,
  description   text,
  amount_cents  bigint NOT NULL CHECK (amount_cents >= 0),
  percentage    numeric(5,2),
  -- advance = el Adelanto del modelo v2.1 (no se certifica);
  -- phase = fase de obra; retention = liberación de retención al final.
  kind          text NOT NULL DEFAULT 'phase'
                CHECK (kind IN ('advance', 'phase', 'retention')),
  source        text NOT NULL DEFAULT 'costpact',
  milestone_id  uuid REFERENCES public.milestones(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pact_id, ordinal)
);

CREATE INDEX IF NOT EXISTS idx_pact_plan_items_pact ON public.pact_plan_items (pact_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_pact_plan_items_milestone
  ON public.pact_plan_items (milestone_id) WHERE milestone_id IS NOT NULL;

ALTER TABLE public.pact_plan_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pact_plan_items_party_select ON public.pact_plan_items;
CREATE POLICY pact_plan_items_party_select ON public.pact_plan_items FOR SELECT
  USING (user_in_pact(pact_id, current_user_id()));

-- Escritura solo por las RPC SECURITY DEFINER de abajo.
REVOKE ALL ON public.pact_plan_items FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.pact_plan_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pact_plan_items TO service_role;

-- Clasificación del hito de CostPact según su disparador.
CREATE OR REPLACE FUNCTION public.sf_plan_item_kind(p_trigger text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE p_trigger
    WHEN 'firma_contrato' THEN 'advance'
    WHEN 'fin_garantia'   THEN 'retention'
    ELSE 'phase'
  END;
$$;

-- Escribe el plan de un pacto (reemplaza el anterior). Uso interno.
CREATE OR REPLACE FUNCTION public.sf_write_pact_plan(p_pact_id uuid, p_items jsonb)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

REVOKE ALL ON FUNCTION public.sf_write_pact_plan(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sf_write_pact_plan(uuid, jsonb) TO service_role;

-- 2. Enlace desde la app al crear el pacto importado ────────────────────────
CREATE OR REPLACE FUNCTION public.sf_link_costpact_budget(
  p_pact_id        uuid,
  p_presupuesto_id text,
  p_items          jsonb
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

REVOKE ALL ON FUNCTION public.sf_link_costpact_budget(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sf_link_costpact_budget(uuid, text, jsonb) TO authenticated, service_role;

-- 3. Certificación ↔ elemento del plan ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sf_link_cert_to_plan_item(
  p_milestone_id uuid,
  p_plan_item_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

REVOKE ALL ON FUNCTION public.sf_link_cert_to_plan_item(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sf_link_cert_to_plan_item(uuid, uuid) TO authenticated, service_role;

-- 4. Puente de servidor: el presupuesto llega como plan ─────────────────────
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

REVOKE ALL     ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) FROM anon;
REVOKE ALL     ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.sf_import_budget_as_pact(text, jsonb) TO service_role;

-- 5. Política de lectura de pact_metadata (antes nunca coincidía) ──────────
DROP POLICY IF EXISTS "pact_metadata_read" ON public.pact_metadata;
CREATE POLICY "pact_metadata_read" ON public.pact_metadata FOR SELECT
  USING (user_in_pact(pact_id, current_user_id()));

NOTIFY pgrst, 'reload schema';
