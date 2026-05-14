import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
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
  });

  final String eyebrow;
  final String amount;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.psNavy,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.psNavy, Color(0xFF14193D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: AppTypography.caption.copyWith(color: AppColors.psCyan)),
          const SizedBox(height: AppSpacing.xs),
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
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.ink500)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.h2.copyWith(fontSize: 22)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: AppTypography.bodyS
                    .copyWith(color: subtitleColor ?? AppColors.ink500)),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Section header
// =====================================================================

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.h3.copyWith(fontSize: 18));
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: AppColors.ink200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Icon(icon, color: AppColors.psBlue, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(task.subtitle,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
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

class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.pact, required this.onTap});

  final DashboardActivePact pact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = _stateConfig(pact.state);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: AppColors.ink200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(pact.title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                StatusPill(label: config.label, color: config.color),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.ink500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(pact.city,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (pact.progressPct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.ink200,
                valueColor: const AlwaysStoppedAnimation(AppColors.psBlue),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progreso: ${pact.progressPct}%',
                    style: AppTypography.bodyS),
                Text(
                  AppFormatters.moneyShort(pact.totalAmountCents),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static ({String label, Color color}) _stateConfig(String state) {
    switch (state) {
      case 'in_execution':
        return (label: 'ACTIVA', color: AppColors.psCyan);
      case 'signing':
      case 'signed':
      case 'funded':
        return (label: 'EN FIRMA', color: AppColors.psBlue);
      case 'inviting':
        return (label: 'PENDIENTE', color: AppColors.warning);
      case 'paused_pending_tech':
        return (label: 'PAUSADA', color: AppColors.warning);
      case 'disputed':
        return (label: 'EN DISPUTA', color: AppColors.error);
      case 'completed':
        return (label: 'COMPLETADA', color: AppColors.success);
      default:
        return (label: state.toUpperCase(), color: AppColors.ink500);
    }
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
        borderRadius: BorderRadius.circular(12),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_center_outlined,
              size: 24, color: AppColors.ink500),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message,
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.ink600)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkBox(height: 124, radius: AppSpacing.md),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: const [
            Expanded(child: _SkBox(height: 86, radius: AppSpacing.md)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: _SkBox(height: 86, radius: AppSpacing.md)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SkBox(height: 18, radius: 4, width: 140),
        const SizedBox(height: AppSpacing.sm),
        _SkBox(height: 72, radius: AppSpacing.md),
        const SizedBox(height: AppSpacing.sm),
        _SkBox(height: 72, radius: AppSpacing.md),
      ],
    );
  }
}

class _SkBox extends StatelessWidget {
  const _SkBox({required this.height, this.radius = 8, this.width});

  final double height;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(radius),
      ),
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
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text('No se pudo cargar el panel',
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  AppTypography.caption.copyWith(color: AppColors.ink600)),
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
