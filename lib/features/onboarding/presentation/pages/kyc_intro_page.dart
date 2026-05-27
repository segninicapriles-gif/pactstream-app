import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Pantalla F-01 del Design Handoff — Bridge pre-Onfido.
///
/// Diseño según mockups F-01. Tras pulsar "Empezar verificación" se navega
/// a /onboarding/identity/capture (mock que simula el SDK de Onfido).
class KycIntroPage extends ConsumerWidget {
  const KycIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text('Verifica tu identidad',
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
                  color: AppColors.infoBg,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 44,
                  color: AppColors.psBlue,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Verifica tu identidad',
                  textAlign: TextAlign.center, style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Para firmar pactos y mover dinero, necesitamos confirmar quién eres. Tarda 2 minutos.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.ink600),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _BulletPoint(
                title: 'Escrow regulado',
                subtitle:
                    'Tu dinero queda en custodia bajo licencia europea (Mangopay).',
              ),
              const _BulletPoint(
                title: 'Firma legal eIDAS',
                subtitle: 'Tu pacto tiene validez ante un juez (Signaturit).',
              ),
              const _BulletPoint(
                title: 'Confianza para las 3 partes',
                subtitle: 'Promotor, técnico y constructora.',
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => context.go(AppRoutes.kycCapture),
                label: const Text('Empezar verificación'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Hacerlo más tarde'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Verificación gestionada por Onfido (próximamente · simulada en desarrollo).',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successBg,
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
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
