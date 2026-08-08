-- =====================================================================
-- Cadena forense: proteger storage_path y client_timestamp
-- =====================================================================
-- Contexto (7-ago-2026): auditoría de trazabilidad.
--
-- HUECO 1 — storage_path era mutable.
-- prevent_evidence_modification() protegía el hash, la hora de servidor, el
-- GPS, el EXIF y el autor, pero NO la ruta del fichero. Una fila podía
-- reapuntarse a otro objeto de Storage conservando intactos hash, GPS y
-- hora: el hash dejaba de corresponder al fichero al que apunta y la fila
-- seguía pareciendo legítima. Era el único agujero real de la cadena
-- forense. Las políticas de storage.objects mitigan (bloquean UPDATE y
-- DELETE al rol authenticated), pero la defensa en profundidad fallaba
-- justo en el eslabón que une la fila con su fichero.
--
-- HUECO 2 — comparaciones no seguras ante NULL.
-- La versión anterior usaba `!=` para exif_metadata::text. Si cualquiera de
-- los dos lados es NULL, `!=` devuelve NULL —no TRUE—, la condición no se
-- cumple y la modificación pasa sin excepción. Como exif_metadata es NULL
-- en todas las filas de hoy (nunca se rellena), el EXIF estaba de facto
-- desprotegido: bastaba con vaciarlo. Se pasa todo a IS DISTINCT FROM, que
-- es seguro ante NULL y es lo que la intención original pedía.
--
-- Qué sigue siendo modificable, a propósito:
--   · is_superseded / superseded_by_id → el flujo de resubida los necesita.
--   · description / technical_notes    → texto libre, no es dato forense.
--   · obra_distance_meters             → lo escribirá el futuro trigger de
--   · geolocation_verification           verificación geográfica.
--
-- Pendiente de decidir (no se incluye aquí para no ampliar el alcance):
-- file_size_bytes y mime_type también describen el fichero y podrían
-- entrar en la lista. Hoy no estaban y se dejan como estaban.

CREATE OR REPLACE FUNCTION prevent_evidence_modification()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Las evidencias son append-only. No se permiten DELETE.';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Datos forenses: identidad de la fila, del fichero y del acto de captura.
    -- Solo se permite mover is_superseded/superseded_by_id y el texto libre.
    IF NEW.id                IS DISTINCT FROM OLD.id
       OR NEW.milestone_id       IS DISTINCT FROM OLD.milestone_id
       OR NEW.uploaded_by_user_id IS DISTINCT FROM OLD.uploaded_by_user_id
       OR NEW.storage_path       IS DISTINCT FROM OLD.storage_path
       OR NEW.sha256_hash        IS DISTINCT FROM OLD.sha256_hash
       OR NEW.server_timestamp   IS DISTINCT FROM OLD.server_timestamp
       OR NEW.client_timestamp   IS DISTINCT FROM OLD.client_timestamp
       OR NEW.gps_latitude       IS DISTINCT FROM OLD.gps_latitude
       OR NEW.gps_longitude      IS DISTINCT FROM OLD.gps_longitude
       OR NEW.exif_metadata      IS DISTINCT FROM OLD.exif_metadata
    THEN
      RAISE EXCEPTION 'Los datos forenses de la evidencia son inmutables.';
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION prevent_evidence_modification() IS
  'Append-only de milestone_evidences. DELETE siempre bloqueado. UPDATE '
  'bloqueado si cambia cualquier dato forense: identidad de la fila, ruta y '
  'hash del fichero, horas de cliente y servidor, GPS o EXIF. Solo quedan '
  'editables is_superseded, superseded_by_id, el texto libre y los campos '
  'que rellenará la verificación geográfica.';
