-- =====================================================================
-- Sprint 6 chunk 1 · Migration 0032
-- Organizations + Members (equipos dentro de la empresa)
-- =====================================================================
-- Permite que un constructor o técnico invite a jefes de obra (u otros
-- miembros) para que puedan operar el día a día sin necesidad de que el
-- dueño esté físicamente en cada obra. Las evidencias quedan firmadas
-- por el user real que las captura (cadena de custodia forense intacta).
--
-- Modelo:
--   - Una organización por owner (1:1 en MVP).
--   - 2 roles: owner / member.
--   - Toggle por miembro: can_view_economics (default false).
--   - Sin KYC obligatorio para miembros (solo el owner pasa Veriff).
--   - Compatibilidad: users autónomos sin organización siguen operando
--     exactamente como antes — la organización es opt-in.
--
-- En este chunk solo creamos la infraestructura. La integración con
-- pact_parties y RPCs viene en el chunk 2.
-- =====================================================================


-- =====================================================================
-- 1 · Enums
-- =====================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_member_role') THEN
    CREATE TYPE public.org_member_role AS ENUM ('owner', 'member');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_member_state') THEN
    CREATE TYPE public.org_member_state AS ENUM (
      'invited',     -- email enviado, aún no aceptado
      'active',      -- aceptó la invitación
      'revoked'      -- revocado por el owner o dejó la empresa
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_type') THEN
    CREATE TYPE public.org_type AS ENUM (
      'constructor',
      'tecnico',
      'promotor',
      'mixed'
    );
  END IF;
END$$;


-- =====================================================================
-- 2 · Tabla organizations
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.organizations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identidad legal
  name              text NOT NULL,
  vat_id            text,                       -- CIF / NIF de empresa
  description       text,

  -- Tipo de negocio (define qué pacts puede crear)
  org_type          org_type NOT NULL DEFAULT 'constructor',

  -- Propietario
  owner_user_id     uuid NOT NULL REFERENCES public.users(id),

  -- Audit
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- MVP: una organización por owner
  CONSTRAINT organizations_one_per_owner UNIQUE (owner_user_id)
);

CREATE INDEX IF NOT EXISTS idx_organizations_owner
  ON public.organizations(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_organizations_type
  ON public.organizations(org_type);

COMMENT ON TABLE public.organizations IS
  'Empresa o equipo que agrupa miembros con permisos diferenciados. '
  'En MVP cada user puede tener máximo una organización como owner.';

COMMENT ON COLUMN public.organizations.org_type IS
  'Determina qué tipo de pacts puede operar la organización: '
  'constructor (jefes de obra), tecnico (estudio de arquitectura), '
  'promotor (promotora inmobiliaria con varios responsables).';


-- =====================================================================
-- 3 · Tabla organization_members
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.organization_members (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  -- Identidad del miembro.
  -- user_id es NULL durante la invitación; se rellena cuando acepta.
  user_id           uuid REFERENCES public.users(id),
  invited_email     text NOT NULL,
  full_name         text,                       -- snapshot para mostrar antes de aceptar

  -- Rol y permisos
  role              org_member_role NOT NULL DEFAULT 'member',

  -- Toggle de visibilidad económica (default false: ve solo lo operativo)
  can_view_economics boolean NOT NULL DEFAULT false,

  -- Lifecycle de la invitación
  state             org_member_state NOT NULL DEFAULT 'invited',

  -- Token único para el link de aceptación (se invalida al aceptar)
  invitation_token  uuid NOT NULL DEFAULT gen_random_uuid(),
  invited_by_user_id uuid NOT NULL REFERENCES public.users(id),
  invited_at        timestamptz NOT NULL DEFAULT now(),
  accepted_at       timestamptz,
  revoked_at        timestamptz,
  revoked_reason    text,

  CONSTRAINT org_member_unique_email_per_org
    UNIQUE (organization_id, invited_email)
);

CREATE INDEX IF NOT EXISTS idx_org_members_user
  ON public.organization_members(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_org_members_org
  ON public.organization_members(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_members_token
  ON public.organization_members(invitation_token);
CREATE INDEX IF NOT EXISTS idx_org_members_state
  ON public.organization_members(state);
CREATE INDEX IF NOT EXISTS idx_org_members_active
  ON public.organization_members(organization_id) WHERE state = 'active';

COMMENT ON TABLE public.organization_members IS
  'Membresía dentro de una organización. El owner se crea automáticamente '
  'al crear la organización vía trigger. Los miembros se invitan por email '
  'y se activan al aceptar el link de invitación (no requieren KYC).';

COMMENT ON COLUMN public.organization_members.can_view_economics IS
  'Si true, el miembro puede ver importes, presupuestos y movimientos. '
  'Si false, solo ve datos operativos (evidencias, certificaciones, plazos).';


-- =====================================================================
-- 4 · Trigger · crear miembro owner automáticamente
-- =====================================================================
-- Cuando se crea una organización, el owner se inserta como miembro
-- activo con role='owner' y can_view_economics=true. No necesita
-- invitación.

CREATE OR REPLACE FUNCTION public.fn_create_owner_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_name text;
BEGIN
  SELECT email, full_name INTO v_email, v_name
  FROM public.users WHERE id = NEW.owner_user_id;

  INSERT INTO public.organization_members (
    organization_id, user_id, invited_email, full_name,
    role, can_view_economics, state,
    invited_by_user_id, invited_at, accepted_at
  ) VALUES (
    NEW.id, NEW.owner_user_id, coalesce(v_email, 'unknown@local'), v_name,
    'owner', true, 'active',
    NEW.owner_user_id, now(), now()
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_owner_member ON public.organizations;
CREATE TRIGGER trg_create_owner_member
  AFTER INSERT ON public.organizations
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_create_owner_member();


-- =====================================================================
-- 5 · Trigger · validar que solo haya un owner activo por organización
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_validate_org_single_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'owner' AND NEW.state = 'active' THEN
    IF EXISTS (
      SELECT 1 FROM public.organization_members
      WHERE organization_id = NEW.organization_id
        AND role = 'owner'
        AND state = 'active'
        AND id != coalesce(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) THEN
      RAISE EXCEPTION 'Ya existe un owner activo en la organización %', NEW.organization_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_org_single_owner ON public.organization_members;
CREATE TRIGGER trg_validate_org_single_owner
  BEFORE INSERT OR UPDATE ON public.organization_members
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_validate_org_single_owner();


-- =====================================================================
-- 6 · Helper · ¿el user actual es miembro activo de esta organización?
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_is_org_active_member(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_auth_uid uuid;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.organization_members om
    JOIN public.users u ON u.id = om.user_id
    WHERE om.organization_id = p_org_id
      AND om.state = 'active'
      AND u.auth_provider_id = v_auth_uid::text
      AND u.deleted_at IS NULL
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_is_org_active_member TO authenticated;


-- =====================================================================
-- 7 · RLS de organizations
-- =====================================================================

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS org_select_member ON public.organizations;
CREATE POLICY org_select_member ON public.organizations
  FOR SELECT TO authenticated
  USING (public.fn_is_org_active_member(id));

GRANT SELECT ON public.organizations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.organizations TO service_role;


-- =====================================================================
-- 8 · RLS de organization_members
-- =====================================================================

ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS org_member_select ON public.organization_members;
CREATE POLICY org_member_select ON public.organization_members
  FOR SELECT TO authenticated
  USING (public.fn_is_org_active_member(organization_id));

GRANT SELECT ON public.organization_members TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.organization_members TO service_role;


-- =====================================================================
-- 9 · Comentarios finales y reload de schema cache
-- =====================================================================

COMMENT ON FUNCTION public.fn_is_org_active_member IS
  'Sprint 6 · Helper para RLS: true si el user del contexto auth es '
  'miembro activo de la organización indicada.';

COMMENT ON FUNCTION public.fn_create_owner_member IS
  'Sprint 6 · Trigger que crea automáticamente al owner como miembro '
  'activo cuando se crea una organización.';

NOTIFY pgrst, 'reload schema';
