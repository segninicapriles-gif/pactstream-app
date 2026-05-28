/// Trust Score page — Opción A: layout completamente claro.
///
/// El gauge vive en una card blanca con sombra sobre fondo ink50.
/// Sin hero navy — coherente con el resto de la app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/scoring_models.dart';
import '../../data/scoring_providers.dart';
import '../widgets/pact_score_gauge.dart';
import '../widgets/scoring_factor_row.dart';

class TrustScorePage extends ConsumerWidget {
  const TrustScorePage({
    super.key,
    required this.pactId,
    required this.pactTitle,
  });

  final String pactId;
  final String pactTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(pactHealthProvider(pactId));

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Column(
          children: [
            Text(
              'TRUST SCORE',
              style: AppTypography.caption.copyWith(
                color: AppColors.psCyan,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              pactTitle,
              style: AppTypography.bodyS.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
      body: healthAsync.when(
        loading: () => const DetailSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudo cargar el score',
          message: e.toString(),
          onRetry: () => ref.invalidate(pactHealthProvider(pactId)),
          scrollable: false,
        ),
        data: (health) => _ScoreBody(health: health),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body principal
// ---------------------------------------------------------------------------

class _ScoreBody extends StatelessWidget {
  const _ScoreBody({required this.health});

  final PactHealthScore health;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // === CTA Financiación (arriba, destacado) ===
          _FinancingCtaCard(score: health.score),

          const SizedBox(height: AppSpacing.lg),

          // === Gauge card ===
          PactScoreGauge(
            score: health.score,
            label: health.label,
            labelColor: health.color,
            previousScore: health.score - 4, // TODO: cargar snapshot anterior
          ),

          const SizedBox(height: AppSpacing.lg),

          // === Factores del score ===
          _FactorsCard(health: health),

          const SizedBox(height: AppSpacing.lg),

          // === Estado actual ===
          _StatusCard(health: health),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA Financiación basada en Trust Score
// ---------------------------------------------------------------------------

class _FinancingCtaCard extends StatelessWidget {
  const _FinancingCtaCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final unlocked = score >= 75;

    return Container(
      decoration: BoxDecoration(
        gradient: unlocked
            ? const LinearGradient(
                colors: [AppColors.psBlue, AppColors.psNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: unlocked ? null : context.colors.card,
        borderRadius: AppRadius.lgAll,
        border: unlocked
            ? null
            : Border.all(color: context.colors.border),
        boxShadow: unlocked ? const [] : AppShadows.soft,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.white.withValues(alpha:0.15)
                  : context.colors.infoBg,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: unlocked ? Colors.white : context.colors.brandAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      unlocked ? 'Financiación disponible' : 'Próximamente',
                      style: AppTypography.bodyS.copyWith(
                        fontWeight: FontWeight.w700,
                        color: unlocked ? Colors.white : context.colors.textPrimary,
                      ),
                    ),
                    if (!unlocked) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.infoBg,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          'Score ≥ 75',
                          style: AppTypography.caption.copyWith(
                            color: context.colors.brandAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? 'Tu Trust Score te da acceso a líneas de crédito preferentes.'
                      : 'Financiación basada en tu historial de obra.',
                  style: AppTypography.caption.copyWith(
                    color: unlocked
                        ? Colors.white.withValues(alpha:0.8)
                        : context.colors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: unlocked ? Colors.white.withValues(alpha:0.7) : context.colors.textHint,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Factores del score
// ---------------------------------------------------------------------------

class _FactorsCard extends StatelessWidget {
  const _FactorsCard({required this.health});

  final PactHealthScore health;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Factores del score',
            style: AppTypography.h3,
          ),
          const SizedBox(height: AppSpacing.md),
          ...health.factors.asMap().entries.map((entry) {
            return ScoringFactorRow(
              factor: entry.value,
              animationDelay: Duration(milliseconds: entry.key * 100),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estado actual (status items)
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.health});

  final PactHealthScore health;

  @override
  Widget build(BuildContext context) {
    final items = _buildStatusItems(health);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado actual', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          ...items.map((item) => _StatusItem(item: item)),
        ],
      ),
    );
  }

  List<_StatusItemData> _buildStatusItems(PactHealthScore h) {
    return [
      _StatusItemData(
        icon: h.milestoneCompliancePct >= 75
            ? Icons.check_circle_outline
            : Icons.warning_amber_outlined,
        color: h.milestoneCompliancePct >= 75
            ? AppColors.success
            : AppColors.warning,
        title: 'Hitos al día',
        subtitle: '${h.milestoneCompliancePct.round()}% completados',
      ),
      _StatusItemData(
        icon: h.iaEvidenceScore >= 75
            ? Icons.smart_toy_outlined
            : Icons.warning_amber_outlined,
        color: h.iaEvidenceScore >= 75 ? AppColors.success : AppColors.warning,
        title: 'Evidencia verificada por IA',
        subtitle: 'Score medio ${h.iaEvidenceScore.round()}/100',
      ),
      _StatusItemData(
        icon: h.noDisputesPct >= 100
            ? Icons.shield_outlined
            : Icons.gavel_outlined,
        color: h.noDisputesPct >= 100 ? AppColors.success : AppColors.error,
        title: h.noDisputesPct >= 100
            ? 'Sin disputas abiertas'
            : 'Disputa activa',
        subtitle: h.noDisputesPct >= 100 ? 'Flujo nominal' : 'Requiere atención',
      ),
      _StatusItemData(
        icon: h.validationSpeedPct >= 75
            ? Icons.bolt_outlined
            : Icons.hourglass_bottom_outlined,
        color: h.validationSpeedPct >= 75
            ? AppColors.success
            : AppColors.warning,
        title: 'Ciclo de validación',
        subtitle: h.validationSpeedPct >= 75
            ? '< 7 días promedio'
            : '> 7 días promedio',
      ),
    ];
  }
}

class _StatusItemData {
  const _StatusItemData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.item});

  final _StatusItemData item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 16, color: item.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.bodyS.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: AppTypography.caption.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

// _ErrorView ahora usa ErrorStateView de core/widgets/empty_state_view.dart.
