import 'app_tokens.generated.dart';

/// Sistema de espaciado — Sistema ARCO.
///
/// Base 4pt con un escalón intermedio de 12 (md) heredado de Material.
/// Cualquier valor fuera de esta escala es un bug.
///
/// Los valores se delegan a [ArcoTokens], generado desde
/// `design-system/tokens.json`. Nota histórica: hasta el 13-ago-2026 esta era
/// la ÚNICA escala de espaciado completa del ecosistema — el canon ARCO nunca
/// definió una, así que las cuatro superficies web improvisaban o heredaban la
/// de Tailwind. Cuando se centralizó, esta escala fue la que se adoptó como
/// canon: era la única que existía de verdad.
///
/// Esta clase se conserva como fachada: los widgets siguen escribiendo
/// `AppSpacing.lg`.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = ArcoTokens.spaceXs;
  static const double sm = ArcoTokens.spaceSm;
  static const double md = ArcoTokens.spaceMd;
  static const double lg = ArcoTokens.spaceLg;
  static const double xl = ArcoTokens.spaceXl;
  static const double xxl = ArcoTokens.spaceXxl;
  static const double xxxl = ArcoTokens.spaceXxxl;
  static const double huge = ArcoTokens.spaceHuge;
  static const double massive = ArcoTokens.spaceMassive;
}
