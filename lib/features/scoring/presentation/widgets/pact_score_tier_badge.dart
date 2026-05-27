/// Badge de tier de reputación con color e icono distintivo por nivel.
/// Reemplaza el genérico "NIVEL ORO" con identidad visual propia.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/scoring_models.dart';

class PactScoreTierBadge extends StatelessWidget {
  const PactScoreTierBadge({
    super.key,
    required this.tier,
    this.size = _BadgeSize.medium,
  });

  final ReputationTier tier;
  final _BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final color = tier.color;
    final bg    = tier.bgColor;
    final isElite = tier == ReputationTier.elite;

    final badgeContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono escudo con degradado para elite
        if (isElite)
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [tier.color, AppColors.tierElite2],
            ).createShader(bounds),
            child: Icon(
              Icons.shield,
              size: size.iconSize,
              color: Colors.white,
            ),
          )
        else
          Icon(Icons.shield, size: size.iconSize, color: color),

        SizedBox(width: size.gap),

        if (isElite)
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [tier.color, AppColors.tierElite2],
            ).createShader(bounds),
            child: Text(
              tier.label.toUpperCase(),
              style: AppTypography.label.copyWith(
                fontSize: size.fontSize,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          )
        else
          Text(
            tier.label.toUpperCase(),
            style: AppTypography.label.copyWith(
              fontSize: size.fontSize,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.paddingH,
        vertical: size.paddingV,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: badgeContent,
    );
  }
}

enum _BadgeSize { small, medium, large }

extension _BadgeSizeX on _BadgeSize {
  double get iconSize => switch (this) {
        _BadgeSize.small  => 12,
        _BadgeSize.medium => 14,
        _BadgeSize.large  => 18,
      };
  double get fontSize => switch (this) {
        _BadgeSize.small  => 9,
        _BadgeSize.medium => 10,
        _BadgeSize.large  => 12,
      };
  double get gap => switch (this) {
        _BadgeSize.small  => 3,
        _BadgeSize.medium => 4,
        _BadgeSize.large  => 6,
      };
  double get paddingH => switch (this) {
        _BadgeSize.small  => 8,
        _BadgeSize.medium => 10,
        _BadgeSize.large  => 14,
      };
  double get paddingV => switch (this) {
        _BadgeSize.small  => 3,
        _BadgeSize.medium => 4,
        _BadgeSize.large  => 6,
      };
}
