import 'package:flutter/widgets.dart';

/// Radios de PactStream (Design System v1.1).
///
/// Escala calibrada para fintech mobile: md (12) para cards, buttons e inputs;
/// lg (16) para containers destacados; pill (999) para badges y pills.
/// Referencia: Revolut, N26, Wise usan 12-16px en sus cards principales.
abstract final class AppRadius {
  AppRadius._();

  // Escala calibrada para fintech mobile (Revolut/N26/Wise reference).
  // xxs=2 para drag-handles y líneas decorativas; micro=4 para progress
  // bars y mini-badges; xs=6 evita la frialdad de 4px; md=12 da calidez
  // a cards y buttons sin perder seriedad; lg=16 para containers destacados.
  static const double xxs = 2.0;
  static const double micro = 4.0;
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double pill = 999.0;

  // BorderRadius helpers
  static const BorderRadius xxsAll = BorderRadius.all(Radius.circular(xxs));
  static const BorderRadius microAll = BorderRadius.all(Radius.circular(micro));
  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Top-only radius for bottom sheets (xl = 20px).
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(xl));
}
