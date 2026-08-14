import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_extension.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';

/// Pantalla F-02 del Design Handoff — resultado post-KYC (Veriff).
///
/// 3 variantes según resultado: verified, pending_review, rejected.
/// El status llega como query param: `?status=verified`.
class KycResultPage extends ConsumerWidget {
  const KycResultPage({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: switch (status) {
            'verified' => _VerifiedResult(),
            'pending_review' => _PendingResult(),
            'rejected' => _RejectedResult(),
            // SEGURIDAD: fallback al estado MÁS restrictivo. Un status
            // desconocido/manipulado nunca debe mostrar "verificado" ni
            // habilitar operaciones; se trata como revisión pendiente.
            _ => _PendingResult(),
          },
        ),
      ),
    );
  }
}

class _VerifiedResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.successBg,
          ),
          child: const Icon(Icons.check_circle,
              size: 56, color: AppColors.success),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(context.l10n.kycVerifiedTitle,
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.kycVerifiedBody,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.successBg,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            children: [
              _ResultRow(
                  label: context.l10n.kycVerifiedAtLabel,
                  // `dateTimeDetail` ya sigue el idioma activo: "15 oct 2024 a
                  // las 11:45" en español, "Oct 15, 2024 at 11:45 AM" en
                  // inglés. No hay que formatear nada a mano aquí.
                  value: AppFormatters.dateTimeDetail(DateTime.now())),
              const SizedBox(height: AppSpacing.xs),
              // "Veriff" es el nombre del proveedor: no se traduce.
              _ResultRow(
                  label: context.l10n.kycValidatedByLabel, value: 'Veriff'),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(
                  label: context.l10n.kycOperationsLabel,
                  value: context.l10n.kycOperationsAvailable,
                  valueColor: AppColors.success),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => context.go(AppRoutes.home),
          label: Text(context.l10n.kycContinueHome),
        ),
      ],
    );
  }
}

class _PendingResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.warningBg,
          ),
          child: Icon(Icons.access_time,
              size: 56, color: context.colors.warningText),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(context.l10n.kycPendingTitle,
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.kycPendingBody,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.warningBg,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            children: [
              _ResultRow(
                  label: context.l10n.kycReceivedLabel,
                  value: AppFormatters.dateTimeDetail(DateTime.now())),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(
                  label: context.l10n.kycMaxDeadlineLabel,
                  value: context.l10n.kycMaxDeadlineValue),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(
                  label: context.l10n.kycOperationsLabel,
                  value: context.l10n.kycOperationsLimited),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.kycPendingNotice,
          textAlign: TextAlign.center,
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text(context.l10n.kycBackHome),
        ),
      ],
    );
  }
}

class _RejectedResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.errorBg,
          ),
          child: const Icon(Icons.cancel, size: 56, color: AppColors.error),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(context.l10n.kycRejectedTitle,
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.kycRejectedBody,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.errorBg,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.kycRejectedReasonLabel,
                  style: AppTypography.caption.copyWith(color: context.colors.errorText)),
              const SizedBox(height: AppSpacing.xs),
              // Motivo GENÉRICO: hoy se muestra siempre el mismo, venga el
              // rechazo de Veriff por lo que venga. Cuando el backend devuelva
              // el motivo real habrá que mapearlo a claves propias; decirle al
              // usuario "documento ilegible" cuando el problema fue otro es
              // peor que no decirle nada concreto.
              Text(
                context.l10n.kycRejectedReasonDefault,
                style: AppTypography.body,
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          onPressed: () => context.go(AppRoutes.kycCapture),
          label: Text(context.l10n.kycRetryCta),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text(context.l10n.kycLaterCta),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary)),
        Text(value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? context.colors.textPrimary,
            )),
      ],
    );
  }
}
