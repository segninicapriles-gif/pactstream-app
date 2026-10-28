-- «Entregado» es terminal de verdad, y el lote entregado no se reabre.
--
-- ✅ APLICADA el 11-ago-2026 con el sello 20260811144413.
--
-- ⚠️ TERCERA vez que un `RETURN` temprano desactiva las comprobaciones de abajo.
-- Las dos anteriores: la puerta no cubría el INSERT (revisión de T2) y sacar un
-- expediente de un lote entregado (encontrado por T6). Esta: devolver a
-- `borrador` un expediente ya ENTREGADO salía por la primera línea de la puerta.
--
-- La lección, escrita donde se lee: en un disparador, un `RETURN NEW` temprano
-- NO es una optimización, es una lista de comprobaciones que se saltan. La
-- inmutabilidad va SIEMPRE antes que cualquier atajo.
--
-- Por eso se parte en dos funciones: una decide qué NO se puede cambiar nunca, y
-- la otra qué hace falta para avanzar. Mezcladas, el atajo de una apagaba a la
-- otra — que es exactamente lo que llevaba pasando tres veces.

CREATE OR REPLACE FUNCTION public.fn_cae_expediente_entregado_es_terminal()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF OLD.estado = 'entregado' AND NEW.estado IS DISTINCT FROM 'entregado' THEN
    RAISE EXCEPTION
      'Un expediente entregado no vuelve atrás: lo que se entregó al delegado '
      'tiene que seguir siendo lo que se entregó.';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_cae_entregado_terminal ON public.cae_expedientes;
CREATE TRIGGER trg_cae_entregado_terminal
  BEFORE UPDATE ON public.cae_expedientes
  FOR EACH ROW EXECUTE FUNCTION public.fn_cae_expediente_entregado_es_terminal();

CREATE OR REPLACE FUNCTION public.fn_cae_puerta_certificado_previo()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_tiene boolean;
BEGIN
  -- Este atajo es seguro AHORA porque lo irreversible vive en su propio
  -- disparador, arriba. No lo era antes.
  IF NEW.estado = 'borrador' THEN RETURN NEW; END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.estado IS NOT DISTINCT FROM NEW.estado THEN RETURN NEW; END IF;
    IF OLD.estado <> 'borrador' THEN RETURN NEW; END IF;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.cae_requisitos r
    WHERE r.expediente_id = NEW.id
      AND r.clave = public.fn_cae_clave_certificado_previo()
      AND r.estado IN ('aportado','verificado')
      AND r.document_id IS NOT NULL
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

CREATE OR REPLACE FUNCTION public.fn_cae_lote_identidad_inmutable()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.comunidad_autonoma IS DISTINCT FROM OLD.comunidad_autonoma
     OR NEW.anio IS DISTINCT FROM OLD.anio THEN
    RAISE EXCEPTION
      'La organización, la comunidad autónoma y el año de un lote no se cambian: '
      'son lo que define qué puede agruparse dentro (Orden TED/815/2023 art. 14.3). '
      'Crea otro lote.';
  END IF;

  IF OLD.estado = 'entregado' AND NEW.estado IS DISTINCT FROM 'entregado' THEN
    RAISE EXCEPTION
      'Un lote entregado no se reabre: se le podría cambiar la composición y '
      'volver a cerrarlo, falsificando lo que se presentó.';
  END IF;

  RETURN NEW;
END $$;
