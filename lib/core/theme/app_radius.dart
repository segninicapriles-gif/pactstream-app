import 'package:flutter/widgets.dart';

import 'app_tokens.generated.dart';

/// Radios de PactStream — Sistema ARCO.
///
/// Los valores ya NO viven aquí: se delegan a [ArcoTokens], generado desde
/// `design-system/tokens.json`. Antes eran una transcripción a mano del canon
/// —correcta, pero sin nada que impidiera que se separara del resto del
/// ecosistema en la siguiente edición.
///
/// Esta clase se conserva como fachada: los widgets siguen escribiendo
/// `AppRadius.lg` y no hay que tocar 200 ficheros.
abstract final class AppRadius {
  AppRadius._();

  // xxs=2 y micro=4 NO están en el canon: son para drag-handles y barras de
  // progreso, elementos que el design system no cubre. Se quedan literales
  // a propósito y así queda dicho.
  static const double xxs = 2.0;
  static const double micro = 4.0;

  // El resto sale del generador. Escala ARCO §5: 6 · 10 · 14 · 20 · 28 · 999.
  static const double xs = ArcoTokens.radiusXs;
  static const double sm = ArcoTokens.radiusSm;
  static const double md = ArcoTokens.radiusMd;
  static const double lg = ArcoTokens.radiusLg;
  static const double xl = ArcoTokens.radiusXl;
  static const double pill = ArcoTokens.radiusPill;

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
