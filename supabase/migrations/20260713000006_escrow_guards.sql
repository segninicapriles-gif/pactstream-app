-- REVISAR Y EJECUTAR MANUALMENTE. NO APLICADO. Verificar impacto en usuarios existentes.
-- =====================================================================
-- AUDITORÍA 2026-07-13 · PactStream Escrow — C3 / C4 / M1
-- =====================================================================
-- RE-DERIVADO 2026-07-13 sobre la definición ACTUAL del remoto
-- (pactstream-dev). Se comprobó con pg_get_functiondef que el cuerpo
-- vigente de AMBAS RPC es la versión v1 (mock release); las migraciones
-- de junio (escrow_acopio / dispute_escrow_expansion / smart_contracts_ipc)
-- NO redefinieron estas dos funciones. Por tanto este parche parte del
-- CUERPO REMOTO EXACTO y solo añade los controles de seguridad, sin
-- introducir ni tocar lógica de acopio/dispute/retención (no existe aquí).
--
--   C4 (autotrato) + duplicados  → sf_invite_party              [CABLEADO]
--   M1 (FOR UPDATE)              → sf_milestone_promotor_decide  [CABLEADO]
--   C3 (liberación sin saldo)    → sf_milestone_promotor_decide  [DOCUMENTADO]
--
-- Se usa CREATE OR REPLACE (sin DROP) para preservar GRANTs existentes y
-- conservar la firma EXACTA (uuid,text,text,text,text) / (uuid,text,text).
-- =====================================================================


-- =====================================================================
-- C4 + duplicados · sf_invite_party(uuid,text,text,text,text)
-- =====================================================================
-- Cuerpo base = definición ACTUAL del remoto (v1, no tocada por junio).
-- El original NO validaba que el invitado no fuese el propio creador
-- (autotrato) ni que su email/user_id ya estuviese en el pacto → se podía
-- crear una contraparte ficticia controlada por el mismo actor, o duplicar
-- partes. Se añaden 3 guardas justo tras resolver v_existing_user_id y
-- ANTES del INSERT. Nada más cambia.
--
-- IMPACTO: ninguno para invitaciones válidas. Invitarse a uno mismo o
-- duplicar un email/usuario ya presente en el pacto ahora falla.
CREATE OR REPLACE FUNCTION public.sf_invite_party(
  p_pact_id uuid,
  p_role text,
  p_email text,
  p_full_name text,
  p_phone text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
$function$;

GRANT EXECUTE ON FUNCTION public.sf_invite_party(uuid,text,text,text,text) TO authenticated;

-- RECOMENDACIÓN (revisar datos antes de aplicar): reforzar a nivel de
-- esquema el rechazo de usuario duplicado por pacto. Solo aplica a partes
-- con user_id no nulo (invitados aún no registrados tienen user_id NULL).
-- Verificar que no existan duplicados previos:
--   -- SELECT pact_id, user_id, count(*) FROM public.pact_parties
--   --   WHERE user_id IS NOT NULL GROUP BY 1,2 HAVING count(*) > 1;
--   -- CREATE UNIQUE INDEX IF NOT EXISTS ux_pact_parties_pact_user
--   --   ON public.pact_parties (pact_id, user_id)
--   --   WHERE user_id IS NOT NULL;


-- =====================================================================
-- M1 · sf_milestone_promotor_decide(uuid,text,text) — FOR UPDATE [CABLEADO]
-- =====================================================================
-- Cuerpo base = definición ACTUAL del remoto (v1 mock release; junio NO la
-- tocó — no contiene acopio/dispute-escrow/retención). Se añade un LOCK de
-- la fila del hito al inicio, ANTES de leer el estado, para serializar dos
-- decisiones concurrentes del promotor (evita doble release / doble
-- disputa por condición de carrera TOCTOU). No se altera nada más.
--
-- C3 (liberación sin saldo): el guard de saldo NO se cablea aquí; ver el
-- bloque DOCUMENTADO más abajo. Motivo: esta RPC v1 nunca consulta ni
-- decrementa deposit_current_cents y usa amount_cents (bruto), mientras la
-- custodia v2/v21 trabaja en net_amount_cents. Cablear un guard de saldo
-- exige reconciliar el modelo contable y podría bloquear pactos legacy
-- financiados por mock (deposit_current_cents = 0).
--
-- IMPACTO: ninguno para decisiones válidas; solo se serializa el acceso
-- concurrente al mismo hito.
CREATE OR REPLACE FUNCTION public.sf_milestone_promotor_decide(
  p_milestone_id uuid,
  p_decision text,
  p_rationale text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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

  -- ── Auditoría 2026-07-13 C3 (liberación sin saldo) — PARCHE DOCUMENTADO ──
  -- Antes de marcar 'paid' (release del escrow) debería garantizarse que la
  -- custodia del pacto cubre el neto del hito. NO se cablea aún: requiere
  -- reconciliar el modelo de custodia v2/v21 (net vs bruto y decremento en
  -- release) y contexto que esta RPC v1 no maneja. Diff propuesto:
  --
  --   DECLARE  -- (añadir a la sección DECLARE)
  --     v_net_cents      bigint;
  --     v_deposit_cents  bigint;
  --   ...
  --   IF p_decision = 'approve' THEN
  --     SELECT coalesce(net_amount_cents, amount_cents)
  --       INTO v_net_cents FROM public.milestones WHERE id = p_milestone_id;
  --     SELECT deposit_current_cents INTO v_deposit_cents
  --       FROM public.pacts WHERE id = v_pact_id FOR UPDATE;   -- lock del pacto
  --     IF v_deposit_cents < v_net_cents THEN
  --       RAISE EXCEPTION 'Saldo en custodia insuficiente para liberar el hito (custodia: % / neto: %)',
  --         v_deposit_cents, v_net_cents;
  --     END IF;
  --     UPDATE public.pacts
  --       SET deposit_current_cents = deposit_current_cents - v_net_cents
  --       WHERE id = v_pact_id;
  --     INSERT INTO public.deposit_movements (
  --       pact_id, movement_type, amount_cents, triggered_by_user_id,
  --       related_milestone_id, balance_before_cents, balance_after_cents, notes
  --     ) VALUES (
  --       v_pact_id, 'release_for_cert', -v_net_cents, v_user_id,
  --       p_milestone_id, v_deposit_cents, v_deposit_cents - v_net_cents,
  --       'Release de Cert al aprobar el hito');
  --   END IF;
  --
  -- ADVERTENCIA: verificar antes cuántos pactos activos tienen
  -- deposit_current_cents < neto (mock-funded / legacy) para no bloquear
  -- releases en curso. NO aplicar a ciegas.

  IF p_decision = 'approve' THEN
    UPDATE public.milestones
    SET state = 'paid', approved_by_promotor_at = now(), paid_at = now()
    WHERE id = p_milestone_id;
    v_final_state := 'paid';
    INSERT INTO public.pact_events (pact_id, event_type, payload, actor_user_id)
    VALUES (v_pact_id, 'milestone_paid',
      jsonb_build_object('milestone_id', p_milestone_id, 'amount_cents', v_amount_cents,
        'note', 'MOCK release · Mangopay pendiente'), v_user_id);
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
    jsonb_build_object('decision', p_decision, 'final_state', v_final_state::text));

  RETURN jsonb_build_object('success', true, 'milestone_state', v_final_state::text);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.sf_milestone_promotor_decide(uuid,text,text) TO authenticated;

COMMENT ON FUNCTION public.sf_milestone_promotor_decide(uuid,text,text) IS
  'El promotor decide approve|dispute. Obra mayor: desde awaiting_promotor. Obra menor: desde ready_for_review (cascada). Auditoría 2026-07-13: lock FOR UPDATE del hito (M1). Guard de saldo (C3) pendiente de cablear — ver bloque documentado.';

NOTIFY pgrst, 'reload schema';
