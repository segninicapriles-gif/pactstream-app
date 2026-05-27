import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Helper centralizado para presentar el estado de un pacto o hito.
///
/// Devuelve etiqueta humana, color de fondo y color de texto. Mantenemos
/// la lógica fuera de los widgets para evitar duplicar el switch en cada
/// pantalla que muestra estado.
class PactStateStyle {
  const PactStateStyle({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  static PactStateStyle forPactState(String state) {
    switch (state) {
      case 'draft':
        return PactStateStyle(
          label: 'Borrador',
          bg: AppColors.ink100,
          fg: AppColors.ink600,
        );
      case 'inviting':
        return PactStateStyle(
          label: 'Invitaciones',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
      case 'signed':
        return PactStateStyle(
          label: 'Firmado',
          bg: AppColors.infoBg,
          fg: AppColors.psBlue,
        );
      case 'funding':
        return PactStateStyle(
          label: 'Pendiente depósito',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
      case 'active':
      case 'in_execution':
        return const PactStateStyle(
          label: 'Activo',
          bg: AppColors.successBg,
          fg: AppColors.success,
        );
      case 'in_dispute':
        return const PactStateStyle(
          label: 'En disputa',
          bg: AppColors.errorBg,
          fg: AppColors.error,
        );
      case 'completed':
      case 'closed':
        return PactStateStyle(
          label: 'Completado',
          bg: AppColors.ink200,
          fg: AppColors.ink700,
        );
      case 'cancelled':
        return PactStateStyle(
          label: 'Cancelado',
          bg: AppColors.errorBg,
          fg: AppColors.error,
        );
      default:
        return PactStateStyle(
          label: state,
          bg: AppColors.ink100,
          fg: AppColors.ink600,
        );
    }
  }

  static PactStateStyle forMilestoneState(String state) {
    switch (state) {
      case 'pending':
        return PactStateStyle(
          label: 'Pendiente',
          bg: AppColors.ink100,
          fg: AppColors.ink600,
        );
      case 'in_execution':
      case 'in_progress':
        return const PactStateStyle(
          label: 'En curso',
          bg: AppColors.infoBg,
          fg: AppColors.psBlue,
        );
      case 'ready_for_review':
        return const PactStateStyle(
          label: 'Para revisar',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
      case 'in_validation':
        return const PactStateStyle(
          label: 'Validando',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
      case 'info_requested':
        return const PactStateStyle(
          label: 'Info pedida',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
      case 'rejected_by_tech':
        return const PactStateStyle(
          label: 'Rechazado',
          bg: AppColors.errorBg,
          fg: AppColors.error,
        );
      case 'approved_by_tech':
        return const PactStateStyle(
          label: 'Aprob. técnico',
          bg: AppColors.infoBg,
          fg: AppColors.psBlue,
        );
      case 'awaiting_promotor':
        return const PactStateStyle(
          label: 'Esperando promotor',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
      case 'disputed':
      case 'rejected':
      case 'in_dispute':
        return const PactStateStyle(
          label: 'En disputa',
          bg: AppColors.errorBg,
          fg: AppColors.error,
        );
      case 'paid':
        return const PactStateStyle(
          label: 'Pagado',
          bg: AppColors.successBg,
          fg: AppColors.success,
        );
      default:
        return PactStateStyle(
          label: state,
          bg: AppColors.ink100,
          fg: AppColors.ink600,
        );
    }
  }
}

/// Pill visual con el estilo del estado.
class PactStateBadge extends StatelessWidget {
  const PactStateBadge({
    super.key,
    required this.style,
    this.compact = false,
  });

  final PactStateStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: style.label,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(
            style.label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: style.fg,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
