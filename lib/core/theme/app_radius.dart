import 'package:flutter/widgets.dart';

/// Radios de PactStream — Sistema ARCO (DESIGN-ECOSISTEMA.md 2026-07-18).
///
/// Escala ARCO: xs 6 · sm 10 · md 14 (inputs) · lg 20 (card app) ·
/// xl 28 (card marketing/hero) · pill 999 (CTA primario, pills de estado).
abstract final class AppRadius {
  AppRadius._();

  // xxs=2 y micro=4 se conservan para drag-handles/progress bars (fuera de
  // la escala ARCO, no especificados por el design system). El resto sigue
  // la escala ARCO: xs 6 · sm 10 · md 14 · lg 20 · xl 28 · pill 999.
  static const double xxs = 2.0;
  static const double micro = 4.0;
  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 20.0;
  static const double xl = 28.0;
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

  /// Top-only radius for bottom sheets (xl = 28px).
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(xl));
}
