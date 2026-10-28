-- =====================================================================
-- Sprint 3 chunk 3 · Migration 0021 (HOTFIX)
-- Añade signaturit_signature_id al payload de sf_get_pact_detail
-- para que el PDF del contrato pueda mostrar el identificador de firma.
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
      'my_user_id', v_user_id
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
        'paid_at', m.paid_at
      ) ORDER BY m.ordinal)
      FROM public.milestones m WHERE m.pact_id = p_pact_id
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.pacts p
  WHERE p.id = p_pact_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sf_get_pact_detail TO authenticated;

NOTIFY pgrst, 'reload schema';
