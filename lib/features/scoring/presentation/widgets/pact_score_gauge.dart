/// Gauge semicircular con arco 180° gradiente rojo→ámbar→verde.
///
/// Diseño limpio: arco va de izquierda (rojo) a derecha (verde)
/// pasando por la cima (ámbar). El centro del arco está en la base
/// del canvas — toda la curva queda visible sin clipping.
/// El score y la etiqueta de nivel aparecen dentro del arco.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/scoring_models.dart' show scoreGradientColor;
import '../../../../core/theme/app_typography.dart';

class PactScoreGauge extends StatefulWidget {
  const PactScoreGauge({
    super.key,
    required this.score,
    required this.label,
    required this.labelColor,
    this.previousScore,
    this.size = 220,
  });

  final int score;
  final String label;
  final Color labelColor;
  final int? previousScore;
  final double size;

  @override
  State<PactScoreGauge> createState() => _PactScoreGaugeState();
}

class _PactScoreGaugeState extends State<PactScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(PactScoreGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.medium,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Rating label ---
          Text(
            'RATING PACTSTREAM',
            style: AppTypography.label.copyWith(
              letterSpacing: 1.2,
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // --- Arc gauge: ocupa todo el ancho disponible ---
          LayoutBuilder(
            builder: (_, constraints) {
              // Radio = 46% del ancho → arco grande que llena la card.
              // Altura = 58% del ancho → espacio justo para el semicírculo.
              final gaugeW = constraints.maxWidth;
              final gaugeH = gaugeW * 0.58;
              // Tamaño de fuente proporcional para que escale con la card.
              final scoreFontSize = gaugeW * 0.22;
              final labelFontSize = gaugeW * 0.055;

              return AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final progress = _animation.value * widget.score / 100;
                  final displayScore =
                      (widget.score * _animation.value).round();

                  return SizedBox(
                    width: gaugeW,
                    height: gaugeH,
                    child: CustomPaint(
                      painter: _ArcGaugePainter(
                        progress: progress,
                        trackColor: context.colors.border,
                      ),
                      child: Align(
                        // Texto en el centro-bajo del interior del arco
                        alignment: const Alignment(0, 0.42),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayScore',
                              style: AppTypography.h1.copyWith(
                                fontSize: scoreFontSize,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'score / 100',
                              style: AppTypography.caption.copyWith(
                                fontSize: labelFontSize,
                                color: context.colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // --- Status label (tier chip) ---
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: widget.labelColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.labelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.label,
                  style: AppTypography.label.copyWith(
                    color: widget.labelColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // --- Delta vs mes anterior ---
          if (widget.previousScore != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Builder(builder: (_) {
              final diff2 = widget.score - widget.previousScore!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    diff2 >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: diff2 >= 0 ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${diff2 >= 0 ? '+' : ''}$diff2 pts vs mes anterior',
                    style: AppTypography.caption.copyWith(
                      color: diff2 >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Painter — semicírculo 180° de izquierda a derecha
// rojo (0°) → ámbar (90° arriba) → verde (180°)
// ---------------------------------------------------------------------------

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({required this.progress, required this.trackColor});

  final double progress; // 0.0 → 1.0
  final Color trackColor;

  // Arco de 180°: empieza a la IZQUIERDA (180°), barre en sentido horario
  // hasta la DERECHA (360°/0°). El centro queda en la base del canvas.
  static const double _startDeg = 180.0;
  static const double _sweepDeg = 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Centro del arco en la base del canvas (y = altura total)
    final cx = size.width / 2;
    final cy = size.height; // centro en la base → semicírculo visible arriba
    final radius = size.width * 0.46;
    final strokeW = size.width * 0.08;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // --- Track (arco gris de fondo) ---
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(
      rect,
      _deg2rad(_startDeg),
      _deg2rad(_sweepDeg),
      false,
      trackPaint,
    );

    // --- Arco activo con gradiente rojo → ámbar → verde ---
    if (progress > 0.01) {
      final sweepActive = _deg2rad(_sweepDeg * progress);

      final gradientPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _deg2rad(_startDeg),
          endAngle: _deg2rad(_startDeg + _sweepDeg),
          colors: const [
            AppColors.gaugeRed,
            AppColors.gaugeAmber,
            AppColors.gaugeGreen,
          ],
          stops: const [0.0, 0.45, 1.0],
          tileMode: TileMode.clamp,
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        );

      canvas.drawArc(
        rect,
        _deg2rad(_startDeg),
        sweepActive,
        false,
        gradientPaint,
      );

      // --- Dot indicador en la punta del arco ---
      final endAngle = _deg2rad(_startDeg) + sweepActive;
      final dotX = cx + radius * math.cos(endAngle);
      final dotY = cy + radius * math.sin(endAngle);

      final dotColor = scoreGradientColor((progress * 100).round());

      canvas.drawCircle(
        Offset(dotX, dotY),
        strokeW * 0.65,
        Paint()
          ..color = AppColors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(dotX, dotY),
        strokeW * 0.45,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill,
      );
    }

  }

  static double _deg2rad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}
