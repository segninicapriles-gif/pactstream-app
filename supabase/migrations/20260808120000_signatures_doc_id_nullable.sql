-- =====================================================================
-- signatures.signaturit_doc_id deja de ser obligatorio
-- =====================================================================
-- Contexto (8-ago-2026): continuación del saneamiento de trazabilidad.
--
-- La columna nació NOT NULL porque el diseño daba por hecho que toda firma
-- pasaría por Signaturit. Ese prestador NO está integrado: hoy el contrato se
-- firma con `sf_sign_contract` —PDF sellado con SHA-256, consentimiento
-- registrado en `legal_consents` y `pact_parties.signed_at`—, que no escribe
-- esta tabla. Verificado antes de tocar nada:
--
--   · Ninguna función del esquema public referencia signaturit_doc_id.
--   · Ningún fichero de la app Flutter la lee ni la escribe.
--   · Las 6 filas de `signatures` son del seed de demo (ids 'sgt_aen_*').
--     No existe ni una firma real.
--
-- Al ser obligatoria, el seed de demo se veía forzado a inventar un
-- identificador de un proveedor que no está conectado, y ese dato inventado
-- acababa sosteniendo un claim comercial que no se puede defender. Hacerla
-- nullable permite representar lo que de verdad hay: una firma trazable, sin
-- firma electrónica cualificada.
--
-- El UNIQUE se conserva: en Postgres los NULL no colisionan entre sí, así que
-- varias firmas sin prestador conviven sin problema, y cuando exista la
-- integración cada identificador seguirá siendo único.
--
-- Reversible mientras no haya filas con NULL:
--   ALTER TABLE public.signatures ALTER COLUMN signaturit_doc_id SET NOT NULL;

ALTER TABLE public.signatures
  ALTER COLUMN signaturit_doc_id DROP NOT NULL;

COMMENT ON COLUMN public.signatures.signaturit_doc_id IS
  'Identificador del documento en el prestador de firma cualificada. NULL '
  'mientras no haya integración: la firma es trazable (PDF + SHA-256 + '
  'consentimiento registrado) pero no cualificada. No presuponer que existe.';
