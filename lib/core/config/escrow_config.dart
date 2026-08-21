/// Proveedor de escrow activo.
///
/// Compile-time via `--dart-define=ESCROW_PROVIDER=...`:
///   - `mock` (default) → flujo simulado en BBDD (`sf_pact_fund_initial`), el
///     demo actual. No mueve dinero real.
///   - `stripe` → pay-in real (Stripe Connect · customer_balance/bank transfer)
///     vía la Edge Function `escrow-payin`: el promotor recibe un IBAN de
///     custodia y transfiere; el depósito se confirma por `stripe-webhook`.
///     Proveedor principal tras el pivote (MangoPay rechazó por volumen).
///   - `mangopay` → legado (Bankwire sandbox). Se conserva compilando; no operativo.
///
/// El provider lo elige la Edge Function por `ESCROW_PROVIDER` en el servidor
/// (`getEscrowClient`); este flag Dart solo ajusta la UI (p.ej. copy del pay-in).
/// Se deja en `mock` mientras Stripe no esté aprobado y verificado end-to-end:
/// así el demo nunca se rompe.
abstract final class EscrowConfig {
  EscrowConfig._();

  static const provider =
      String.fromEnvironment('ESCROW_PROVIDER', defaultValue: 'mock');

  static bool get isStripe => provider == 'stripe';
  static bool get isMangopay => provider == 'mangopay';

  /// True si el pay-in mueve dinero real (cualquier proveedor no-mock).
  static bool get isLiveEscrow => provider != 'mock';

  /// Puente cert→factura (R3): al aprobar un hito, PactStream pide a CostPact
  /// que emita la factura Verifactu. Compile-time via
  /// `--dart-define=INVOICE_BRIDGE=on`. Off por defecto (no dispara nada).
  static const invoiceBridge =
      String.fromEnvironment('INVOICE_BRIDGE', defaultValue: 'off');

  static bool get invoiceBridgeOn => invoiceBridge == 'on';
}
