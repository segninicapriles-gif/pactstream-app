import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/arco_gauge.dart';
import '../../../../core/widgets/cifra_viva.dart';
import '../../../../core/widgets/pressable_card.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../scoring/data/scoring_models.dart';
import '../../../scoring/data/scoring_providers.dart';
import '../../../pact/presentation/widgets/pact_state_badge.dart';
import '../../../scoring/presentation/widgets/pact_score_shields.dart';
import '../../data/dashboard_data.dart';

/// Widgets compartidos por los 3 dashboards (promotor / constructor / técnico).

// =====================================================================
// Hero KPI card (la card oscura grande con el dato principal)
// =====================================================================

class HeroKpiCard extends StatelessWidget {
  const HeroKpiCard({
    super.key,
    required this.eyebrow,
    required this.amount,
    required this.subtitle,
    required this.subtitleColor,
    this.icon = Icons.shield_outlined,
    this.monetary = true,
  });

  final String eyebrow;
  final String amount;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;

  /// `true` (por defecto) cuando [amount] es un importe — se renderiza con
  /// Cifra Viva (JetBrains Mono, entero fuerte + decimales/símbolo tenues).
  /// Pasar `false` cuando [amount] es un conteo (p. ej. nº de obras), no un
  /// importe.
  final bool monetary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$eyebrow: $amount. $subtitle',
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.psNavy,
        borderRadius: AppRadius.lgAll,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.psNavy, AppColors.ink800],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: AppTypography.caption.copyWith(color: AppColors.psCyan)),
          const SizedBox(height: AppSpacing.xs),
          if (monetary)
            CifraViva(
              formatted: amount,
              size: 36,
              color: AppColors.white,
            )
          else
            Text(amount,
                style: AppTypography.displayL
                    .copyWith(color: AppColors.white, fontSize: 36)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(icon, size: 14, color: subtitleColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(subtitle,
                    style: AppTypography.bodyS.copyWith(color: subtitleColor)),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// =====================================================================
// Hero KPI card CON Trust Score (split: financiero izq. | score der.)
// =====================================================================

/// Versión del HeroKpiCard que integra el Trust Score del usuario
/// en un panel derecho dentro del mismo bloque navy.
class HeroKpiScoreCard extends ConsumerWidget {
  const HeroKpiScoreCard({
    super.key,
    required this.eyebrow,
    required this.amount,
    required this.subtitle,
    required this.subtitleColor,
    this.secondaryLabel,
    this.secondaryValue,
    this.icon = Icons.shield_outlined,
    this.gradientColors,
    this.monetary = true,
    this.secondaryMonetary = true,
  });

  final String eyebrow;
  final String amount;
  final String subtitle;
  final Color subtitleColor;
  /// Etiqueta de un segundo dato (ej. "PRÓXIMA LIBERACIÓN")
  final String? secondaryLabel;
  final String? secondaryValue;
  final IconData icon;

  /// `true` (por defecto) cuando [amount] es un importe — Cifra Viva. Pasar
  /// `false` cuando [amount] es un conteo (p. ej. nº de obras del técnico).
  final bool monetary;

  /// Igual que [monetary] pero para [secondaryValue].
  final bool secondaryMonetary;

  /// Optional custom gradient colors. Defaults to [AppColors.psNavy, AppColors.ink800].
  /// Pass a custom list to differentiate hero cards per role (e.g. técnico).
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repAsync = ref.watch(myReputationProvider);

    final colors = gradientColors ?? const [AppColors.psNavy, AppColors.ink800];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── Panel izquierdo: KPI financiero ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.psCyan, letterSpacing: 1.0),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (monetary)
                  CifraViva(
                    formatted: amount,
                    size: 30,
                    color: AppColors.white,
                  )
                else
                  Text(
                    amount,
                    style: AppTypography.displayL.copyWith(
                      color: AppColors.white,
                      fontSize: 30,
                      height: 1.1,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(icon, size: 13, color: subtitleColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style:
                            AppTypography.bodyS.copyWith(color: subtitleColor),
                      ),
                    ),
                  ],
                ),
                if (secondaryLabel != null && secondaryValue != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    secondaryLabel!,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha:0.45),
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (secondaryMonetary)
                    CifraViva(
                      formatted: secondaryValue!,
                      size: 16,
                      color: AppColors.white,
                    )
                  else
                    Text(
                      secondaryValue!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ],
            ),
          ),

          // ─── Divisor ───
          Container(
            width: 1,
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: Colors.white.withValues(alpha:0.15),
          ),

          // ─── Panel derecho: Trust Score ───
          repAsync.when(
            loading: () => _ScorePanel.loading(),
            error: (_, __) => _ScorePanel.empty(),
            data: (rep) => _ScorePanel(rep: rep),
          ),
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.rep}) : _loading = false;
  const _ScorePanel.loading() : rep = null, _loading = true;
  const _ScorePanel.empty() : rep = null, _loading = false;

  final UserReputation? rep;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 64,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    if (rep == null) {
      return SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SCORE',
              style: AppTypography.caption.copyWith(
                color: Colors.white54,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.shield_outlined, color: Colors.white38, size: 28),
          ],
        ),
      );
    }

    return _AnimatedScorePanel(rep: rep!);
  }
}

/// Score panel con animación de conteo y arco progresivo.
class _AnimatedScorePanel extends StatefulWidget {
  const _AnimatedScorePanel({required this.rep});
  final UserReputation rep;

  @override
  State<_AnimatedScorePanel> createState() => _AnimatedScorePanelState();
}

class _AnimatedScorePanelState extends State<_AnimatedScorePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scoreAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rep = widget.rep;
    final color = rep.tier.color;
    final isElite = rep.tier == ReputationTier.elite;

    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, child) {
        final displayScore = (_scoreAnim.value * rep.score).round();
        final ringProgress = _scoreAnim.value * (rep.score / 100);

        return SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TRUST SCORE',
                style: AppTypography.caption.copyWith(
                  color: Colors.white54,
                  fontSize: 7,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              // Score gauge · Sistema ARCO (arco 270°, ya animado por el
              // AnimationController del panel — no re-animar internamente).
              ArcoGauge(
                size: 50,
                progress: ringProgress,
                color: color,
                trackColor: color.withValues(alpha: 0.2),
                animate: false,
                semanticLabel: 'Trust Score',
                child: isElite
                    ? ShaderMask(
                        shaderCallback: (b) => LinearGradient(
                          colors: [
                            AppColors.tierElite1,
                            AppColors.tierElite2,
                          ],
                        ).createShader(b),
                        child: Text(
                          '$displayScore',
                          style: AppTypography.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1,
                          ),
                        ),
                      )
                    : Text(
                        '$displayScore',
                        style: AppTypography.body.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1,
                        ),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                rep.tier.label.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              PactScoreShields(
                filled: rep.shieldsFilled,
                tier: rep.tier,
                size: 11,
                spacing: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// Mini KPI card (las 2 cards blancas debajo del hero)
// =====================================================================

class MiniKpiCard extends StatelessWidget {
  const MiniKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.subtitleColor,
    @Deprecated('ARCO §8b prohíbe borde-acento lateral') this.accentColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    return Semantics(
      label: '$label: $value${subtitle != null ? '. $subtitle' : ''}',
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: co.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: context.colors.textTertiary)),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: AppTypography.h2.copyWith(
                  fontSize: 22,
                  color: context.colors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: AppTypography.bodyS.copyWith(
                    color: subtitleColor ?? context.colors.textTertiary)),
          ],
        ],
      ),
      ),
    );
  }
}

// =====================================================================
// Section header
// =====================================================================

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'Ver todas →',
  });

  final String title;
  /// Si se pasa, aparece el link "Ver todas →" a la derecha.
  final VoidCallback? onViewAll;
  final String viewAllLabel;

  @override
  Widget build(BuildContext context) {
    if (onViewAll == null) {
      return Text(title, style: AppTypography.h3.copyWith(fontSize: 18, color: context.colors.textPrimary));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: AppTypography.h3.copyWith(fontSize: 18, color: context.colors.textPrimary)),
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            viewAllLabel,
            style: AppTypography.bodyS.copyWith(
              color: context.colors.brandAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Urgent task card
// =====================================================================

class UrgentTaskCard extends StatelessWidget {
  const UrgentTaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  final DashboardUrgentTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForKind(task.kind);
    final co = context.colors;
    return Semantics(
      button: true,
      label: '${task.title}. ${task.subtitle}. ${task.badgeLabel}',
      child: PressableCard(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: co.card,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: co.brandAccentBg,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, color: co.brandAccent, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(task.subtitle,
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textTertiary)),
                  ],
                ),
              ),
              StatusPill(
                label: task.badgeLabel,
                color: task.badgeLabel == 'URGENTE'
                    ? AppColors.warning
                    : AppColors.psBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForKind(String kind) {
    switch (kind) {
      case 'addendum_sign':
        return Icons.assignment_outlined;
      case 'contract_sign':
        return Icons.draw_outlined;
      case 'accept_invite':
        return Icons.mail_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}

// =====================================================================
// Work card
// =====================================================================

class WorkCard extends ConsumerWidget {
  const WorkCard({super.key, required this.pact, required this.onTap});

  final DashboardActivePact pact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Estado del pacto: se usa la MISMA fuente que la lista y el detalle
    // (PactStateStyle). Antes había aquí un `_stateConfig` paralelo que pintaba
    // "ACTIVA" en cian y "COMPLETADA" en verde, divergiendo del resto de la app.
    final stateStyle = PactStateStyle.forPactState(pact.state, context);
    // Dot de salud: obtener score de pact_health para mostrar indicador
    final healthAsync = ref.watch(pactHealthProvider(pact.id));
    final healthColor = healthAsync.maybeWhen(
      data: (h) => h.color,
      orElse: () => null,
    );
    final healthScore = healthAsync.maybeWhen(
      data: (h) => h.score,
      orElse: () => null,
    );

    final co = context.colors;
    return Semantics(
      button: true,
      label: '${pact.title}. ${pact.city}. Progreso ${pact.progressPct}%',
      child: PressableCard(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: co.card,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(pact.title,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                ),
                // Dot de salud (solo cuando hay datos)
                if (healthColor != null) ...[
                  _HealthDot(color: healthColor, score: healthScore),
                  const SizedBox(width: AppSpacing.sm),
                ],
                PactStateBadge(style: stateStyle, compact: true),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: context.colors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(pact.city,
                      style: AppTypography.bodyS
                          .copyWith(color: context.colors.textTertiary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.xsAll,
              child: LinearProgressIndicator(
                value: (pact.progressPct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: co.border,
                valueColor: AlwaysStoppedAnimation(
                  healthColor ?? AppColors.psBlue,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progreso: ${pact.progressPct}%',
                    style: AppTypography.bodyS.copyWith(color: co.textSecondary)),
                CifraViva(
                  amountCents: pact.totalAmountCents,
                  size: 15,
                  color: co.textPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

}

/// Pequeño dot de color con el score numérico del pacto.
class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.color, this.score});

  final Color color;
  final int? score;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: score != null ? 'Trust Score: $score/100' : 'Trust Score',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.12),
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: color.withValues(alpha:0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (score != null) ...[
              const SizedBox(width: 3),
              Text(
                '$score',
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Status pill
// =====================================================================

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bgColor = color == AppColors.psCyan
        ? AppColors.psCyan
        : color.withValues(alpha: 0.15);
    final fgColor = color == AppColors.psCyan ? AppColors.psNavy : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// =====================================================================
// Empty state
// =====================================================================

class EmptyWorksCard extends StatelessWidget {
  const EmptyWorksCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: co.scaffold,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Icon(Icons.business_center_outlined,
              size: 24, color: co.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message,
                style: AppTypography.bodyS
                    .copyWith(color: co.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Loading skeleton
// =====================================================================

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShimmerBox(height: 124, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: ShimmerBox(height: 86, radius: AppRadius.md)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: ShimmerBox(height: 86, radius: AppRadius.md)),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        ShimmerBox(height: 18, radius: 4, width: 140),
        SizedBox(height: AppSpacing.sm),
        ShimmerBox(height: 72, radius: AppRadius.md),
        SizedBox(height: AppSpacing.sm),
        ShimmerBox(height: 72, radius: AppRadius.md),
      ],
    );
  }
}

// =====================================================================
// Error block
// =====================================================================

class DashboardErrorBlock extends StatelessWidget {
  const DashboardErrorBlock({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.errorBg,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text('No se pudo cargar el panel',
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  AppTypography.caption.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Técnico validation task card (prominent card with "Validar ahora" CTA)
// =====================================================================

/// Task card for técnico validation tasks (ARCO §8b: tarjeta uniforme).
class TecnicoValidationTaskCard extends StatelessWidget {
  const TecnicoValidationTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.ctaLabel = 'Validar ahora',
    this.onCtaTap,
    this.accentColor,
  });

  final DashboardUrgentTask task;

  /// Called when tapping the card body (navigates to pact detail).
  final VoidCallback onTap;

  /// Label for the CTA button.
  final String ctaLabel;

  /// Called when tapping the CTA button. Defaults to [onTap] if null.
  final VoidCallback? onCtaTap;

  /// Accent used for icon bg and CTA. Defaults to [AppColors.tecnicoAccent].
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.tecnicoAccent;

    return Semantics(
      button: true,
      label: '${task.title}. ${task.subtitle}. $ctaLabel',
      child: PressableCard(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(
                  _iconForValidationKind(task.kind),
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      style: AppTypography.bodyS
                          .copyWith(color: context.colors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: onCtaTap ?? onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  textStyle: AppTypography.bodyS.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smAll,
                  ),
                ),
                child: Text(ctaLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForValidationKind(String kind) {
    switch (kind) {
      case 'milestone_pending_tech_review':
        return Icons.verified_outlined;
      case 'milestone_pending_validation':
        return Icons.checklist_outlined;
      case 'addendum_sign':
        return Icons.assignment_outlined;
      case 'contract_sign':
        return Icons.draw_outlined;
      default:
        return Icons.task_alt_outlined;
    }
  }
}
