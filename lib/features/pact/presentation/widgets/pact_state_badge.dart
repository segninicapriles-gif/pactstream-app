import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
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

  static PactStateStyle forPactState(String state, BuildContext context) {
    switch (state) {
      case 'draft':
        return PactStateStyle(
          label: 'Borrador',
          bg: context.colors.chipBg,
          fg: context.colors.chipText,
        );
      case 'inviting':
        return PactStateStyle(
          label: 'Invitaciones',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'signing':
        return PactStateStyle(
          label: 'En firma',
          bg: context.colors.infoBg,
          fg: context.colors.brandAccent,
        );
      case 'signed':
        return PactStateStyle(
          label: 'Firmado',
          bg: context.colors.infoBg,
          fg: context.colors.brandAccent,
        );
      case 'funding':
        return PactStateStyle(
          label: 'Pendiente depósito',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'funded':
        return PactStateStyle(
          label: 'Fondeada',
          bg: context.colors.infoBg,
          fg: context.colors.brandAccent,
        );
      case 'active':
      case 'in_execution':
        return PactStateStyle(
          label: 'Activo',
          bg: context.colors.successBg,
          fg: AppColors.success,
        );
      case 'paused_pending_tech':
        return PactStateStyle(
          label: 'Pausada',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'in_dispute':
      case 'disputed':
        return PactStateStyle(
          label: 'En disputa',
          bg: context.colors.errorBg,
          fg: AppColors.error,
        );
      // "Completado" = resultado bueno alcanzado (obra terminada y pagada) →
      // VERDE, igual que `completado` en CostPact. Distinto de "cerrado",
      // que es archivado/sin desenlace → gris.
      case 'completed':
        return PactStateStyle(
          label: 'Completado',
          bg: context.colors.successBg,
          fg: AppColors.success,
        );
      case 'closed':
        return PactStateStyle(
          label: 'Cerrado',
          bg: context.colors.border,
          fg: context.colors.textPrimary,
        );
      case 'cancelled':
        return PactStateStyle(
          label: 'Cancelado',
          bg: context.colors.errorBg,
          fg: AppColors.error,
        );
      default:
        return PactStateStyle(
          label: state,
          bg: context.colors.chipBg,
          fg: context.colors.chipText,
        );
    }
  }

  static PactStateStyle forMilestoneState(String state, BuildContext context) {
    switch (state) {
      case 'pending':
        return PactStateStyle(
          label: 'Pendiente',
          bg: context.colors.chipBg,
          fg: context.colors.chipText,
        );
      case 'in_execution':
      case 'in_progress':
        return PactStateStyle(
          label: 'En curso',
          bg: context.colors.infoBg,
          fg: context.colors.brandAccent,
        );
      case 'ready_for_review':
        return PactStateStyle(
          label: 'Para revisar',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'in_validation':
        return PactStateStyle(
          label: 'Validando',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'info_requested':
        return PactStateStyle(
          label: 'Info pedida',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'rejected_by_tech':
        return PactStateStyle(
          label: 'Rechazado',
          bg: context.colors.errorBg,
          fg: AppColors.error,
        );
      case 'approved_by_tech':
        return PactStateStyle(
          label: 'Aprob. técnico',
          bg: context.colors.infoBg,
          fg: context.colors.brandAccent,
        );
      case 'awaiting_promotor':
        return PactStateStyle(
          label: 'Esperando promotor',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'disputed':
      case 'rejected':
      case 'in_dispute':
        return PactStateStyle(
          label: 'En disputa',
          bg: context.colors.errorBg,
          fg: AppColors.error,
        );
      case 'paid':
        return PactStateStyle(
          label: 'Pagado',
          bg: context.colors.successBg,
          fg: AppColors.success,
        );
      case 'paused_no_predeposit':
        return PactStateStyle(
          label: 'Obra paralizada',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'paused_pending_tech':
        return PactStateStyle(
          label: 'Pendiente técnico',
          bg: context.colors.warningBg,
          fg: AppColors.warning,
        );
      case 'cancelled':
        return PactStateStyle(
          label: 'Cancelado',
          bg: context.colors.errorBg,
          fg: AppColors.error,
        );
      case 'completed':
        return PactStateStyle(
          label: 'Completado',
          bg: context.colors.border,
          fg: context.colors.textPrimary,
        );
      default:
        return PactStateStyle(
          label: state.replaceAll('_', ' '),
          bg: context.colors.chipBg,
          fg: context.colors.chipText,
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
