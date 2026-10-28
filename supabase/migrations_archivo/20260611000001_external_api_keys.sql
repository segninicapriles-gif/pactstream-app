-- Reconstruida el 2026-07-13 desde supabase_migrations.schema_migrations del remoto
-- (pactstream-dev / erqglsrnknhwqhfupckf). Esta migracion YA estaba aplicada en el
-- remoto pero no versionada en el repo local; se recupera para alinear el historial.
-- Fuente: statements[] almacenados por el CLI de Supabase.

-- Migration: External API keys for partner integrations (ConstructPro → PactStream)
-- Supports the create-pact-external Edge Function.

-- ---------------------------------------------------------------------------
-- 1. api_keys — One row per partner API key
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_keys (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id  text NOT NULL,                    -- e.g. 'constructpro'
  label       text NOT NULL DEFAULT '',         -- human-readable label
  key_hash    text NOT NULL UNIQUE,             -- SHA-256 hex of the raw key
  scopes      text[] NOT NULL DEFAULT '{}',     -- e.g. {'pact:create'}
  active      boolean NOT NULL DEFAULT true,
  rate_limit_rpm int NOT NULL DEFAULT 60,
  created_at  timestamptz NOT NULL DEFAULT now(),
  revoked_at  timestamptz
);

COMMENT ON TABLE api_keys IS 'API keys for external partner integrations';

COMMENT ON COLUMN api_keys.key_hash IS 'SHA-256 hex digest — never store raw keys';

-- RLS: only service_role can read/write
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- No policies = only service_role access (Edge Functions use service_role)

-- ---------------------------------------------------------------------------
-- 2. api_key_usage — Rate-limit tracking
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_key_usage (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  api_key_id  uuid NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
  partner_id  text NOT NULL,
  endpoint    text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_api_key_usage_rate ON api_key_usage (api_key_id, created_at DESC);

ALTER TABLE api_key_usage ENABLE ROW LEVEL SECURITY;

-- Auto-prune usage rows older than 1 hour (keep table small)
-- Handled by pg_cron if available, otherwise manual cleanup.

-- ---------------------------------------------------------------------------
-- 3. pact_metadata — Key-value store for external references
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pact_metadata (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id   uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  key       text NOT NULL,
  value     text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(pact_id, key)
);

CREATE INDEX idx_pact_metadata_pact ON pact_metadata (pact_id);

CREATE INDEX idx_pact_metadata_lookup ON pact_metadata (key, value);

ALTER TABLE pact_metadata ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read metadata of pacts they're party to
CREATE POLICY "pact_metadata_read" ON pact_metadata FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM pact_parties pp
      WHERE pp.pact_id = pact_metadata.pact_id
        AND pp.user_id = auth.uid()
    )
  );

-- Only service_role can insert/update (via Edge Functions)

-- ---------------------------------------------------------------------------
-- 4. Grant execute to authenticated for RPC impersonation header support
-- ---------------------------------------------------------------------------
-- The create-pact-external function uses service_role with
-- x-supabase-auth-user-id header to impersonate the creator.
-- The RPCs already check auth.uid(), which Supabase resolves from this header
-- when called with service_role + the override header.;
