import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        Text('Identidad verificada',
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ya puedes firmar pactos y mover dinero en custodia.',
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
                  label: 'Verificada el',
                  value: AppFormatters.dateTimeDetail(DateTime.now())),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(label: 'Validada por', value: 'Veriff'),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(
                  label: 'Operaciones',
                  value: 'Disponibles ✓',
                  valueColor: AppColors.success),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => context.go(AppRoutes.home),
          label: const Text('Continuar al inicio'),
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
          child: const Icon(Icons.access_time,
              size: 56, color: AppColors.warning),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Revisión en curso',
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Hemos recibido tu documentación. Un agente revisará tu identidad en menos de 24 horas.',
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
                  label: 'Recibido', value: AppFormatters.dateTimeDetail(DateTime.now())),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(label: 'Plazo máximo', value: '24 horas hábiles'),
              const SizedBox(height: AppSpacing.xs),
              _ResultRow(label: 'Operaciones', value: 'Limitadas hasta aprobación'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Te avisaremos por email y notificación cuando esté lista.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Volver a inicio'),
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
        Text('Verificación rechazada',
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No hemos podido validar tu identidad con la documentación aportada.',
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
              Text('Motivo',
                  style: AppTypography.caption.copyWith(color: AppColors.error)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Documento ilegible o caducado. Por favor, vuelve a intentarlo con un documento en buen estado.',
                style: AppTypography.body,
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          onPressed: () => context.go(AppRoutes.kycCapture),
          label: const Text('Volver a intentar'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Hacerlo más tarde'),
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
