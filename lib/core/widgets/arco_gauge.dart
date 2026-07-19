import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Arco Gauge — Sistema ARCO §1/§6/§8b (ver
/// `design-ecosistema-2026-07/DESIGN-ECOSISTEMA.md`).
///
/// Gauge de arco de 270° (desde 135°), extremos redondeados, para todo
/// score/progreso/asignación del ecosistema: score IA de PactStream (0-100),
/// consumo de presupuesto, asignaciones. Es la ÚNICA curva decorativa
/// permitida en UI de producto (regla it.6: el arco queda solo donde es
/// funcional).
///
/// - Pista: color de marca al 8% (light) / 15% (dark) vía `context.colors`
///   (por defecto `context.colors.brandAccentBg`, que ya resuelve esa
///   calibración exacta para PactStream).
/// - Progreso: color parametrizable, por defecto [AppColors.psBlue].
///   Para scores, pasar el color semántico que ya use la pantalla
///   (verde/ámbar/rojo) — este widget no inventa umbrales.
/// - `child` centrado (normalmente la cifra en mono w700).
///
/// Uso:
/// ```dart
/// ArcoGauge(
///   progress: score / 100,
///   size: 52,
///   color: scoreColor, // ya calculado por la pantalla (verdict/severity)
///   semanticLabel: 'Score IA: $score de 100',
///   child: Text('$score', style: ...),
/// )
/// ```
class ArcoGauge extends StatelessWidget {
  const ArcoGauge({
    super.key,
    required this.progress,
    this.size = 80,
    this.color,
    this.trackColor,
    this.strokeWidthFactor = 0.09,
    this.child,
    this.semanticLabel,
    this.animate = true,
    this.duration = AppMotion.slow,
    this.curve = Curves.easeOutCubic,
  });

  /// Progreso 0.0-1.0. Se clampa internamente.
  final double progress;

  /// Diámetro del gauge.
  final double size;

  /// Color del arco de progreso. Por defecto [AppColors.psBlue]. Pasar el
  /// color semántico correspondiente (verde/ámbar/rojo) cuando el gauge
  /// representa un score.
  final Color? color;

  /// Color de la pista de fondo. Por defecto `context.colors.brandAccentBg`
  /// (marca al ~8% light / ~15% dark).
  final Color? trackColor;

  /// Grosor del trazo como fracción del diámetro (~9% por defecto).
  final double strokeWidthFactor;

  /// Contenido centrado (normalmente la cifra/porcentaje en mono w700).
  final Widget? child;

  /// Label de accesibilidad (equivalente a aria-label). Se expone junto con
  /// el valor porcentual vía `Semantics.value`.
  final String? semanticLabel;

  /// Si `true`, anima el barrido desde 0 hasta [progress] al montar / al
  /// cambiar el valor. Desactivar cuando el valor ya se anima externamente
  /// (p. ej. un `AnimationController` propio del caller).
  final bool animate;
  final Duration duration;
  final Curve curve;

  static const double startAngleDeg = 135;
  static const double sweepAngleDeg = 270;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    final resolvedColor = color ?? AppColors.psBlue;
    final resolvedTrack = trackColor ?? co.brandAccentBg;
    final clamped = progress.clamp(0.0, 1.0);

    Widget paint(double value) {
      return CustomPaint(
        size: Size(size, size),
        painter: _ArcoGaugePainter(
          progress: value,
          color: resolvedColor,
          trackColor: resolvedTrack,
          strokeWidthFactor: strokeWidthFactor,
        ),
      );
    }

    final gauge = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: duration,
            curve: curve,
            builder: (context, value, _) => paint(value),
          )
        : paint(clamped);

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            gauge,
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _ArcoGaugePainter extends CustomPainter {
  _ArcoGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidthFactor,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidthFactor;

  static const double _startAngle =
      ArcoGauge.startAngleDeg * math.pi / 180;
  static const double _sweepAngle =
      ArcoGauge.sweepAngleDeg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = size.shortestSide;
    final strokeWidth = diameter * strokeWidthFactor;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (diameter - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        arcRect,
        _startAngle,
        _sweepAngle * clamped,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcoGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidthFactor != strokeWidthFactor;
}
