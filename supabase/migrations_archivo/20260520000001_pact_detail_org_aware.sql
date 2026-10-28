-- =====================================================================
-- Sprint 6 chunk 5c · Migration
-- sf_get_pact_detail consciente de Organizations + Members
-- =====================================================================
-- Cambios respecto a 0031 (v2.1):
--
--   * Validación de acceso vía fn_user_can_act_on_pact (party directo o
--     miembro activo de organización constructor/técnico).
--
--   * Nuevos flags en el objeto `pact`:
--       - is_member_via_org      → true si el user accede vía organización
--       - can_view_economics     → true si puede ver importes
--       - can_move_money         → true sólo si es party directo (owner)
--
--   * Enmascarado de importes para miembros SIN can_view_economics:
--       pact.total_amount_cents, pact.deposit_current_cents,
--       pact.budget_consumed_cents, pact.advance_released_cents,
--       pact.advance_outstanding_cents,
--       milestones[].amount_cents, milestones[].net_amount_cents,
--       milestones[].advance_amortization_cents,
--       milestones[].predeposit_received_cents,
--       addendums[].extra_amount_cents,
--       deposit_movements[] queda como `null` cuando no se ven economics,
--       surety_policy.premium_cents / coverage / claims también null.
--
-- Retrocompatible: parties directos no notan el cambio. Miembros con
-- can_view_economics=true ven exactamente lo mismo que un owner.
-- =====================================================================

DROP FUNCTION IF EXISTS public.sf_get_pact_detail;
CREATE OR REPLACE FUNCTION public.sf_get_pact_detail(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

GRANT EXECUTE ON FUNCTION public.sf_get_pact_detail TO authenticated;

COMMENT ON FUNCTION public.sf_get_pact_detail IS
  'Sprint 6 · Detalle del pacto consciente de Organizations + Members. '
  'Permite acceso a miembros activos de orgs parte; enmascara importes '
  'cuando can_view_economics=false. Añade flags is_member_via_org, '
  'can_view_economics, can_move_money al payload.';

NOTIFY pgrst, 'reload schema';
