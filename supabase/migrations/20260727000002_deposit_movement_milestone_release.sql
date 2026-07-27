-- 20260727000002: Añadir al enum de movimientos de depósito la salida ordinaria.
--
-- APLICADA EN: erqglsrnknhwqhfupckf (pactstream-dev) el 27/07/2026 ✅
-- DESTINO: pactstream-app/supabase/migrations/
--
-- ─────────────────────────────────────────────────────────────────────────────
-- PROBLEMA
-- ─────────────────────────────────────────────────────────────────────────────
-- Estado del enum `deposit_movement_type` ANTES de esta migración (9 valores,
-- repartidos entre 20260430000018 y 20260430000025):
--
--   1 initial_deposit         entrada · depósito inicial del promotor
--   2 replenishment           entrada · reposición tras certificación aprobada
--   3 automatic_execution     salida  · ejecución forzosa tras T+72 h de impago
--   4 addendum_replenishment  entrada · reposición tras firmar un anexo
--   5 refund                  salida  · devolución al promotor
--   6 reserve_deposit         entrada · reserva
--   7 predeposit_for_cert     entrada · predepósito para una certificación
--   8 surety_claim_payout     salida  · pago por siniestro de la póliza de caución
--   9 final_reserve_release   salida  · liberación de la reserva final
--
-- Hay salidas, pero todas son de casos límite: impago, devolución, siniestro y
-- liquidación final. NINGUNA cubre la salida del camino feliz — consumir el
-- depósito al aprobar un hito y liberar el importe al constructor — pese a que la
-- columna documenta explícitamente:
--
--     amount_cents -- positivo = entrada al depósito; negativo = salida
--
-- Y hay una prueba de que el hueco es real: en
-- `20260713000006_escrow_guards.sql` (líneas ~243-250) el equipo dejó escrito el
-- diff propuesto para registrar justo ese movimiento, y usa el literal
-- 'release_for_cert' — un valor que NO EXISTE en el enum. Ese bloque está
-- comentado con la advertencia «NO aplicar a ciegas», así que hoy no rompe nada,
-- pero el día que se descomente fallaría con
--   22P02: invalid input value for enum deposit_movement_type: "release_for_cert"
--
-- ─────────────────────────────────────────────────────────────────────────────
-- CORRECCIÓN
-- ─────────────────────────────────────────────────────────────────────────────
-- Se añade `milestone_release`, y no `release_for_cert`, porque el enum
-- `payment_type` de la misma base ya usa exactamente ese nombre para el mismo
-- hecho económico. Que el mismo evento se llame igual en `payments` y en
-- `deposit_movements` vale más que respetar el nombre de un borrador comentado.
--
-- ⚠️ PENDIENTE DE CÓDIGO: al descomentar el bloque de escrow_guards hay que
--    cambiar 'release_for_cert' por 'milestone_release'. Si se prefiere el otro
--    nombre, añádase ese valor en su lugar — pero que sea uno solo, no dos
--    sinónimos.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- SEGURIDAD
-- ─────────────────────────────────────────────────────────────────────────────
-- ALTER TYPE ... ADD VALUE es aditivo: no invalida datos ni políticas, y ningún
-- CHECK ni RPC enumera los valores de forma exhaustiva. Idempotente por
-- IF NOT EXISTS.
--
-- ⚠️ SIN TRANSACCIÓN A PROPÓSITO: PostgreSQL no permite usar un valor de enum
--    recién añadido dentro de la misma transacción que lo crea. Ejecutar suelto.
--
-- NOTA SOBRE EL SEED DE DEMO
--   `02_seed_pactstream.sql` NO depende de esta migración: registra solo entradas
--   (initial_deposit + replenishment) y deja el consumo en `payments`, de modo que
--   funciona con el enum previo. Aplicar esta migración no lo altera.

ALTER TYPE public.deposit_movement_type ADD VALUE IF NOT EXISTS 'milestone_release';

COMMENT ON TYPE public.deposit_movement_type IS
  'Movimientos del depósito de garantía. Entradas: initial_deposit, replenishment, '
  'addendum_replenishment, reserve_deposit, predeposit_for_cert. Salidas: '
  'milestone_release (ordinaria, al aprobar un hito), automatic_execution (forzosa '
  'por impago), surety_claim_payout (siniestro de la póliza), final_reserve_release '
  '(liquidación) y refund (devolución al promotor). El signo va en amount_cents: '
  'positivo entrada, negativo salida.';

-- ─── Verificación: deben aparecer los diez valores ────────────────────────────
SELECT e.enumsortorder AS pos, e.enumlabel
FROM pg_enum e
JOIN pg_type t ON t.oid = e.enumtypid
WHERE t.typname = 'deposit_movement_type'
ORDER BY e.enumsortorder;

NOTIFY pgrst, 'reload schema';
