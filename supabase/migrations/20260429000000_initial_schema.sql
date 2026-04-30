-- =====================================================================
-- PACTSTREAM — Postgres Schema v1.0
-- =====================================================================
-- Compatible con Supabase, Neon, AWS RDS, Google Cloud SQL.
-- Diseñado para PostgreSQL 15+.
--
-- Convenciones:
--   - Snake case en nombres de tablas y columnas.
--   - UUIDs como PKs (gen_random_uuid()).
--   - Timestamps con timezone (timestamptz) siempre en UTC.
--   - Importes monetarios en BIGINT como céntimos de euro (no FLOAT).
--   - Soft delete con deleted_at en tablas con datos personales (RGPD).
--   - Append-only en evidencias y audit_log.
--
-- Este schema no contiene los datos seed ni las funciones RPC.
-- Las políticas Row Level Security (RLS) van al final.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- =====================================================================
-- ENUMS
-- =====================================================================

CREATE TYPE user_role AS ENUM ('promotor', 'constructor', 'tecnico', 'admin');

CREATE TYPE kyc_status AS ENUM (
  'not_started',
  'in_progress',
  'pending_review',
  'verified',
  'rejected',
  'expired'
);

CREATE TYPE legal_doc_type AS ENUM (
  'terms_of_service',
  'privacy_policy',
  'escrow_terms',
  'cookies_policy',
  'biometric_consent'
);

CREATE TYPE pact_state AS ENUM (
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
  'cancelled'
);

CREATE TYPE milestone_state AS ENUM (
  'pending',
  'in_execution',
  'ready_for_review',
  'in_validation',
  'info_requested',
  'approved_by_tech',
  'rejected_by_tech',
  'awaiting_promotor',
  'paid',
  'disputed'
);

CREATE TYPE pact_party_role AS ENUM ('promotor', 'constructor', 'tecnico');

CREATE TYPE evidence_type AS ENUM ('photo', 'video', 'audio', 'document', 'note');

CREATE TYPE evidence_verification AS ENUM (
  'verified',
  'gps_outside_radius',
  'metadata_anomaly',
  'manual_override'
);

CREATE TYPE validation_decision AS ENUM (
  'approved',
  'rejected',
  'info_requested'
);

CREATE TYPE dispute_state AS ENUM (
  'opened',
  'in_review',
  'proposal_sent',
  'resolved',
  'withdrawn',
  'escalated_to_arbitration'
);

CREATE TYPE dispute_outcome AS ENUM (
  'release_full',
  'release_partial',
  'refund_full',
  'redo_milestone',
  'pending'
);

CREATE TYPE payment_type AS ENUM (
  'pay_in',
  'milestone_release',
  'partial_refund',
  'full_refund',
  'platform_fee',
  'reversal'
);

CREATE TYPE payment_state AS ENUM (
  'created',
  'pending',
  'succeeded',
  'failed',
  'cancelled'
);

CREATE TYPE document_type AS ENUM (
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

CREATE TYPE signature_state AS ENUM (
  'requested',
  'sent',
  'partially_signed',
  'signed',
  'expired',
  'cancelled'
);

CREATE TYPE notification_channel AS ENUM ('push', 'email', 'sms', 'in_app');

CREATE TYPE notification_priority AS ENUM ('low', 'normal', 'high', 'critical');

-- =====================================================================
-- 1. USUARIOS Y ORGANIZACIONES
-- =====================================================================

CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Auth (Supabase Auth o Firebase Auth referencia)
  auth_provider   text NOT NULL DEFAULT 'supabase',
  auth_provider_id text NOT NULL UNIQUE,

  -- Identidad
  full_name       text NOT NULL,
  email           citext NOT NULL UNIQUE,
  phone_e164      text,
  national_id     text,           -- DNI / NIE / pasaporte (cifrado a nivel de aplicación recomendado)
  date_of_birth   date,
  address_line    text,
  postal_code     text,
  city            text,
  province        text,
  country_iso     char(2) NOT NULL DEFAULT 'ES',

  -- Rol primario (un usuario puede tener varios roles a través de pacts, pero tiene un rol primario)
  primary_role    user_role NOT NULL,

  -- Profesional (solo técnico)
  profession      text,
  colegio         text,            -- ej. 'COAM Madrid'
  num_colegiacion text,
  rc_certificate_url text,        -- URL al certificado RC

  -- Empresa asociada (solo constructor o promotor corporativo en V2)
  organization_id uuid,

  -- KYC
  kyc_status      kyc_status NOT NULL DEFAULT 'not_started',
  kyc_verified_at timestamptz,
  kyc_provider    text DEFAULT 'onfido',
  kyc_external_id text,            -- ID en Onfido

  -- Mangopay
  mangopay_user_id text UNIQUE,    -- NaturalUser para personas físicas

  -- Audit
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  last_login_at   timestamptz,
  deleted_at      timestamptz,     -- soft delete RGPD

  -- Marketing opt-in
  marketing_consent_at timestamptz,

  CONSTRAINT users_email_lower CHECK (email = lower(email::text)::citext)
);

CREATE INDEX idx_users_primary_role ON users(primary_role) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_kyc_status ON users(kyc_status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_organization ON users(organization_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_country ON users(country_iso) WHERE deleted_at IS NULL;

COMMENT ON TABLE users IS 'Usuarios de la plataforma. Un usuario tiene un rol primario pero puede aparecer en distintos pactos con roles distintos.';
COMMENT ON COLUMN users.national_id IS 'Cifrado a nivel de aplicación. Solo accesible para Cloud Functions con permisos KYC.';

CREATE TABLE organizations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name      text NOT NULL,
  trade_name      text,
  cif             text NOT NULL UNIQUE,
  address_line    text,
  postal_code     text,
  city            text,
  province        text,
  country_iso     char(2) NOT NULL DEFAULT 'ES',
  registry        text,                -- Registro Mercantil
  registry_number text,

  -- Beneficiarios reales (UBOs) — JSONB para flexibilidad
  beneficial_owners jsonb,             -- [{full_name, dni, ownership_pct, ...}]

  -- KYB
  kyb_status      kyc_status NOT NULL DEFAULT 'not_started',
  kyb_verified_at timestamptz,
  kyb_provider    text DEFAULT 'onfido',

  -- Mangopay
  mangopay_user_id text UNIQUE,         -- LegalUser

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

ALTER TABLE users ADD CONSTRAINT users_organization_fk FOREIGN KEY (organization_id) REFERENCES organizations(id);

CREATE INDEX idx_organizations_kyb_status ON organizations(kyb_status) WHERE deleted_at IS NULL;

-- =====================================================================
-- 2. CONSENTIMIENTOS LEGALES (RGPD trazabilidad)
-- =====================================================================

CREATE TABLE legal_consents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doc_type        legal_doc_type NOT NULL,
  doc_version     text NOT NULL,           -- ej. '1.0.2'
  doc_hash        text NOT NULL,           -- SHA-256 del documento aceptado
  consented_at    timestamptz NOT NULL DEFAULT now(),
  ip_address      inet,
  user_agent      text,
  revoked_at      timestamptz              -- para consentimientos revocables (marketing)
);

CREATE INDEX idx_legal_consents_user ON legal_consents(user_id, doc_type);
CREATE UNIQUE INDEX idx_legal_consents_user_doc_active ON legal_consents(user_id, doc_type)
  WHERE revoked_at IS NULL;

COMMENT ON TABLE legal_consents IS 'Trazabilidad de aceptación de Términos, Privacidad, Cookies y Consentimiento Biométrico. Append-only.';

-- =====================================================================
-- 3. PACTOS
-- =====================================================================

CREATE TABLE pacts (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_id          text NOT NULL UNIQUE,           -- 'PS-PCT-241014-001'

  -- Información de la obra
  title               text NOT NULL,
  description         text,
  obra_address_line   text NOT NULL,
  obra_postal_code    text,
  obra_city           text NOT NULL,
  obra_province       text,
  obra_country_iso    char(2) NOT NULL DEFAULT 'ES',
  obra_cadastral_ref  text,
  obra_type           text,            -- 'reforma_integral', 'reforma_parcial', 'obra_menor'

  -- Económico (en céntimos de EUR)
  total_amount_cents  bigint NOT NULL CHECK (total_amount_cents > 0),
  iva_rate_pct        numeric(4,2) NOT NULL DEFAULT 21.00,  -- 10.00 reducido, 21.00 general
  iva_included        boolean NOT NULL DEFAULT false,
  total_with_iva_cents bigint GENERATED ALWAYS AS (
    CASE WHEN iva_included THEN total_amount_cents
         ELSE total_amount_cents + ROUND(total_amount_cents * iva_rate_pct / 100)
    END
  ) STORED,
  platform_fee_pct    numeric(4,2) NOT NULL DEFAULT 1.00,    -- comisión PactStream

  -- Fechas
  estimated_start_date date,
  estimated_end_date  date,

  -- Estado
  state               pact_state NOT NULL DEFAULT 'draft',
  state_updated_at    timestamptz NOT NULL DEFAULT now(),

  -- Modalidad de pago
  funding_mode        text NOT NULL DEFAULT 'fund_first'
                      CHECK (funding_mode IN ('fund_first', 'pay_per_milestone')),

  -- Custodia
  mangopay_wallet_id  text UNIQUE,
  iban_custodia       text,

  -- Documento del contrato firmado
  master_contract_doc_id uuid,         -- FK a documents tras firma

  -- Audit
  created_by_user_id  uuid NOT NULL REFERENCES users(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  closed_at           timestamptz,

  CONSTRAINT pacts_iva_rate_valid CHECK (iva_rate_pct IN (0, 4, 10, 21))
);

CREATE INDEX idx_pacts_state ON pacts(state);
CREATE INDEX idx_pacts_created_by ON pacts(created_by_user_id);
CREATE INDEX idx_pacts_obra_city ON pacts(obra_city);

COMMENT ON TABLE pacts IS 'Acuerdo tripartito. Fuente de verdad del estado del pacto. Las transiciones de state se validan por trigger.';
COMMENT ON COLUMN pacts.platform_fee_pct IS 'Comisión PactStream sobre cada hito liberado. Editable desde admin.';

-- =====================================================================
-- 4. RELACIÓN DE PARTES AL PACTO
-- =====================================================================

CREATE TABLE pact_parties (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  user_id         uuid REFERENCES users(id),
  organization_id uuid REFERENCES organizations(id),
  role            pact_party_role NOT NULL,

  -- Estado de la invitación
  invited_at      timestamptz NOT NULL DEFAULT now(),
  invited_by_user_id uuid REFERENCES users(id),
  accepted_at     timestamptz,            -- cuando acepta la invitación
  signed_at       timestamptz,            -- cuando firma el contrato

  -- Datos snapshot al momento de la firma (inmutables)
  snapshot_full_name text,
  snapshot_id_number text,
  snapshot_email     citext,
  snapshot_role_data jsonb,                -- ej. número colegiación, CIF, etc.

  -- Firma del contrato
  signaturit_signature_id text,
  signature_state signature_state DEFAULT 'requested',

  CONSTRAINT pact_parties_unique_role_per_pact UNIQUE (pact_id, role),
  CONSTRAINT pact_parties_user_or_org CHECK (
    (user_id IS NOT NULL AND organization_id IS NULL) OR
    (user_id IS NULL AND organization_id IS NOT NULL) OR
    (user_id IS NOT NULL AND organization_id IS NOT NULL)
  )
);

CREATE INDEX idx_pact_parties_pact ON pact_parties(pact_id);
CREATE INDEX idx_pact_parties_user ON pact_parties(user_id);
CREATE INDEX idx_pact_parties_org ON pact_parties(organization_id);

COMMENT ON TABLE pact_parties IS 'Relación user/org → pact con su rol. Snapshot inmutable de los datos al momento de la firma.';

-- =====================================================================
-- 5. HITOS (MILESTONES)
-- =====================================================================

CREATE TABLE milestones (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  display_id      text NOT NULL,             -- 'PS-HIT-241014-001'
  ordinal         smallint NOT NULL,         -- número de hito 1..n
  name            text NOT NULL,
  description     text,
  amount_cents    bigint NOT NULL CHECK (amount_cents > 0),
  target_date     date,

  -- Especificaciones técnicas (estructuradas)
  technical_specs jsonb,                      -- [{spec_id, description, mandatory}]
  critical_checks jsonb,                      -- checklist que el técnico debe validar

  -- Estado
  state           milestone_state NOT NULL DEFAULT 'pending',
  state_updated_at timestamptz NOT NULL DEFAULT now(),

  -- Plazo de objeción del promotor (en horas hábiles desde validación técnica)
  objection_window_hours smallint NOT NULL DEFAULT 48,

  -- Marca temporales clave
  started_at      timestamptz,                -- pasa a in_execution
  submitted_at    timestamptz,                -- constructor declara ready_for_review
  validated_at    timestamptz,                -- técnico aprueba
  approved_by_promotor_at timestamptz,        -- promotor acepta o se cumple plazo silencioso
  rejected_at     timestamptz,
  paid_at         timestamptz,

  -- Pago liberado
  payment_id      uuid,

  created_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT milestones_ordinal_per_pact UNIQUE (pact_id, ordinal),
  CONSTRAINT milestones_display_id_unique UNIQUE (display_id)
);

CREATE INDEX idx_milestones_pact ON milestones(pact_id);
CREATE INDEX idx_milestones_state ON milestones(state);
CREATE INDEX idx_milestones_target_date ON milestones(target_date);

COMMENT ON TABLE milestones IS 'Hitos del pacto. Suma de amount_cents debe igualar el total del pacto (validar por trigger).';

-- Trigger para asegurar que la suma de hitos = total del pacto cuando el pacto pasa a 'signed'
-- (implementación en código de aplicación)

-- =====================================================================
-- 6. EVIDENCIAS DE HITOS (APPEND-ONLY)
-- =====================================================================

CREATE TABLE milestone_evidences (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id    uuid NOT NULL REFERENCES milestones(id) ON DELETE RESTRICT,
  uploaded_by_user_id uuid NOT NULL REFERENCES users(id),
  evidence_type   evidence_type NOT NULL,

  -- Archivo
  storage_path    text NOT NULL,             -- supabase storage path o S3 key
  file_size_bytes bigint,
  mime_type       text,
  sha256_hash     text NOT NULL,             -- hash del archivo, calculado en cliente
  exif_metadata   jsonb,                     -- EXIF completo (cámara, GPS, timestamp)

  -- Geolocalización
  gps_latitude    numeric(10, 7),
  gps_longitude   numeric(10, 7),
  gps_accuracy_meters numeric(8, 2),
  obra_distance_meters numeric(10, 2),       -- distancia al centro de obra calculada
  geolocation_verification evidence_verification NOT NULL DEFAULT 'verified',

  -- Sellado temporal
  client_timestamp timestamptz,              -- timestamp del cliente al capturar
  server_timestamp timestamptz NOT NULL DEFAULT now(),  -- inmutable, timestamp del servidor
  tsa_timestamp_token text,                  -- token de la TSA cualificada
  tsa_provider    text DEFAULT 'signaturit_tsa',

  -- Descripción libre
  description     text,
  technical_notes text,                      -- 'algo que el técnico deba saber'

  -- Estado de la evidencia (puede ser superseded si rechazada y resubida)
  is_superseded   boolean NOT NULL DEFAULT false,
  superseded_by_id uuid,
  superseded_at   timestamptz,

  CONSTRAINT milestone_evidences_no_update CHECK (1 = 1)  -- placeholder para política RLS append-only
);

CREATE INDEX idx_milestone_evidences_milestone ON milestone_evidences(milestone_id);
CREATE INDEX idx_milestone_evidences_uploader ON milestone_evidences(uploaded_by_user_id);
CREATE INDEX idx_milestone_evidences_active ON milestone_evidences(milestone_id) WHERE NOT is_superseded;

-- TRIGGER: prevenir UPDATE y DELETE en milestone_evidences (excepto el flag is_superseded vía función específica)
CREATE OR REPLACE FUNCTION prevent_evidence_modification()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Las evidencias son append-only. No se permiten DELETE.';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    -- Permitir solo cambio de is_superseded y superseded_by_id (vía función específica)
    IF NEW.id != OLD.id OR NEW.milestone_id != OLD.milestone_id OR
       NEW.uploaded_by_user_id != OLD.uploaded_by_user_id OR
       NEW.sha256_hash != OLD.sha256_hash OR NEW.server_timestamp != OLD.server_timestamp OR
       NEW.gps_latitude IS DISTINCT FROM OLD.gps_latitude OR
       NEW.gps_longitude IS DISTINCT FROM OLD.gps_longitude OR
       NEW.exif_metadata::text != OLD.exif_metadata::text THEN
      RAISE EXCEPTION 'Los datos forenses de la evidencia son inmutables.';
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_evidence_immutable
BEFORE UPDATE OR DELETE ON milestone_evidences
FOR EACH ROW EXECUTE FUNCTION prevent_evidence_modification();

COMMENT ON TABLE milestone_evidences IS 'Evidencias del trabajo. APPEND-ONLY: timestamp servidor, GPS y hash son inmutables. Solo se puede marcar como superseded.';

-- =====================================================================
-- 7. VALIDACIONES TÉCNICAS
-- =====================================================================

CREATE TABLE milestone_validations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id    uuid NOT NULL REFERENCES milestones(id),
  validator_user_id uuid NOT NULL REFERENCES users(id),  -- Técnico
  decision        validation_decision NOT NULL,
  decision_at     timestamptz NOT NULL DEFAULT now(),
  rationale       text,                       -- motivo del rechazo o petición de info
  technical_specs_check jsonb,                -- {spec_id: passed/failed/notes}
  critical_checks_check jsonb,                -- {check_id: passed/failed/notes}

  -- Si solicita más información
  requested_info_categories text[],           -- ['photo', 'docs', 'specs', 'other']
  requested_info_text text,

  -- Certificado generado
  certificate_doc_id uuid                     -- FK a documents
);

CREATE INDEX idx_milestone_validations_milestone ON milestone_validations(milestone_id);
CREATE INDEX idx_milestone_validations_validator ON milestone_validations(validator_user_id);

-- =====================================================================
-- 8. OBJECIONES Y DISPUTAS
-- =====================================================================

CREATE TABLE milestone_objections (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id    uuid NOT NULL REFERENCES milestones(id),
  raised_by_user_id uuid NOT NULL REFERENCES users(id),  -- Promotor
  raised_at       timestamptz NOT NULL DEFAULT now(),
  reason_categories text[] NOT NULL,           -- ['incomplete', 'low_quality', 'wrong_materials', 'delayed', 'spec_mismatch', 'other']
  reason_detail   text NOT NULL,
  resulting_dispute_id uuid                    -- FK a disputes (si escala)
);

CREATE TABLE disputes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_id      text NOT NULL UNIQUE,        -- 'PS-DSP-241014-001'
  pact_id         uuid NOT NULL REFERENCES pacts(id),
  milestone_id    uuid NOT NULL REFERENCES milestones(id),
  amount_held_cents bigint NOT NULL,
  state           dispute_state NOT NULL DEFAULT 'opened',
  state_updated_at timestamptz NOT NULL DEFAULT now(),

  -- Plazos
  opened_at       timestamptz NOT NULL DEFAULT now(),
  first_response_due_at timestamptz NOT NULL,  -- 24h
  resolution_due_at timestamptz NOT NULL,      -- 10 días naturales

  -- Resolución
  outcome         dispute_outcome NOT NULL DEFAULT 'pending',
  outcome_amount_to_constructor_cents bigint DEFAULT 0,
  outcome_amount_refund_promotor_cents bigint DEFAULT 0,
  outcome_rationale text,
  resolved_at     timestamptz,
  resolution_doc_id uuid,                       -- PDF informe firmado

  -- Aceptaciones
  accepted_by_promotor_at timestamptz,
  accepted_by_constructor_at timestamptz,
  accepted_by_tecnico_at timestamptz,

  closed_at       timestamptz
);

CREATE INDEX idx_disputes_pact ON disputes(pact_id);
CREATE INDEX idx_disputes_state ON disputes(state);
CREATE INDEX idx_disputes_milestone ON disputes(milestone_id);

ALTER TABLE milestone_objections ADD CONSTRAINT objections_dispute_fk
  FOREIGN KEY (resulting_dispute_id) REFERENCES disputes(id);

CREATE TABLE dispute_contributions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id      uuid NOT NULL REFERENCES disputes(id) ON DELETE CASCADE,
  contributor_user_id uuid NOT NULL REFERENCES users(id),
  contributor_role pact_party_role NOT NULL,
  contribution_text text,
  attached_evidence_ids uuid[],                -- referencias a milestone_evidences extras aportadas
  attached_doc_ids uuid[],                     -- referencias a documents
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_dispute_contributions_dispute ON dispute_contributions(dispute_id);

-- =====================================================================
-- 9. DOCUMENTOS Y FIRMAS
-- =====================================================================

CREATE TABLE documents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid REFERENCES pacts(id) ON DELETE CASCADE,
  doc_type        document_type NOT NULL,
  display_id      text,                         -- 'PS-DOC-XXX'

  -- Archivo
  storage_path    text NOT NULL,
  file_size_bytes bigint,
  mime_type       text NOT NULL DEFAULT 'application/pdf',
  sha256_hash     text NOT NULL,
  pages           smallint,

  -- Origen
  generated_by    text,                          -- 'system' | 'user_upload' | 'integration'
  uploaded_by_user_id uuid REFERENCES users(id),

  -- Firma
  signature_id    uuid,                          -- FK a signatures
  signed_at       timestamptz,

  -- Audit
  created_at      timestamptz NOT NULL DEFAULT now(),

  -- Retención (10 años por LOE)
  retention_until timestamptz NOT NULL DEFAULT (now() + INTERVAL '10 years')
);

CREATE INDEX idx_documents_pact ON documents(pact_id);
CREATE INDEX idx_documents_type ON documents(doc_type);

CREATE TABLE signatures (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id         uuid NOT NULL REFERENCES documents(id),
  signaturit_doc_id   text NOT NULL UNIQUE,    -- referencia en Signaturit
  state               signature_state NOT NULL DEFAULT 'requested',

  -- Plazos
  requested_at        timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz,
  completed_at        timestamptz,

  -- Sellado temporal cualificado
  tsa_timestamp_token text,
  tsa_provider        text,

  -- Hash final del PDF firmado
  final_pdf_sha256    text
);

CREATE TABLE signature_signers (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  signature_id        uuid NOT NULL REFERENCES signatures(id) ON DELETE CASCADE,
  user_id             uuid NOT NULL REFERENCES users(id),
  signer_role         pact_party_role NOT NULL,
  ordinal             smallint NOT NULL,        -- orden de firma
  signed_at           timestamptz,
  ip_address          inet,
  biometric_data_consent_at timestamptz,        -- consentimiento art.9 RGPD
  signaturit_signer_id text
);

ALTER TABLE documents ADD CONSTRAINT documents_signature_fk
  FOREIGN KEY (signature_id) REFERENCES signatures(id);

ALTER TABLE pacts ADD CONSTRAINT pacts_master_contract_fk
  FOREIGN KEY (master_contract_doc_id) REFERENCES documents(id);

ALTER TABLE milestone_validations ADD CONSTRAINT milestone_validations_certificate_fk
  FOREIGN KEY (certificate_doc_id) REFERENCES documents(id);

ALTER TABLE disputes ADD CONSTRAINT disputes_resolution_doc_fk
  FOREIGN KEY (resolution_doc_id) REFERENCES documents(id);

-- =====================================================================
-- 10. PAGOS (referencias a Mangopay)
-- =====================================================================

CREATE TABLE payments (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id                 uuid NOT NULL REFERENCES pacts(id),
  milestone_id            uuid REFERENCES milestones(id),
  payment_type            payment_type NOT NULL,
  amount_cents            bigint NOT NULL,
  fee_cents               bigint NOT NULL DEFAULT 0,
  net_amount_cents        bigint GENERATED ALWAYS AS (amount_cents - fee_cents) STORED,
  state                   payment_state NOT NULL DEFAULT 'created',

  -- Origen / destino
  source_user_id          uuid REFERENCES users(id),
  source_org_id           uuid REFERENCES organizations(id),
  destination_user_id     uuid REFERENCES users(id),
  destination_org_id      uuid REFERENCES organizations(id),

  -- Referencias Mangopay (idempotencia + trazabilidad)
  mangopay_transaction_id text UNIQUE,
  mangopay_wallet_id      text,
  idempotency_key         text NOT NULL UNIQUE,

  -- Webhooks recibidos
  last_webhook_at         timestamptz,

  created_at              timestamptz NOT NULL DEFAULT now(),
  succeeded_at            timestamptz,
  failed_at               timestamptz,
  failure_reason          text
);

CREATE INDEX idx_payments_pact ON payments(pact_id);
CREATE INDEX idx_payments_milestone ON payments(milestone_id);
CREATE INDEX idx_payments_state ON payments(state);
CREATE INDEX idx_payments_type ON payments(payment_type);

ALTER TABLE milestones ADD CONSTRAINT milestones_payment_fk
  FOREIGN KEY (payment_id) REFERENCES payments(id);

-- =====================================================================
-- 11. CONVERSACIONES Y MENSAJES
-- =====================================================================

CREATE TABLE conversations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  -- Una conversación por pacto en MVP. En V2 podrían existir hilos por hito.
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conversations_pact_unique UNIQUE (pact_id)
);

CREATE TABLE messages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_user_id  uuid REFERENCES users(id),
  -- Si es null, es evento del sistema
  is_system_event boolean NOT NULL DEFAULT false,
  event_type      text,                         -- 'pact_signed', 'milestone_validated', etc.
  body            text,
  attached_doc_ids uuid[],
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);
CREATE INDEX idx_messages_sender ON messages(sender_user_id);

-- =====================================================================
-- 12. NOTIFICACIONES
-- =====================================================================

CREATE TABLE notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pact_id         uuid REFERENCES pacts(id),
  milestone_id    uuid REFERENCES milestones(id),
  notification_type text NOT NULL,              -- 'payment_released', 'milestone_validated', 'dispute_opened', etc.
  channel         notification_channel NOT NULL,
  priority        notification_priority NOT NULL DEFAULT 'normal',
  title           text NOT NULL,
  body            text NOT NULL,
  cta_url         text,                          -- deep link
  -- Estados
  sent_at         timestamptz,
  read_at         timestamptz,
  clicked_at      timestamptz,
  failed_at       timestamptz,
  failure_reason  text,
  -- Idempotencia
  idempotency_key text UNIQUE,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE read_at IS NULL;

-- =====================================================================
-- 13. RATINGS (Salud del proyecto y Reputación PactStream)
-- =====================================================================

-- Salud del proyecto: por pacto, recalculado al cierre o periódicamente
CREATE TABLE pact_health_scores (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  score           smallint NOT NULL CHECK (score BETWEEN 0 AND 100),
  -- Componentes
  milestone_compliance_pct numeric(5,2),         -- % hitos cumplidos en plazo
  evidence_validity_pct numeric(5,2),            -- % evidencias verificadas
  validation_speed_pct numeric(5,2),             -- velocidad de validación
  no_disputes_pct numeric(5,2),                  -- ausencia de disputas
  -- Fecha de cálculo (snapshot)
  calculated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pact_health_scores_pact_calc UNIQUE (pact_id, calculated_at)
);

CREATE INDEX idx_pact_health_scores_pact ON pact_health_scores(pact_id, calculated_at DESC);

-- Reputación PactStream: por usuario, recalculado periódicamente
CREATE TABLE user_reputations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role            user_role NOT NULL,            -- el rating depende del rol
  score           smallint NOT NULL CHECK (score BETWEEN 0 AND 100),
  tier            text NOT NULL CHECK (tier IN ('bronce', 'plata', 'oro', 'platino', 'elite')),
  -- Componentes específicos por rol (JSONB para flexibilidad)
  components      jsonb NOT NULL,
  -- Histórico
  pacts_total     smallint NOT NULL DEFAULT 0,
  pacts_completed smallint NOT NULL DEFAULT 0,
  pacts_disputed  smallint NOT NULL DEFAULT 0,
  calculated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_reputations_user ON user_reputations(user_id, calculated_at DESC);
CREATE INDEX idx_user_reputations_tier ON user_reputations(tier);

-- =====================================================================
-- 14. EVENT LOG (event sourcing) Y AUDIT
-- =====================================================================

CREATE TABLE pact_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  event_type      text NOT NULL,
  event_version   smallint NOT NULL DEFAULT 1,
  payload         jsonb NOT NULL,                -- estado nuevo + diff
  actor_user_id   uuid REFERENCES users(id),
  actor_type      text DEFAULT 'user',           -- 'user' | 'system' | 'admin' | 'webhook'
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  -- Inmutable
  CONSTRAINT pact_events_no_modification CHECK (1 = 1)
);

CREATE INDEX idx_pact_events_pact ON pact_events(pact_id, occurred_at);
CREATE INDEX idx_pact_events_type ON pact_events(event_type);

CREATE OR REPLACE FUNCTION prevent_event_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'pact_events es append-only.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_events_immutable
BEFORE UPDATE OR DELETE ON pact_events
FOR EACH ROW EXECUTE FUNCTION prevent_event_modification();

COMMENT ON TABLE pact_events IS 'Event log apéndice-solo del pacto. Fuente de verdad para reconstruir estado.';

-- Transiciones de estado del pacto (con validación)
CREATE TABLE pact_state_transitions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id         uuid NOT NULL REFERENCES pacts(id) ON DELETE CASCADE,
  from_state      pact_state,
  to_state        pact_state NOT NULL,
  transitioned_by_user_id uuid REFERENCES users(id),
  reason          text,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_pact_state_transitions_pact ON pact_state_transitions(pact_id, occurred_at);

CREATE TABLE milestone_state_transitions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id    uuid NOT NULL REFERENCES milestones(id) ON DELETE CASCADE,
  from_state      milestone_state,
  to_state        milestone_state NOT NULL,
  transitioned_by_user_id uuid REFERENCES users(id),
  reason          text,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_milestone_state_transitions_milestone ON milestone_state_transitions(milestone_id, occurred_at);

-- Audit log general
CREATE TABLE audit_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id   uuid REFERENCES users(id),
  action          text NOT NULL,                 -- 'login', 'created_pact', 'admin_freeze_milestone', etc.
  entity_type     text,
  entity_id       uuid,
  ip_address      inet,
  user_agent      text,
  metadata        jsonb,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_actor ON audit_log(actor_user_id, occurred_at DESC);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);

-- =====================================================================
-- 15. INTEGRACIONES (idempotencia de webhooks)
-- =====================================================================

CREATE TABLE webhook_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider        text NOT NULL,                  -- 'mangopay' | 'onfido' | 'signaturit'
  external_id     text NOT NULL,
  event_type      text NOT NULL,
  payload         jsonb NOT NULL,
  signature_valid boolean,
  processed_at    timestamptz,
  processed_result text,                          -- 'success' | 'error' | 'ignored'
  received_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT webhook_events_unique_per_provider UNIQUE (provider, external_id)
);

CREATE INDEX idx_webhook_events_provider ON webhook_events(provider, processed_at);
CREATE INDEX idx_webhook_events_unprocessed ON webhook_events(provider) WHERE processed_at IS NULL;

-- =====================================================================
-- 16. ROW LEVEL SECURITY (Supabase / Postgres native)
-- =====================================================================

-- Habilitar RLS en todas las tablas con datos sensibles
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE pacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pact_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestone_evidences ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestone_validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestone_objections ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispute_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE signature_signers ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE pact_health_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reputations ENABLE ROW LEVEL SECURITY;
ALTER TABLE pact_events ENABLE ROW LEVEL SECURITY;

-- Función auxiliar para obtener el user_id desde JWT (Supabase auth)
CREATE OR REPLACE FUNCTION current_user_id() RETURNS uuid AS $$
  SELECT (current_setting('request.jwt.claims', true)::json->>'sub')::uuid
$$ LANGUAGE sql STABLE;

-- Función: ¿está user_id en este pacto?
CREATE OR REPLACE FUNCTION user_in_pact(p_pact_id uuid, p_user_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM pact_parties pp
    WHERE pp.pact_id = p_pact_id
    AND (pp.user_id = p_user_id
         OR (pp.organization_id IS NOT NULL AND pp.organization_id IN
             (SELECT organization_id FROM users WHERE id = p_user_id AND organization_id IS NOT NULL)))
  )
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- POLÍTICAS USERS — un usuario solo se ve a sí mismo (admin tiene bypass)
CREATE POLICY users_self_select ON users FOR SELECT USING (id = current_user_id());
CREATE POLICY users_self_update ON users FOR UPDATE USING (id = current_user_id());

-- POLÍTICAS PACTS — solo partes del pacto pueden leer
CREATE POLICY pacts_party_select ON pacts FOR SELECT
  USING (user_in_pact(id, current_user_id()));

CREATE POLICY pacts_creator_insert ON pacts FOR INSERT
  WITH CHECK (created_by_user_id = current_user_id());

-- Las escrituras a state, importe, hitos, etc. solo desde Cloud Functions con SECURITY DEFINER
CREATE POLICY pacts_no_direct_update ON pacts FOR UPDATE USING (false);

-- POLÍTICAS PACT_PARTIES — un usuario ve las parties de los pactos en los que está
CREATE POLICY pact_parties_party_select ON pact_parties FOR SELECT
  USING (user_in_pact(pact_id, current_user_id()));

-- POLÍTICAS MILESTONES — solo partes del pacto
CREATE POLICY milestones_party_select ON milestones FOR SELECT
  USING (user_in_pact(pact_id, current_user_id()));

-- POLÍTICAS EVIDENCES — solo partes del pacto, append-only
CREATE POLICY evidences_party_select ON milestone_evidences FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM milestones m
      WHERE m.id = milestone_evidences.milestone_id
      AND user_in_pact(m.pact_id, current_user_id())
    )
  );

-- Solo el constructor del pacto puede insertar evidencias
CREATE POLICY evidences_constructor_insert ON milestone_evidences FOR INSERT
  WITH CHECK (
    uploaded_by_user_id = current_user_id()
    AND EXISTS (
      SELECT 1 FROM milestones m
      JOIN pact_parties pp ON pp.pact_id = m.pact_id
      WHERE m.id = milestone_id
      AND pp.role = 'constructor'
      AND (pp.user_id = current_user_id()
           OR pp.organization_id IN (SELECT organization_id FROM users WHERE id = current_user_id()))
    )
  );

-- POLÍTICAS NOTIFICATIONS — un usuario solo sus propias notificaciones
CREATE POLICY notifications_self_select ON notifications FOR SELECT
  USING (user_id = current_user_id());
CREATE POLICY notifications_self_update ON notifications FOR UPDATE
  USING (user_id = current_user_id());

-- Las demás tablas siguen el patrón "partes del pacto" o "self" — añadir según se desarrolle.

-- =====================================================================
-- 17. VIEWS ÚTILES
-- =====================================================================

-- Vista: pactos activos de un usuario (para listas tipo "Mis Obras")
-- Los pactos no tienen soft delete; se rigen por la máquina de estados
-- (closed/cancelled son los estados terminales).
CREATE OR REPLACE VIEW v_user_active_pacts AS
SELECT DISTINCT
  p.*,
  pp.role AS my_role,
  pp.user_id AS my_user_id
FROM pacts p
JOIN pact_parties pp ON pp.pact_id = p.id
WHERE p.state NOT IN ('closed', 'cancelled');

-- Vista: progreso financiero de un pacto
CREATE OR REPLACE VIEW v_pact_financial_progress AS
SELECT
  p.id AS pact_id,
  p.total_amount_cents,
  COALESCE(SUM(m.amount_cents) FILTER (WHERE m.state = 'paid'), 0) AS paid_cents,
  COALESCE(SUM(m.amount_cents) FILTER (WHERE m.state IN ('approved_by_tech', 'awaiting_promotor')), 0) AS approved_pending_release_cents,
  COALESCE(SUM(m.amount_cents) FILTER (WHERE m.state = 'disputed'), 0) AS disputed_cents,
  COALESCE(SUM(m.amount_cents) FILTER (WHERE m.state IN ('pending', 'in_execution', 'ready_for_review', 'in_validation', 'info_requested')), 0) AS in_custody_cents
FROM pacts p
LEFT JOIN milestones m ON m.pact_id = p.id
GROUP BY p.id, p.total_amount_cents;

-- =====================================================================
-- 18. TRIGGERS DE INTEGRIDAD
-- =====================================================================

-- Trigger: actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_pacts_updated_at BEFORE UPDATE ON pacts FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger: validar transición de estado del pacto
CREATE OR REPLACE FUNCTION validate_pact_state_transition()
RETURNS TRIGGER AS $$
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
    WHEN 'in_execution' THEN ARRAY['disputed', 'suspended', 'completed']
    WHEN 'disputed' THEN ARRAY['in_execution', 'suspended']
    WHEN 'suspended' THEN ARRAY['in_execution', 'cancelled']
    WHEN 'completed' THEN ARRAY['closed']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (NEW.state::text = ANY(valid_transitions)) THEN
    RAISE EXCEPTION 'Transición de estado inválida: % → %', OLD.state, NEW.state;
  END IF;

  -- Insertar transición en log
  INSERT INTO pact_state_transitions(pact_id, from_state, to_state, transitioned_by_user_id)
  VALUES (NEW.id, OLD.state, NEW.state, current_user_id());

  NEW.state_updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pact_state_transition BEFORE UPDATE OF state ON pacts
FOR EACH ROW EXECUTE FUNCTION validate_pact_state_transition();

-- Trigger similar para milestones (versión simplificada)
CREATE OR REPLACE FUNCTION validate_milestone_state_transition()
RETURNS TRIGGER AS $$
DECLARE
  valid_transitions text[];
BEGIN
  IF OLD.state = NEW.state THEN
    RETURN NEW;
  END IF;

  valid_transitions := CASE OLD.state
    WHEN 'pending' THEN ARRAY['in_execution']
    WHEN 'in_execution' THEN ARRAY['ready_for_review']
    WHEN 'ready_for_review' THEN ARRAY['in_validation']
    WHEN 'in_validation' THEN ARRAY['approved_by_tech', 'rejected_by_tech', 'info_requested']
    WHEN 'info_requested' THEN ARRAY['ready_for_review']
    WHEN 'rejected_by_tech' THEN ARRAY['in_execution', 'disputed']
    WHEN 'approved_by_tech' THEN ARRAY['awaiting_promotor', 'disputed']
    WHEN 'awaiting_promotor' THEN ARRAY['paid', 'disputed']
    WHEN 'disputed' THEN ARRAY['paid', 'awaiting_promotor', 'in_execution']
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_milestone_state_transition BEFORE UPDATE OF state ON milestones
FOR EACH ROW EXECUTE FUNCTION validate_milestone_state_transition();

-- =====================================================================
-- FIN DEL SCHEMA
-- =====================================================================
-- Próximos pasos para el CTO:
-- 1. Decidir: Supabase managed vs RDS self-managed.
-- 2. Crear migrations con sqitch / dbmate / o las migrations propias de Supabase.
-- 3. Implementar las funciones SECURITY DEFINER para escrituras protegidas:
--    - sf_create_pact(...)
--    - sf_invite_party(...)
--    - sf_validate_milestone(...)
--    - sf_release_payment(...)
--    - sf_open_dispute(...)
--    - sf_resolve_dispute(...)
-- 4. Habilitar Realtime en messages, notifications, pact_state_transitions.
-- 5. Programar jobs (pg_cron) para:
--    - Recálculo de pact_health_scores cada noche
--    - Recálculo de user_reputations semanalmente
--    - Auto-liberación de pagos al expirar el plazo de objeción
--    - Detección de inactividad y abandono (D+3, D+7, D+14)
-- 6. Configurar backups: PITR + snapshots diarios con retención 35 días.
-- 7. Configurar replicación de read en Año 2 cuando GMV > 5M€.
