/// Badge visual del veredicto del dictamen IA.
///
/// Verde  → ok            "Sin objeciones"
/// Ámbar  → review_needed "Revisar"
/// Rojo   → block         "Bloqueante"
///
/// Diseñado para encajar en filas y headers sin ocupar demasiado espacio.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/ai_models.dart';

class AiVerdictBadge extends StatelessWidget {
  const AiVerdictBadge({
    super.key,
    required this.verdict,
    this.showIcon = true,
    this.compact = false,
  });

  final AiVerdict verdict;

  /// Si `false`, muestra solo el texto (sin icono).
  final bool showIcon;

  /// Si `true`, usa tamaño reducido para contextos muy apretados.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon, label) = _attrs(verdict);
    final fontSize = compact ? 10.0 : 11.0;
    final iconSize = compact ? 12.0 : 14.0;
    final hPad = compact ? 6.0 : 8.0;
    final vPad = compact ? 2.0 : 3.0;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color, IconData, String) _attrs(AiVerdict v) {
    switch (v) {
      case AiVerdict.ok:
        return (
          AppColors.success,
          AppColors.successBg,
          Icons.check_circle_outline,
          'Sin objeciones',
        );
      case AiVerdict.reviewNeeded:
        return (
          AppColors.warning,
          AppColors.warningBg,
          Icons.warning_amber_outlined,
          'Revisar',
        );
      case AiVerdict.block:
        return (
          AppColors.error,
          AppColors.errorBg,
          Icons.block_outlined,
          'Bloqueante',
        );
    }
  }
}

/// Badge de severidad de un finding individual.
/// Verde / Ámbar / Rojo con un punto de color.
class AiFindingSeverityDot extends StatelessWidget {
  const AiFindingSeverityDot({super.key, required this.severity});

  final AiFindingSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      AiFindingSeverity.green => AppColors.success,
      AiFindingSeverity.amber => AppColors.warning,
      AiFindingSeverity.red   => AppColors.error,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
