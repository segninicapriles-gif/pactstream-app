/// Card de reputación del usuario: score, tier badge, escudos, componentes.
///
/// Reemplaza el placeholder _ReputationCard de profile_page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/scoring_models.dart';
import '../../data/scoring_providers.dart';
import 'pact_score_shields.dart';
import 'pact_score_tier_badge.dart';

class UserReputationCard extends ConsumerWidget {
  const UserReputationCard({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repAsync = ref.watch(userReputationProvider(userId));

    return repAsync.when(
      loading: () => _CardShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: const [
              ShimmerBox(height: 68, width: 68, radius: 34),
              SizedBox(height: AppSpacing.md),
              ShimmerBox(height: 14, width: 120, radius: 4),
              SizedBox(height: AppSpacing.sm),
              ShimmerBox(height: 10, width: 180, radius: 4),
            ],
          ),
        ),
      ),
      error: (_, __) => _CardShell(
        child: _EmptyState(),
      ),
      data: (rep) => _ReputationContent(rep: rep),
    );
  }
}

// ---------------------------------------------------------------------------
// Content con datos reales
// ---------------------------------------------------------------------------

class _ReputationContent extends StatelessWidget {
  const _ReputationContent({required this.rep});

  final UserReputation rep;

  @override
  Widget build(BuildContext context) {
    final isElite = rep.tier == ReputationTier.elite;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Score + shields + badge ---
          Row(
            children: [
              // Score circle
              _ScoreBadgeCircle(score: rep.score, tier: rep.tier),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PactScoreTierBadge(tier: rep.tier),
                    const SizedBox(height: 6),
                    PactScoreShields(
                      filled: rep.shieldsFilled,
                      tier: rep.tier,
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rep.summaryText,
                      style: AppTypography.caption.copyWith(
                        color: context.colors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // --- Divider ---
          Divider(color: context.colors.borderSubtle, height: 1),
          const SizedBox(height: AppSpacing.lg),

          // --- Componentes del score ---
          Text(
            'Factores de reputación',
            style: AppTypography.label.copyWith(
              color: context.colors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...rep.components.entries.map(
            (e) => _ComponentRow(
              componentKey: e.key,
              value: e.value,
              tier: rep.tier,
            ),
          ),

          // --- Elite badge extra ---
          if (isElite) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.tierElite1, AppColors.tierElite2],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Profesional de confianza máxima · PactStream Elite',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score circle con color de tier
// ---------------------------------------------------------------------------

class _ScoreBadgeCircle extends StatelessWidget {
  const _ScoreBadgeCircle({required this.score, required this.tier});

  final int score;
  final ReputationTier tier;

  @override
  Widget build(BuildContext context) {
    final color = tier.color;
    final isElite = tier == ReputationTier.elite;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tier.bgColor,
        border: Border.all(color: color, width: 2.5),
      ),
      child: Center(
        child: isElite
            ? ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.tierElite1, AppColors.tierElite2],
                ).createShader(bounds),
                child: Text(
                  '$score',
                  style: AppTypography.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              )
            : Text(
                '$score',
                style: AppTypography.h2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fila de componente del score de reputación
// ---------------------------------------------------------------------------

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    super.key,
    required this.componentKey,
    required this.value,
    required this.tier,
  });

  final String componentKey;
  final dynamic value; // 0-100
  final ReputationTier tier;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(componentKey.toLowerCase());
    final pct = (value as num).toDouble().clamp(0.0, 100.0);
    final color = tier.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: context.colors.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 32,
            child: Text(
              '${pct.round()}',
              textAlign: TextAlign.right,
              style: AppTypography.bodyS.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(String k) => switch (k) {
        'payment_speed_pct'    => 'Velocidad de pago',
        'no_disputes_pct'      => 'Sin disputas',
        'completion_rate_pct'  => 'Tasa de finalización',
        'completion_pct'       => 'Finalización',
        'evidence_quality_pct' => 'Calidad de evidencia',
        'validation_speed_pct' => 'Velocidad validación',
        'sign_rate_pct'        => 'Tasa de firma',
        // Keys que el backend puede enviar sin sufijo _pct
        'completion'           => 'Finalización',
        'no_disputes'          => 'Sin disputas',
        'evidence_quality'     => 'Calidad de evidencia',
        'payment_speed'        => 'Velocidad de pago',
        'validation_speed'     => 'Velocidad validación',
        // fallback legible: quita sufijos técnicos y capitaliza
        _  => _humanize(k),
      };

  static String _humanize(String k) {
    final clean = k.replaceAll('_pct', '').replaceAll('_', ' ');
    if (clean.isEmpty) return k;
    return clean[0].toUpperCase() + clean.substring(1);
  }
}

// ---------------------------------------------------------------------------
// Estado vacío (sin reputación calculada aún)
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.colors.chipBg,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shield_outlined,
              color: context.colors.textHint, size: 26),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Sin actividad todavía',
          style:
              AppTypography.body.copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Tu reputación se construye con cada pacto cerrado, hito validado a tiempo y ausencia de disputas.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary, height: 1.4),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shell del card (frame común)
// ---------------------------------------------------------------------------

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.border),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
