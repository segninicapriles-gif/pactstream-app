/// Indicador visual de reputación con 5 escudos (reemplaza las ★★★★★).
/// Semántica de protección/confianza, alineada con el producto fintech.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/scoring_models.dart';

class PactScoreShields extends StatelessWidget {
  const PactScoreShields({
    super.key,
    required this.filled,
    required this.tier,
    this.size = 22.0,
    this.spacing = 4.0,
  });

  /// Número de escudos rellenos (0-5).
  final int filled;
  final ReputationTier tier;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isFilled = i < filled.clamp(0, 5);
        final isElite = tier == ReputationTier.elite;

        if (isFilled && isElite) {
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? spacing : 0),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.tierElite1, AppColors.tierElite2],
              ).createShader(bounds),
              child: Icon(Icons.shield, size: size, color: Colors.white),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? spacing : 0),
          child: Icon(
            isFilled ? Icons.shield : Icons.shield_outlined,
            size: size,
            color: isFilled ? tier.color : AppColors.ink300,
          ),
        );
      }),
    );
  }
}
