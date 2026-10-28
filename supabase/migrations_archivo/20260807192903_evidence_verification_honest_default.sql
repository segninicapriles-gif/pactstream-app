-- =====================================================================
-- geolocation_verification: el valor por defecto deja de mentir
-- =====================================================================
-- Contexto (7-ago-2026): continuación de 20260807000001.
--
-- Hasta hoy, toda evidencia nacía con geolocation_verification='verified'
-- sin que ningún proceso comprobara nada. A partir de aquí nace 'pending',
-- que es lo cierto: la evidencia se ha sellado (hash SHA-256, hora de
-- servidor inmutable y posición GPS del dispositivo) pero su ubicación no
-- se ha contrastado todavía contra la de la obra.
--
-- Qué SÍ está garantizado hoy y se puede afirmar sin reservas:
--   · sha256_hash, server_timestamp, gps_latitude/longitude y exif_metadata
--     son inmutables (trigger trg_evidence_immutable).
--   · Las evidencias no se pueden borrar.
--   · El objeto en Storage tampoco se puede modificar ni borrar
--     (políticas RLS con USING (false) sobre storage.objects).
--
-- Qué falta para poder marcar 'verified' de verdad:
--   1. Extraer el EXIF en el cliente (hoy no hay paquete y exif_metadata
--      nunca se rellena) y comparar el GPS de la foto con el del
--      dispositivo — no son lo mismo, y su discrepancia ya es señal.
--   2. Guardar un punto de referencia de la obra. Hoy solo existe
--      obra_address_line como texto libre: sin coordenadas no hay forma de
--      calcular obra_distance_meters.
--   3. Función + trigger que calcule la distancia y asigne la bandera
--      ('verified' | 'gps_outside_radius' | 'metadata_anomaly').
--
-- ⚠️ FILAS EXISTENTES: se dejan como están, a propósito.
-- Están marcadas 'verified' sin haberse comprobado, así que el dato sigue
-- siendo incorrecto para el histórico. Reescribirlo es una modificación de
-- datos de producción y es decisión de Andrés, no de esta migración. Si se
-- decide sanear el histórico, basta con:
--
--   UPDATE public.milestone_evidences
--      SET geolocation_verification = 'pending'
--    WHERE geolocation_verification = 'verified';
--
-- (geolocation_verification no está protegida por trg_evidence_immutable,
--  precisamente para que el futuro trigger de verificación pueda escribirla.)

ALTER TABLE public.milestone_evidences
  ALTER COLUMN geolocation_verification SET DEFAULT 'pending';

COMMENT ON COLUMN public.milestone_evidences.geolocation_verification IS
  'Resultado del contraste entre la ubicación de la evidencia y la de la obra. '
  'Nace como pending: el sellado (hash, hora de servidor, GPS) sí está '
  'garantizado, pero la verificación geográfica todavía no está implementada. '
  'No afirmar que la evidencia se verifica contra el catastro hasta que exista.';
