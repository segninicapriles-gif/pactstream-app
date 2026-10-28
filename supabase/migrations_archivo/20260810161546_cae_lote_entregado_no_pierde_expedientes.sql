-- Un lote entregado no pierde expedientes.
--
-- ✅ APLICADA el 10-ago-2026 con el sello 20260810161546.
--
-- El disparador de T2 volvía antes de tiempo cuando `NEW.lote_id` era NULL, así
-- que SACAR un expediente de un lote ya entregado se le escapaba: se podía
-- vaciar por detrás un lote ya presentado al delegado. Lo encontró la tarea del
-- lote (T6) al construir su pantalla.
--
-- La comprobación que faltaba mira el lote de ORIGEN, no el de destino.
-- El cuerpo completo de `fn_cae_valida_lote` vive en 20260810124108; aquí solo
-- se reemplaza con el bloque nuevo al principio.

CREATE OR REPLACE FUNCTION public.fn_cae_valida_lote()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE
  v_lote        public.cae_lotes%ROWTYPE;
  v_lote_previo public.cae_lotes%ROWTYPE;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.lote_id IS NOT NULL
     AND OLD.lote_id IS DISTINCT FROM NEW.lote_id THEN
    SELECT * INTO v_lote_previo FROM public.cae_lotes WHERE id = OLD.lote_id;
    IF v_lote_previo.estado = 'entregado' THEN
      RAISE EXCEPTION
        'Ese lote ya está entregado: no se le pueden sacar expedientes. Lo presentado '
        'tiene que seguir siendo lo que se presentó.';
    END IF;
  END IF;

  IF NEW.lote_id IS NULL THEN RETURN NEW; END IF;

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
  IF v_lote.estado = 'entregado'
     AND (TG_OP = 'INSERT' OR OLD.lote_id IS DISTINCT FROM NEW.lote_id) THEN
    RAISE EXCEPTION 'Ese lote ya está entregado: no admite cambios de composición.';
  END IF;

  RETURN NEW;
END $$;
