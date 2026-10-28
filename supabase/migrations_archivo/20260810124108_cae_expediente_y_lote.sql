-- =====================================================================
-- Vertical CAE · expediente, lote y requisitos
--
-- Spec: docs/superpowers/specs/2026-08-10-expediente-y-lote-cae-design.md
--
-- Tres ideas que explican el diseño:
--
--  1. EL EXPEDIENTE NO CUELGA DE UN PACTO. Un pacto vive alrededor del escrow,
--     que sigue sin licencia. Si el expediente lo exigiera, el vertical entero
--     heredaría ese bloqueo. Cuelga de la ORGANIZACIÓN y enlaza con un pacto
--     solo si existe (`pact_id` nulo por defecto).
--
--  2. EL LOTE ES LA UNIDAD DE VALOR, no la obra. La Orden TED/815/2023 exige
--     30 MWh por solicitud (art. 14.6) y que lo agrupado sea del mismo año y
--     la misma comunidad autónoma (art. 14.3). Eso se impone con disparadores
--     por LOS DOS LADOS: es una regla legal, no una preferencia de interfaz.
--
--  3. LA PUERTA DEL CERTIFICADO PREVIO ES BLOQUEO DURO, y vive en la base.
--     Un bloqueo que solo existe en el front no es un bloqueo: cualquier
--     llamada directa a la API se lo salta.
--
-- Revisión adversarial previa a aplicar (10-ago-2026). Encontró tres huecos
-- críticos que están cerrados aquí y quedan anotados donde se cierran:
--   · la puerta no cubría el INSERT (se podía NACER en `en_ejecucion`)
--   · la puerta solo miraba el par exacto `borrador → en_ejecucion`
--   · nadie vigilaba `cae_lotes`: cambiar la comunidad del lote rompía el 14.3
-- =====================================================================


-- ─── 1 · Tipos ────────────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE public.cae_estado_expediente AS ENUM (
    'borrador', 'en_ejecucion', 'documentado', 'en_lote', 'entregado'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.cae_estado_lote AS ENUM ('abierto', 'listo', 'entregado');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.cae_estado_requisito AS ENUM (
    'pendiente', 'aportado', 'verificado', 'rechazado'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- La comunidad se compara por igualdad de texto para agrupar el lote, así que
-- una mal escrita crea un grupo paralelo sin avisar. Va en un DOMINIO y no en
-- dos CHECK copiados: con la lista duplicada, editar una y olvidar la otra es
-- cuestión de tiempo.
--
-- ⚠️ Sigue siendo la etiqueta, no el código del INE. Es deuda consciente: si
-- algún día hay que traducir los rótulos o aceptar denominaciones alternativas
-- («Baleares», «Comunidad de Madrid»), toca tabla de referencia y migración.
DO $$ BEGIN
  CREATE DOMAIN public.cae_comunidad AS text
    CHECK (VALUE IN (
      'Andalucía','Aragón','Asturias','Illes Balears','Canarias','Cantabria',
      'Castilla-La Mancha','Castilla y León','Cataluña','Comunitat Valenciana',
      'Extremadura','Galicia','La Rioja','Madrid','Murcia','Navarra',
      'País Vasco','Ceuta','Melilla'
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ─── 2 · La clave del certificado previo, en UN solo sitio ────────────
--
-- Si el disparador teclea la cadena a mano y no coincide con
-- `CLAVE_CERTIFICADO_PREVIO` de `src/lib/cae/requisitos.ts`, la puerta se abre
-- EN SILENCIO. Una sola fuente en SQL, y T7 comprueba que casa con la de
-- TypeScript.

CREATE OR REPLACE FUNCTION public.fn_cae_clave_certificado_previo()
RETURNS text
LANGUAGE sql IMMUTABLE
SET search_path = public
AS $$ SELECT 'certificado_energetico_previo'::text $$;

COMMENT ON FUNCTION public.fn_cae_clave_certificado_previo() IS
  'Clave del requisito que abre la puerta para salir de borrador. DEBE coincidir '
  'con CLAVE_CERTIFICADO_PREVIO de src/lib/cae/requisitos.ts en pactstream-cae. '
  'Si divergen, la puerta deja de bloquear y no avisa.';


-- ─── 3 · Lotes ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.cae_lotes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  comunidad_autonoma  public.cae_comunidad NOT NULL,
  anio                int  NOT NULL,
  estado              public.cae_estado_lote NOT NULL DEFAULT 'abierto',
  delegado_nombre     text,
  entregado_at        timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT cae_lotes_anio_plausible CHECK (anio BETWEEN 2023 AND 2100),
  CONSTRAINT cae_lotes_entregado_con_fecha
    CHECK ((estado = 'entregado') = (entregado_at IS NOT NULL))
);

COMMENT ON TABLE public.cae_lotes IS
  'Agrupación de expedientes CAE para una solicitud de emisión. El mínimo de '
  '30 MWh (Orden TED/815/2023 art. 14.6) NO se almacena: se calcula sumando los '
  'expedientes del lote, para que no pueda quedar desfasado. Ojo: ese mínimo NO '
  'aplica en Ceuta y Melilla, por el mismo artículo.';

COMMENT ON COLUMN public.cae_lotes.delegado_nombre IS
  'Solo informativo. Nosotros NO presentamos: el art. 14.1 reserva la solicitud '
  'a sujetos obligados y delegados.';

CREATE INDEX IF NOT EXISTS idx_cae_lotes_org ON public.cae_lotes(organization_id);


-- ─── 4 · Expedientes ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.cae_expedientes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  pact_id             uuid REFERENCES public.pacts(id) ON DELETE SET NULL,
  ficha_codigo        text NOT NULL,
  ficha_version       text NOT NULL,
  comunidad_autonoma  public.cae_comunidad NOT NULL,
  anio_ejecucion      int  NOT NULL,
  direccion           text NOT NULL,
  datos_calculo       jsonb NOT NULL DEFAULT '{}'::jsonb,
  ahorro_kwh          int,
  estado              public.cae_estado_expediente NOT NULL DEFAULT 'borrador',
  ayuda_fnee          boolean NOT NULL DEFAULT false,
  -- RESTRICT y no SET NULL: si se borra un lote, sus expedientes quedarían en
  -- `en_lote` apuntando a nada. Un lote con expedientes se vacía, no se borra.
  lote_id             uuid REFERENCES public.cae_lotes(id) ON DELETE RESTRICT,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT cae_exp_ficha_conocida CHECK (ficha_codigo IN ('RES022','RES060')),
  CONSTRAINT cae_exp_anio_plausible CHECK (anio_ejecucion BETWEEN 2023 AND 2100),
  CONSTRAINT cae_exp_ahorro_no_negativo CHECK (ahorro_kwh IS NULL OR ahorro_kwh >= 0),
  -- La dirección es lo que nombra al bloqueante en la pantalla del lote
  -- («Serrano 40»). Vacía, la pantalla no sirve para lo único que hace.
  CONSTRAINT cae_exp_direccion_no_vacia CHECK (length(btrim(direccion)) > 0),
  -- `estado` y `lote_id` son dos verdades sobre lo mismo: si se desincronizan,
  -- la vista de lote y la lista de expedientes se contradicen.
  CONSTRAINT cae_exp_en_lote_coherente
    CHECK (estado <> 'en_lote' OR lote_id IS NOT NULL),
  CONSTRAINT cae_exp_lote_solo_en_estados
    CHECK (lote_id IS NULL OR estado IN ('en_lote','entregado'))
);

COMMENT ON COLUMN public.cae_expedientes.pact_id IS
  'Opcional a propósito. El escrow no tiene licencia; si el expediente exigiera '
  'un pacto, el vertical heredaría ese bloqueo y no podría venderse.';

COMMENT ON COLUMN public.cae_expedientes.ficha_version IS
  'Versión APLICADA, no la vigente. Un expediente se juzga con la ficha de su '
  'momento: el periodo transitorio del art. 3.2 de la Orden TED/845/2023 existe '
  'precisamente porque las fichas cambian.';

COMMENT ON COLUMN public.cae_expedientes.ayuda_fnee IS
  'Orden TED/815/2023 art. 14.8: una actuación beneficiaria de ayuda con cargo '
  'al Fondo Nacional de Eficiencia Energética NO puede generar CAE. La ayuda '
  'quema el certificado, así que no puede entrar en ningún lote.';

CREATE INDEX IF NOT EXISTS idx_cae_exp_lote   ON public.cae_expedientes(lote_id);
CREATE INDEX IF NOT EXISTS idx_cae_exp_pact   ON public.cae_expedientes(pact_id);
-- Cubre también los filtros por organización sola: es su columna de cabecera.
CREATE INDEX IF NOT EXISTS idx_cae_exp_agrupa ON public.cae_expedientes(organization_id, comunidad_autonoma, anio_ejecucion);


-- ─── 5 · Requisitos ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.cae_requisitos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expediente_id   uuid NOT NULL REFERENCES public.cae_expedientes(id) ON DELETE CASCADE,
  clave           text NOT NULL,
  estado          public.cae_estado_requisito NOT NULL DEFAULT 'pendiente',
  document_id     uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  nota            text,
  actualizado_por uuid REFERENCES public.users(id) ON DELETE SET NULL,
  actualizado_at  timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT cae_req_unico_por_expediente UNIQUE (expediente_id, clave),
  CONSTRAINT cae_req_clave_formato CHECK (clave ~ '^[a-z0-9_]+$'),
  -- Un requisito no puede estar «aportado» sin papel aportado. Sin esto, la
  -- puerta se abría marcando una casilla, y el semáforo podía pintar verde algo
  -- que no existe: el riesgo nº 1 declarado del spec, escrito en el esquema.
  -- Además hace ruidoso el borrado del documento (el SET NULL reevalúa el CHECK)
  -- en vez de dejar un verde huérfano en silencio.
  CONSTRAINT cae_req_aportado_con_documento
    CHECK (estado NOT IN ('aportado','verificado') OR document_id IS NOT NULL)
);

COMMENT ON TABLE public.cae_requisitos IS
  'Estado de cada requisito documental de un expediente. El CATÁLOGO de qué '
  'requisitos tiene cada ficha NO vive aquí: vive en src/lib/cae/requisitos.ts '
  'del front, porque es dato normativo y se revisa como código.';

CREATE INDEX IF NOT EXISTS idx_cae_req_documento ON public.cae_requisitos(document_id);
CREATE INDEX IF NOT EXISTS idx_cae_req_actualizado_por ON public.cae_requisitos(actualizado_por);


-- ─── 6 · Invariante del lote, desde el lado del expediente ───────────

CREATE OR REPLACE FUNCTION public.fn_cae_valida_lote()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_lote public.cae_lotes%ROWTYPE;
BEGIN
  IF NEW.lote_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- ⚠️ Esta función es INVOKER a propósito. Al no ser SECURITY DEFINER, un lote
  -- de otra organización sencillamente NO SE VE: `v_lote` queda nulo y la
  -- comparación de abajo lo rechaza. Es una segunda barrera además de la RLS.
  -- Si alguien la «arregla» poniéndola SECURITY DEFINER, esa barrera desaparece.
  SELECT * INTO v_lote FROM public.cae_lotes WHERE id = NEW.lote_id;

  IF v_lote.organization_id IS DISTINCT FROM NEW.organization_id THEN
    RAISE EXCEPTION 'El lote no existe o pertenece a otra organización.';
  END IF;

  IF v_lote.comunidad_autonoma IS DISTINCT FROM NEW.comunidad_autonoma THEN
    RAISE EXCEPTION
      'No se puede meter un expediente de % en un lote de %: la Orden TED/815/2023 '
      'art. 14.3 exige que todo lo agrupado sea de la misma comunidad autónoma.',
      NEW.comunidad_autonoma, v_lote.comunidad_autonoma;
  END IF;

  IF v_lote.anio IS DISTINCT FROM NEW.anio_ejecucion THEN
    RAISE EXCEPTION
      'No se puede meter un expediente de % en un lote de %: la Orden TED/815/2023 '
      'art. 14.3 exige que todo lo agrupado sea del mismo año.',
      NEW.anio_ejecucion, v_lote.anio;
  END IF;

  IF NEW.ayuda_fnee THEN
    RAISE EXCEPTION
      'Este expediente recibió ayuda del Fondo Nacional de Eficiencia Energética '
      'y no puede generar CAE (Orden TED/815/2023 art. 14.8): no puede entrar en un lote.';
  END IF;

  -- Un lote ya entregado al delegado no cambia de composición: lo presentado
  -- tiene que seguir siendo lo que se presentó.
  IF v_lote.estado = 'entregado'
     AND (TG_OP = 'INSERT' OR OLD.lote_id IS DISTINCT FROM NEW.lote_id) THEN
    RAISE EXCEPTION 'Ese lote ya está entregado: no admite cambios de composición.';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_cae_valida_lote ON public.cae_expedientes;
CREATE TRIGGER trg_cae_valida_lote
  BEFORE INSERT OR UPDATE ON public.cae_expedientes
  FOR EACH ROW EXECUTE FUNCTION public.fn_cae_valida_lote();


-- ─── 7 · Invariante del lote, desde el lado del lote ─────────────────
--
-- Sin esto, un `UPDATE cae_lotes SET comunidad_autonoma = 'Cataluña'` sobre un
-- lote lleno de expedientes de Madrid deja el lote entero violando el art. 14.3
-- y ningún disparador se entera: el invariante solo se protegía por un lado.
-- Organización, comunidad y año son la IDENTIDAD del lote, no atributos.

CREATE OR REPLACE FUNCTION public.fn_cae_lote_identidad_inmutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.comunidad_autonoma IS DISTINCT FROM OLD.comunidad_autonoma
     OR NEW.anio IS DISTINCT FROM OLD.anio THEN
    RAISE EXCEPTION
      'La organización, la comunidad autónoma y el año de un lote no se cambian: '
      'son lo que define qué puede agruparse dentro (Orden TED/815/2023 art. 14.3). '
      'Crea otro lote.';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_cae_lote_identidad ON public.cae_lotes;
CREATE TRIGGER trg_cae_lote_identidad
  BEFORE UPDATE ON public.cae_lotes
  FOR EACH ROW EXECUTE FUNCTION public.fn_cae_lote_identidad_inmutable();


-- ─── 8 · La puerta del certificado previo ────────────────────────────
--
-- Decisión de Andrés, 10-ago-2026: BLOQUEO DURO.
--
-- Por qué este y no otro: el certificado energético previo NO se puede emitir
-- con la obra empezada. Es el único error del sistema que no tiene arreglo
-- posterior — el cliente pierde la deducción entera y de forma irreversible, y
-- en la RES060 además desaparece el número, porque las demandas salen de él.
-- Todo lo demás (fotos, REA, facturas) se puede aportar tarde.
--
-- La condición está escrita como «SALIR de borrador», no como el par exacto
-- `borrador → en_ejecucion`. Con el par exacto se rodeaba de tres maneras:
-- saltando a `documentado`, entrando a `en_ejecucion` desde otro estado, o
-- naciendo ya fuera de `borrador` en un INSERT directo contra PostgREST.

CREATE OR REPLACE FUNCTION public.fn_cae_puerta_certificado_previo()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_tiene boolean;
BEGIN
  -- Mientras siga en borrador no hay nada que exigir.
  IF NEW.estado = 'borrador' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- `entregado` es terminal: lo que ya se entregó al delegado no se reabre.
    IF OLD.estado = 'entregado' AND NEW.estado IS DISTINCT FROM 'entregado' THEN
      RAISE EXCEPTION 'Un expediente entregado no vuelve atrás.';
    END IF;
    -- Sin cambio de estado no hay puerta que cruzar.
    IF OLD.estado IS NOT DISTINCT FROM NEW.estado THEN
      RETURN NEW;
    END IF;
    -- Ya estaba fuera de borrador: la puerta se cruzó en su momento.
    IF OLD.estado <> 'borrador' THEN
      RETURN NEW;
    END IF;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.cae_requisitos r
    WHERE r.expediente_id = NEW.id
      AND r.clave = public.fn_cae_clave_certificado_previo()
      AND r.estado IN ('aportado', 'verificado')
      AND r.document_id IS NOT NULL   -- marcar la casilla no basta: tiene que haber papel
  ) INTO v_tiene;

  IF NOT v_tiene THEN
    RAISE EXCEPTION
      'No puedes sacar esta obra de borrador: falta el certificado energético '
      'previo. No se puede emitir una vez empezada la obra, así que si arrancas '
      'sin él tu cliente pierde la deducción entera y de forma irreversible.'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END $$;

-- Sin `OF estado`: si otro disparador BEFORE cambiara `NEW.estado` sin que la
-- columna esté en el SET, con `OF estado` este no llegaría a ejecutarse. El
-- guarda por `OLD.estado IS NOT DISTINCT FROM NEW.estado` es más robusto.
DROP TRIGGER IF EXISTS trg_cae_puerta_certificado_previo ON public.cae_expedientes;
CREATE TRIGGER trg_cae_puerta_certificado_previo
  BEFORE INSERT OR UPDATE ON public.cae_expedientes
  FOR EACH ROW EXECUTE FUNCTION public.fn_cae_puerta_certificado_previo();


-- ─── 9 · Lo que no cambia después de crearse ─────────────────────────
--
-- `IS DISTINCT FROM`, nunca `!=`: con `!=` la comparación es ciega ante los
-- nulos y deja pasar el cambio sin avisar. Ya nos costó un agujero el 7-ago en
-- los disparadores de inmutabilidad de la evidencia.

CREATE OR REPLACE FUNCTION public.fn_cae_expediente_inmutables()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    RAISE EXCEPTION 'La organización de un expediente no se cambia.';
  END IF;

  -- Cambiar de ficha invalidaría todos los requisitos ya aportados, que son de
  -- la ficha anterior. Si hay que cambiarla, se crea otro expediente.
  IF NEW.ficha_codigo IS DISTINCT FROM OLD.ficha_codigo THEN
    RAISE EXCEPTION
      'La ficha de un expediente no se cambia: sus requisitos son los de la ficha '
      'con la que nació. Crea un expediente nuevo.';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_cae_expediente_inmutables ON public.cae_expedientes;
CREATE TRIGGER trg_cae_expediente_inmutables
  BEFORE UPDATE ON public.cae_expedientes
  FOR EACH ROW EXECUTE FUNCTION public.fn_cae_expediente_inmutables();

-- `updated_at` con la función que ya usa el resto del esquema, en vez de a mano
-- dentro del disparador de inmutabilidad: así quitar uno no mata al otro.
DROP TRIGGER IF EXISTS trg_cae_exp_updated_at ON public.cae_expedientes;
CREATE TRIGGER trg_cae_exp_updated_at
  BEFORE UPDATE ON public.cae_expedientes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_cae_lotes_updated_at ON public.cae_lotes;
CREATE TRIGGER trg_cae_lotes_updated_at
  BEFORE UPDATE ON public.cae_lotes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ─── 10 · RLS · deny-by-default, por organización ────────────────────
--
-- Se reutiliza `fn_is_org_active_member`, que ya existe y ya resuelve la
-- pertenencia activa. Es SECURITY DEFINER, así que esquiva la RLS de
-- `organization_members` y evita recursión entre políticas.

ALTER TABLE public.cae_lotes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cae_expedientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cae_requisitos  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cae_lotes_todo_miembro ON public.cae_lotes;
CREATE POLICY cae_lotes_todo_miembro ON public.cae_lotes
  FOR ALL TO authenticated
  USING      (public.fn_is_org_active_member(organization_id))
  WITH CHECK (public.fn_is_org_active_member(organization_id));

DROP POLICY IF EXISTS cae_exp_todo_miembro ON public.cae_expedientes;
CREATE POLICY cae_exp_todo_miembro ON public.cae_expedientes
  FOR ALL TO authenticated
  USING      (public.fn_is_org_active_member(organization_id))
  WITH CHECK (public.fn_is_org_active_member(organization_id));

-- Los requisitos no llevan organización propia: heredan la del expediente.
DROP POLICY IF EXISTS cae_req_todo_miembro ON public.cae_requisitos;
CREATE POLICY cae_req_todo_miembro ON public.cae_requisitos
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)
  ));

-- `service_role` explícito, como en `documents`, `pacts` y `organizations`. Sin
-- esto funcionaría igual por los default privileges, pero se rompería sin aviso
-- el día que alguien los toque.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cae_lotes       TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cae_expedientes TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cae_requisitos  TO authenticated, service_role;
