/// Sistema de espaciado del Design System v1.0.
///
/// Base de 4pt con un escalón intermedio de 12pt (md) heredado de
/// Material Design. Cualquier valor fuera de esta escala es un bug.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
  static const double huge = 64.0;
  static const double massive = 96.0;
}
