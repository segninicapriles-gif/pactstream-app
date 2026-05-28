/// Fila de factor del score: icono + label + peso + barra animada + porcentaje.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/scoring_models.dart';

class ScoringFactorRow extends StatefulWidget {
  const ScoringFactorRow({
    super.key,
    required this.factor,
    this.animationDelay = Duration.zero,
  });

  final ScoringFactor factor;
  final Duration animationDelay;

  @override
  State<ScoringFactorRow> createState() => _ScoringFactorRowState();
}

class _ScoringFactorRowState extends State<ScoringFactorRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(widget.animationDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factor = widget.factor;
    final color = factor.color;
    final pct = factor.valuePct.clamp(0.0, 100.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono con tint
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Icon(factor.icon, size: 15, color: color),
              ),
              const SizedBox(width: AppSpacing.md),

              // Label
              Expanded(
                child: Text(
                  factor.label,
                  style: AppTypography.bodyS.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),

              // Peso del factor
              Text(
                'peso ${factor.weightPct}%',
                style: AppTypography.caption.copyWith(
                  color: context.colors.textHint,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Porcentaje
              SizedBox(
                width: 36,
                child: Text(
                  '${pct.round()}%',
                  textAlign: TextAlign.right,
                  style: AppTypography.bodyS.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),

          // Barra de progreso animada
          AnimatedBuilder(
            animation: _barAnimation,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  value: (pct / 100) * _barAnimation.value,
                  backgroundColor: context.colors.chipBg,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
