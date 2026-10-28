-- El papel tiene que existir, y «verificado» no lo pone quien aporta.
--
-- ✅ APLICADA el 11-ago-2026 con el sello 20260811150705.
--
-- La puerta del certificado previo se apoyaba en una tabla que el propio
-- interesado controla entera. Lo destapó la revisión final del corte 1:
--
--   · `cae_requisitos` tenía UNA sola política `FOR ALL`, así que cualquier
--     miembro podía escribir a mano `estado='aportado'` y un `document_id`.
--   · `documents_cae_insert` no comprobaba que el fichero existiera en Storage.
--
-- Con dos llamadas a la API se salía de borrador sin haber subido un byte, y el
-- rastro con huella SHA-256 quedaba falsificado. No hacía la puerta decorativa
-- —seguía parando el despiste honesto, que es el 99 % de los casos— pero sí
-- hacía falsa la promesa de trazabilidad, que es lo que este producto vende.

CREATE OR REPLACE FUNCTION public.fn_cae_documento_exige_fichero()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_org  uuid;
  v_ruta text;
BEGIN
  v_org := public.fn_cae_org_de_ruta(NEW.storage_path);
  IF v_org IS NULL THEN
    RETURN NEW;   -- no es un documento CAE: no es asunto de este disparador
  END IF;

  v_ruta := regexp_replace(NEW.storage_path, '^cae-documentos/', '');

  IF NOT EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id = 'cae-documentos' AND o.name = v_ruta
  ) THEN
    RAISE EXCEPTION
      'No hay ningún fichero subido en esa ruta: un documento del expediente no '
      'puede existir sin el papel detrás.'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END $$;

COMMENT ON FUNCTION public.fn_cae_documento_exige_fichero() IS
  'Impide inventar una fila de documento CAE sin objeto en Storage. SECURITY '
  'DEFINER porque storage.objects tiene su propia RLS y aquí solo se comprueba '
  'existencia, nunca se devuelve contenido. La acción de servidor sube a Storage '
  'ANTES de insertar la fila, así que el camino bueno no se rompe.';

DROP TRIGGER IF EXISTS trg_cae_documento_exige_fichero ON public.documents;
CREATE TRIGGER trg_cae_documento_exige_fichero
  BEFORE INSERT ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.fn_cae_documento_exige_fichero();

-- `verificado` es el verde que la interfaz reserva a «una persona miró el papel».
-- Hoy no hay pantalla que lo produzca, y por eso mismo nadie se daría cuenta si
-- apareciera. Sale del alcance de `authenticated`. La `FOR ALL` se parte en
-- cuatro: concedía mucho más de lo que ninguna pantalla usa, que es la
-- definición de permiso de más.

DROP POLICY IF EXISTS cae_req_todo_miembro ON public.cae_requisitos;

CREATE POLICY cae_req_leer ON public.cae_requisitos
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)));

CREATE POLICY cae_req_crear ON public.cae_requisitos
  FOR INSERT TO authenticated
  WITH CHECK (estado <> 'verificado' AND EXISTS (
    SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)));

CREATE POLICY cae_req_actualizar ON public.cae_requisitos
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)))
  WITH CHECK (estado <> 'verificado' AND EXISTS (
    SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)));

CREATE POLICY cae_req_borrar ON public.cae_requisitos
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.cae_expedientes e
    WHERE e.id = cae_requisitos.expediente_id
      AND public.fn_is_org_active_member(e.organization_id)));
