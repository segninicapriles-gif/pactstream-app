-- =====================================================================
-- Fase 1 · Auditoría 16-jul-2026 · UNIQUE(pact_id, user_id) en pact_parties
-- =====================================================================
--
-- Auditoría 13-jul (C4) recomendó UNIQUE(pact_id, user_id) como defensa
-- en profundidad al `sf_invite_party` (que ya rechaza autotrato+duplicados
-- desde `20260713000006_escrow_guards.sql`). Sin el constraint, cualquier
-- ruta que inserte directamente en `pact_parties` podría meter la misma
-- persona dos veces en el mismo pacto (autotrato / duplicado).
--
-- ESTADO EN DEV `erqglsrnknhwqhfupckf` (2026-07-16, verificado):
--   44 filas totales, 5 grupos duplicados por (pact_id, user_id).
--   Ninguno duplica (pact_id, user_id, role) exacto → son casos donde el
--   mismo user aparece con dos roles distintos en el mismo pacto (el
--   escenario de autotrato que sf_invite_party ya cierra a futuro).
--
-- SANEO (solo en dev; datos de prueba): conservar la fila más antigua por
-- (pact_id, user_id) y borrar el resto. Antes del constraint.
--
-- ⚠️ ANTES DE APLICAR EN CUALQUIER OTRO ENTORNO CON DATOS REALES,
-- REVISAR el saneo manualmente. En dev es aceptable la heurística
-- "conservar la más antigua"; en prod la decisión de qué rol conservar
-- es humana.

-- ── 1. Saneo (idempotente): eliminar duplicados conservando la fila
--       más antigua de cada grupo (pact_id, user_id).
DELETE FROM public.pact_parties pp
USING (
  SELECT id
  FROM (
    SELECT id,
           row_number() OVER (
             PARTITION BY pact_id, user_id
             ORDER BY invited_at ASC, id ASC
           ) AS rn
    FROM public.pact_parties
    WHERE user_id IS NOT NULL
  ) t
  WHERE t.rn > 1
) del
WHERE pp.id = del.id;

-- ── 2. Constraint UNIQUE (parcial: solo cuando user_id NO es null;
--       en el modelo v2.1 puede haber partes "invitadas por email" con
--       user_id NULL hasta que aceptan).
CREATE UNIQUE INDEX IF NOT EXISTS uq_pact_parties_pact_user
  ON public.pact_parties (pact_id, user_id)
  WHERE user_id IS NOT NULL;

COMMENT ON INDEX public.uq_pact_parties_pact_user IS
  'Auditoría 16-jul (C4 defense-in-depth): un usuario no puede aparecer dos veces en el mismo pacto. Complementa sf_invite_party. Parcial: WHERE user_id IS NOT NULL (invitados pendientes son NULL hasta aceptar).';
