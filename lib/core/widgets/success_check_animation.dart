import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Animación de checkmark circular que se dibuja progresivamente.
///
/// Se usa para confirmar acciones exitosas (ej: tras marcar hito,
/// enviar validación, completar firma). Reproduce el patrón de
/// micro-confirmación de apps fintech premium.
///
/// Uso:
/// ```dart
/// SuccessCheckAnimation(
///   size: 64,
///   onComplete: () => Navigator.pop(context),
/// )
/// ```
class SuccessCheckAnimation extends StatefulWidget {
  const SuccessCheckAnimation({
    super.key,
    this.size = 56,
    this.color,
    this.strokeWidth = 3.0,
    this.onComplete,
  });

  final double size;
  final Color? color;
  final double strokeWidth;
  final VoidCallback? onComplete;

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _circleAnim;
  late final Animation<double> _checkAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.emphasis,
    );

    // Fase 1: Círculo se dibuja (0.0 → 0.5)
    _circleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Fase 2: Check se dibuja (0.4 → 0.8)
    _checkAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    // Fase 3: Pulse scale (0.7 → 1.0)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 60),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.success;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _CheckPainter(
              color: color,
              circleProgress: _circleAnim.value,
              checkProgress: _checkAnim.value,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.color,
    required this.circleProgress,
    required this.checkProgress,
    required this.strokeWidth,
  });

  final Color color;
  final double circleProgress;
  final double checkProgress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Círculo
    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        paint,
      );
    }

    // Checkmark
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(size.width * 0.28, size.height * 0.52);
      final p2 = Offset(size.width * 0.44, size.height * 0.66);
      final p3 = Offset(size.width * 0.72, size.height * 0.36);

      final path = Path();

      if (checkProgress <= 0.5) {
        // Primer trazo: p1 → p2
        final t = checkProgress * 2;
        final current = Offset.lerp(p1, p2, t)!;
        path.moveTo(p1.dx, p1.dy);
        path.lineTo(current.dx, current.dy);
      } else {
        // Primer trazo completo + segundo trazo
        path.moveTo(p1.dx, p1.dy);
        path.lineTo(p2.dx, p2.dy);
        final t = (checkProgress - 0.5) * 2;
        final current = Offset.lerp(p2, p3, t)!;
        path.lineTo(current.dx, current.dy);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      circleProgress != old.circleProgress ||
      checkProgress != old.checkProgress;
}
