import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/l10n_extension.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Pantalla F-01 del Design Handoff — intro pre-KYC.
///
/// Tras pulsar "Empezar verificación" se navega a
/// /onboarding/identity/capture, que abre la sesión de Veriff (proveedor
/// real integrado). Nota: los mockups originales referenciaban Onfido —
/// el equipo pivotó a Veriff, unificado en la UI el 2026-07-17.
class KycIntroPage extends ConsumerWidget {
  const KycIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text(l10n.kycIntroTitle,
            style: AppTypography.h3.copyWith(color: AppColors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              // Hero icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.infoBg,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 44,
                  color: context.colors.brandAccent,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.kycIntroTitle,
                  textAlign: TextAlign.center, style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.kycIntroBody,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              // ⚠️ Los dos primeros bullets hacen AFIRMACIONES REGULATORIAS
              // (licencia europea de Mangopay, validez eIDAS) que solo son
              // ciertas en la UE. Traducirlas a inglés no las hace válidas en
              // EE. UU., donde el marco de firma es ESIGN Act / UETA y el
              // escrow se licencia por estado. Pendiente de revisión legal
              // antes de lanzar fuera de Europa — ver handoff.
              _BulletPoint(
                title: l10n.kycBulletEscrowTitle,
                subtitle: l10n.kycBulletEscrowBody,
              ),
              _BulletPoint(
                title: l10n.kycBulletSignatureTitle,
                subtitle: l10n.kycBulletSignatureBody,
              ),
              _BulletPoint(
                title: l10n.kycBulletTrustTitle,
                subtitle: l10n.kycBulletTrustBody,
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => context.go(AppRoutes.kycCapture),
                label: Text(l10n.kycStartCta),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l10n.kycLaterCta),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.kycProviderNote,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.successBg,
            ),
            child: const Icon(Icons.check, size: 14, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                Text(subtitle,
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
