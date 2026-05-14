-- =====================================================================
-- Sprint 1.5 · Migration 0007
-- Soporte para "obra menor" — pactos bipartitos sin técnico director.
-- =====================================================================
-- Cambio de modelo:
--   - Modelo original: 3 partes obligatorias (Promotor + Constructor + Técnico)
--   - Modelo nuevo: 'obra_mayor' (3 partes) | 'obra_menor' (2 partes, sin técnico)
--
-- Esta migration solo añade los CAMPOS necesarios. La lógica de máquina
-- de estados, contratos bipartitos y validación auto-promotor se
-- implementa cuando se cierren las 4 decisiones legales pendientes
-- (ver Decision-Obra-Menor.docx).
--
-- Compatibilidad: pacts existentes y futuros tienen default 'obra_mayor',
-- así que la app sigue funcionando exactamente igual hasta que activemos
-- la nueva opción en el wizard.
-- =====================================================================

-- ENUM nuevo
CREATE TYPE pact_type AS ENUM ('obra_mayor', 'obra_menor');

-- Columnas nuevas en pacts
ALTER TABLE public.pacts
  ADD COLUMN pact_type pact_type NOT NULL DEFAULT 'obra_mayor',
  ADD COLUMN requires_tecnico boolean NOT NULL DEFAULT true,
  -- Self-declaration legal del usuario para obra menor
  ADD COLUMN obra_menor_declaration_accepted_at timestamptz,
  ADD COLUMN obra_menor_declaration_text_hash text;

COMMENT ON COLUMN public.pacts.pact_type IS
  'obra_mayor (3 partes) | obra_menor (2 partes sin técnico). Default obra_mayor.';
COMMENT ON COLUMN public.pacts.requires_tecnico IS
  'Derivado de pact_type vía trigger. true para obra_mayor, false para obra_menor.';
COMMENT ON COLUMN public.pacts.obra_menor_declaration_accepted_at IS
  'Timestamp en que el promotor aceptó la declaración responsable de que la obra es menor y asume responsabilidad legal de la calificación.';

-- Trigger: sincronizar requires_tecnico con pact_type
CREATE OR REPLACE FUNCTION public.sync_pact_type_requires_tecnico()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.requires_tecnico := (NEW.pact_type = 'obra_mayor');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_pact_type_requires_tecnico
  BEFORE INSERT OR UPDATE OF pact_type ON public.pacts
  FOR EACH ROW EXECUTE FUNCTION public.sync_pact_type_requires_tecnico();

-- Validación: obra_menor requiere declaración legal aceptada
ALTER TABLE public.pacts
  ADD CONSTRAINT pacts_obra_menor_requires_declaration CHECK (
    pact_type = 'obra_mayor' OR
    (pact_type = 'obra_menor' AND obra_menor_declaration_accepted_at IS NOT NULL)
  );

-- Comisión diferenciada por tipo (0.8% obra menor vs 1% obra mayor)
-- Se aplica en el wizard de creación; no es trigger porque puede haber
-- promociones puntuales que sobreescriban.
ALTER TABLE public.pacts
  ALTER COLUMN platform_fee_pct SET DEFAULT 1.00;

-- Vista de utilidad: pactos donde el usuario actual es parte, con tipo
CREATE OR REPLACE VIEW public.v_my_pacts_summary AS
SELECT
  p.id,
  p.display_id,
  p.title,
  p.state,
  p.pact_type,
  p.total_amount_cents,
  p.requires_tecnico,
  pp.role AS my_role,
  p.created_at
FROM public.pacts p
JOIN public.pact_parties pp ON pp.pact_id = p.id
WHERE pp.user_id = (
  SELECT id FROM public.users WHERE auth_provider_id = (auth.uid())::text
)
AND p.state NOT IN ('closed', 'cancelled');

COMMENT ON VIEW public.v_my_pacts_summary IS
  'Pactos activos donde el usuario actual es parte, con su rol y tipo de pacto.';
