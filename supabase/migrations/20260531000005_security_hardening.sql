-- =============================================================================
-- SECURITY HARDENING MIGRATION
-- Addresses findings from security audit 2026-05-31
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 1: REVOKE mock RPCs from authenticated role
-- Findings: sf_simulate_kyc_verification and sf_mock_fund_pact are callable
-- by any authenticated user, allowing KYC bypass and funding without payment.
-- ─────────────────────────────────────────────────────────────────────────────

-- Revoke KYC mock — only service_role (admin) should be able to simulate
-- Signature: (p_decision text DEFAULT 'verified', p_reason text DEFAULT NULL)
REVOKE EXECUTE ON FUNCTION sf_simulate_kyc_verification(text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION sf_simulate_kyc_verification(text, text) FROM anon;

-- Revoke mock fund — only service_role (admin) should bypass real payment
-- Signature: (p_pact_id uuid)
REVOKE EXECUTE ON FUNCTION sf_mock_fund_pact(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION sf_mock_fund_pact(uuid) FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 2: Enable RLS on unprotected tables
-- Findings: audit_log, webhook_events, pact_state_transitions, and
-- milestone_state_transitions lack RLS, exposing sensitive data.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE pact_state_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestone_state_transitions ENABLE ROW LEVEL SECURITY;

-- audit_log: users can only read their own entries
CREATE POLICY "Users can view own audit entries"
  ON audit_log FOR SELECT
  USING (actor_user_id = auth.uid());

-- webhook_events: no direct access from client — service_role only
-- (No policies = deny all for authenticated/anon, allow for service_role)

-- pact_state_transitions: users can only read transitions for their pacts
CREATE POLICY "Users can view transitions of their pacts"
  ON pact_state_transitions FOR SELECT
  USING (
    pact_id IN (
      SELECT pact_id FROM pact_parties WHERE user_id = auth.uid()
    )
  );

-- milestone_state_transitions: same pattern
CREATE POLICY "Users can view milestone transitions of their pacts"
  ON milestone_state_transitions FOR SELECT
  USING (
    milestone_id IN (
      SELECT m.id FROM milestones m
      JOIN pact_parties pp ON pp.pact_id = m.pact_id
      WHERE pp.user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 3: Restrict DML grants on sensitive tables
-- Findings: Overly broad INSERT/UPDATE/DELETE on append-only and audit tables.
-- ─────────────────────────────────────────────────────────────────────────────

-- audit_log: read-only for authenticated (writes via SECURITY DEFINER RPCs)
REVOKE INSERT, UPDATE, DELETE ON audit_log FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON audit_log FROM anon;

-- webhook_events: no client access at all
REVOKE ALL ON webhook_events FROM authenticated;
REVOKE ALL ON webhook_events FROM anon;

-- pact_state_transitions: read-only
REVOKE INSERT, UPDATE, DELETE ON pact_state_transitions FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON pact_state_transitions FROM anon;

-- milestone_state_transitions: read-only
REVOKE INSERT, UPDATE, DELETE ON milestone_state_transitions FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON milestone_state_transitions FROM anon;

-- pact_events: already has append-only trigger, but revoke UPDATE/DELETE
REVOKE UPDATE, DELETE ON pact_events FROM authenticated;
REVOKE UPDATE, DELETE ON pact_events FROM anon;

-- deposit_movements: should be append-only via RPCs
REVOKE UPDATE, DELETE ON deposit_movements FROM authenticated;
REVOKE UPDATE, DELETE ON deposit_movements FROM anon;

-- payments: should be managed by RPCs only
REVOKE INSERT, UPDATE, DELETE ON payments FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON payments FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 4: Add KYC check to critical RPCs
-- Finding: No server-side KYC enforcement on pact creation, signing, etc.
-- ─────────────────────────────────────────────────────────────────────────────

-- Helper function to check KYC status
CREATE OR REPLACE FUNCTION check_kyc_verified(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
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

-- Note: To integrate check_kyc_verified() into existing RPCs like
-- sf_create_pact_v2, sf_sign_contract, sf_accept_invitation, etc.,
-- add this call at the beginning of each function body:
--   PERFORM check_kyc_verified(v_user_id);
-- This is left as a separate step to avoid modifying complex RPCs
-- in a single migration. Apply to each RPC individually.

-- ─────────────────────────────────────────────────────────────────────────────
-- DONE — Security hardening applied
-- ─────────────────────────────────────────────────────────────────────────────
