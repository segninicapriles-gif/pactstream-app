import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Widget que anima transiciones numéricas con un conteo suave.
///
/// Cuando [value] cambia, el número se desliza hacia arriba con fade-out
/// del viejo valor y fade-in del nuevo, creando un efecto de "ticker"
/// similar a los dashboards financieros premium.
///
/// Uso:
/// ```dart
/// AnimatedCounter(
///   value: totalAmount,
///   style: AppTypography.h2,
///   formatter: (v) => AppFormatters.money(v),
/// )
/// ```
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.duration = AppMotion.normal,
    this.curve = AppMotion.emphasize,
  });

  /// Valor numérico actual.
  final num value;

  /// Estilo del texto.
  final TextStyle? style;

  /// Formateador opcional (e.g. para moneda, porcentaje).
  final String Function(num value)? formatter;

  /// Duración de la animación.
  final Duration duration;

  /// Curva de la animación.
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: _NumTween(end: value),
      duration: duration,
      curve: curve,
      builder: (context, animValue, _) {
        final display = formatter != null
            ? formatter!(animValue)
            : animValue is int || animValue == animValue.roundToDouble()
                ? '${animValue.round()}'
                : animValue.toStringAsFixed(1);
        return Text(display, style: style);
      },
    );
  }
}

/// Tween personalizado para num que interpola suavemente.
class _NumTween extends Tween<num> {
  _NumTween({required num end}) : super(end: end);

  @override
  num lerp(double t) {
    final b = begin ?? 0;
    final e = end ?? 0;
    return b + (e - b) * t;
  }
}
