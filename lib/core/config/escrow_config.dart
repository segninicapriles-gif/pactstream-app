/// Proveedor de escrow activo.
///
/// Compile-time via `--dart-define=ESCROW_PROVIDER=...`:
///   - `mock` (default) → flujo simulado en BBDD (`sf_pact_fund_initial`), el
///     demo actual. No mueve dinero real.
///   - `mangopay` → pay-in real (Bankwire, sandbox) vía la Edge Function
///     `mangopay-payin`: el promotor recibe un IBAN de custodia y transfiere;
///     el depósito se confirma por webhook.
///
/// Se deja en `mock` mientras el flujo Mangopay no esté verificado end-to-end
/// contra sandbox: así el demo nunca se rompe.
abstract final class EscrowConfig {
  EscrowConfig._();

  static const provider =
      String.fromEnvironment('ESCROW_PROVIDER', defaultValue: 'mock');

  static bool get isMangopay => provider == 'mangopay';

  /// Puente cert→factura (R3): al aprobar un hito, PactStream pide a CostPact
  /// que emita la factura Verifactu. Compile-time via
  /// `--dart-define=INVOICE_BRIDGE=on`. Off por defecto (no dispara nada).
  static const invoiceBridge =
      String.fromEnvironment('INVOICE_BRIDGE', defaultValue: 'off');

  static bool get invoiceBridgeOn => invoiceBridge == 'on';
}
