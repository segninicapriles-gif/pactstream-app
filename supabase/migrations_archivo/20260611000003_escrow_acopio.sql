-- Reconstruida el 2026-07-13 desde supabase_migrations.schema_migrations del remoto
-- (pactstream-dev / erqglsrnknhwqhfupckf). Esta migracion YA estaba aplicada en el
-- remoto pero no versionada en el repo local; se recupera para alinear el historial.
-- Fuente: statements[] almacenados por el CLI de Supabase.

-- Migration: Escrow de Acopio (Mejora 5.1)
--
-- Nuevo tipo de hito para hedging de materiales. Permite al promotor
-- depositar fondos específicos para la compra de materiales antes de que
-- la obra comience o durante su ejecución. El constructor puede solicitar
-- la liberación parcial conforme documenta la compra con facturas.
--
-- Diferencia con hito normal:
--   - Se crea al inicio del pacto (no requiere cert previa).
--   - El importe se deposita íntegramente en custodia.
--   - La liberación es parcial contra factura de proveedor verificada.
--   - No sigue el flujo de validación técnica estándar.

-- ---------------------------------------------------------------------------
-- 1. Tipo de hito: milestone_category
-- ---------------------------------------------------------------------------
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'certification'
    CHECK (category IN ('certification', 'acopio', 'retention'));

COMMENT ON COLUMN public.milestones.category IS
  'Tipo de hito: certification (normal), acopio (escrow materiales), retention (reserva final)';

CREATE INDEX IF NOT EXISTS idx_milestones_category
  ON public.milestones (pact_id, category);

-- ---------------------------------------------------------------------------
-- 2. Tabla acopio_items — partidas de materiales dentro del escrow
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.acopio_items (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id    uuid NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
  pact_id         uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  description     text NOT NULL,
  material_type   text NOT NULL DEFAULT 'generic',
  estimated_cents bigint NOT NULL CHECK (estimated_cents > 0),
  actual_cents    bigint,
  supplier_name   text,
  supplier_cif    text,
  invoice_ref     text,
  invoice_storage_path text,
  invoice_sha256  text,
  state           text NOT NULL DEFAULT 'pending'
    CHECK (state IN ('pending', 'quoted', 'purchased', 'delivered', 'verified', 'released')),
  purchased_at    timestamptz,
  delivered_at    timestamptz,
  verified_at     timestamptz,
  released_at     timestamptz,
  released_cents  bigint DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_acopio_items_milestone ON public.acopio_items (milestone_id, state);

ALTER TABLE acopio_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "acopio_read_party" ON public.acopio_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pact_parties pp
      WHERE pp.pact_id = acopio_items.pact_id
        AND pp.user_id = (
          SELECT u.id FROM public.users u
          WHERE u.auth_provider_id = auth.uid()::text
          LIMIT 1
        )
    )
  );

GRANT SELECT ON public.acopio_items TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC: sf_create_acopio_milestone
--    Constructor o promotor crea un hito de acopio con items de materiales.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_create_acopio_milestone(
  p_pact_id uuid,
  p_name text,
  p_total_cents bigint,
  p_items jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

GRANT EXECUTE ON FUNCTION public.sf_create_acopio_milestone TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC: sf_release_acopio_item
--    Promotor autoriza la liberación de fondos para un item de material
--    tras verificar la factura del proveedor.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sf_release_acopio_item(
  p_item_id uuid,
  p_amount_cents bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

GRANT EXECUTE ON FUNCTION public.sf_release_acopio_item TO authenticated;
