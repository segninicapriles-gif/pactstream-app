-- =====================================================================
-- Sprint 4 chunk 4 · Migration 0025 (HOTFIX)
-- Corrige columnas inexistentes en sf_get_pact_detail
-- =====================================================================
-- La migración 0024 referenciaba a.activated_at y a.cancelled_at, pero
-- la tabla pact_addendums (creada en 0018) solo tiene `finalized_at`
-- (timestamp único para ambas terminaciones).
--
-- Solución: derivar activated_at / cancelled_at desde finalized_at + state.
-- Así el contrato del JSON con el cliente Dart se mantiene intacto.
-- =====================================================================

DROP FUNCTION IF EXISTS public.sf_get_pact_detail;
CREATE OR REPLACE FUNCTION public.sf_get_pact_detail(p_pact_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_id  uuid;
  v_is_party boolean;
  v_result   jsonb;
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

  SELECT EXISTS(
    SELECT 1 FROM public.pact_parties pp
    WHERE pp.pact_id = p_pact_id AND pp.user_id = v_user_id
  ) INTO v_is_party;

  IF NOT v_is_party THEN
    RAISE EXCEPTION 'No tienes acceso a este pacto';
  END IF;

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
      'total_amount_cents', p.total_amount_cents,
      'iva_rate_pct', p.iva_rate_pct,
      'iva_included', p.iva_included,
      'platform_fee_pct', p.platform_fee_pct,
      'estimated_start_date', p.estimated_start_date,
      'estimated_end_date', p.estimated_end_date,
      'created_by_user_id', p.created_by_user_id,
      'created_at', p.created_at,
      'is_creator', (p.created_by_user_id = v_user_id),
      'my_user_id', v_user_id,
      -- Campos v2.0
      'model_version', coalesce(p.model_version, 'v1'),
      'deposit_required_pct', p.deposit_required_pct,
      'deposit_current_cents', coalesce(p.deposit_current_cents, 0),
      'budget_consumed_cents', coalesce(p.budget_consumed_cents, 0),
      'certification_frequency_text', p.certification_frequency_text
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
        'amount_cents', m.amount_cents,
        'target_date', m.target_date,
        'state', m.state::text,
        'state_updated_at', m.state_updated_at,
        'started_at', m.started_at,
        'submitted_at', m.submitted_at,
        'validated_at', m.validated_at,
        'approved_by_promotor_at', m.approved_by_promotor_at,
        'rejected_at', m.rejected_at,
        'paid_at', m.paid_at,
        -- Campos v2.0
        'version', coalesce(m.version, 1),
        'previous_version_id', m.previous_version_id,
        'invoice_number', m.invoice_number,
        'invoice_storage_path', m.invoice_storage_path,
        'invoice_sha256', m.invoice_sha256,
        'invoice_size_bytes', m.invoice_size_bytes,
        'detailed_doc_storage_path', m.detailed_doc_storage_path,
        'detailed_doc_sha256', m.detailed_doc_sha256,
        'detailed_doc_mime_type', m.detailed_doc_mime_type,
        'detailed_doc_size_bytes', m.detailed_doc_size_bytes
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
        'extra_amount_cents', a.extra_amount_cents,
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
        -- finalized_at se usa para ambos finales; lo desambiguamos por estado
        'activated_at', CASE WHEN a.state = 'active'    THEN a.finalized_at END,
        'cancelled_at', CASE WHEN a.state = 'cancelled' THEN a.finalized_at END,
        'created_at', a.created_at
      ) ORDER BY a.ordinal)
      FROM public.pact_addendums a WHERE a.pact_id = p_pact_id
    ), '[]'::jsonb),
    'deposit_movements', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', dm.id,
        'movement_type', dm.movement_type::text,
        'amount_cents', dm.amount_cents,
        'balance_before_cents', dm.balance_before_cents,
        'balance_after_cents', dm.balance_after_cents,
        'milestone_id', dm.milestone_id,
        'triggered_by_user_id', dm.triggered_by_user_id,
        'notes', dm.notes,
        'created_at', dm.created_at
      ) ORDER BY dm.created_at DESC)
      FROM public.deposit_movements dm WHERE dm.pact_id = p_pact_id
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.pacts p
  WHERE p.id = p_pact_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_pact_detail TO authenticated;

COMMENT ON FUNCTION public.sf_get_pact_detail IS
  'Sprint 4 hotfix · Mismo payload que 0024 pero usando finalized_at para '
  'derivar activated_at/cancelled_at según el estado del anexo.';

NOTIFY pgrst, 'reload schema';
