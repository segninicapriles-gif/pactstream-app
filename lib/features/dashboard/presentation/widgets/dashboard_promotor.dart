import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../data/dashboard_data.dart';
import '../../data/dashboard_providers.dart';
import 'dashboard_shared.dart';
import 'monthly_series_chart.dart';

/// Dashboard del Promotor (cableado a datos reales).
///
/// Hero KPI: "Cuánto dinero tengo en custodia".
/// KPIs secundarios: obras activas, próxima liberación.
/// Secciones: Tareas urgentes, Mis obras activas.
class DashboardPromotor extends ConsumerWidget {
  const DashboardPromotor({
    super.key,
    required this.userName,
    this.onViewAllPacts,
  });

  final String userName;

  /// Callback invocado por "Ver todas" — cambia al tab Obras en HomePage.
  final VoidCallback? onViewAllPacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardDataProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        await ref.read(dashboardDataProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const DashboardSkeleton(),
            error: (e, _) => DashboardErrorBlock(
              message: e.toString(),
              onRetry: () => ref.invalidate(dashboardDataProvider),
            ),
            data: (data) => _Content(
              data: data,
              onViewAllPacts: onViewAllPacts,
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data, this.onViewAllPacts});
  final DashboardData data;
  final VoidCallback? onViewAllPacts;

  @override
  Widget build(BuildContext context) {
    var animIdx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO · dinero en custodia + Trust Score del promotor
        AnimatedListItem(
          index: animIdx++,
          child: HeroKpiScoreCard(
            eyebrow: 'EN CUSTODIA',
            amount: AppFormatters.moneyShort(data.inCustodyCents),
            subtitle: data.inCustodyCents > 0
                ? 'Garantizado'
                : 'Sin obras con depósito todavía',
            subtitleColor: data.inCustodyCents > 0
                ? AppColors.success
                : AppColors.psCyan,
            secondaryLabel: data.nextRelease != null ? 'PRÓXIMA LIBERACIÓN' : null,
            secondaryValue: data.nextRelease != null
                ? AppFormatters.moneyShort(data.nextRelease!.amountCents)
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        AnimatedListItem(
          index: animIdx++,
          child: Row(
            children: [
              Expanded(
                child: MiniKpiCard(
                  label: 'OBRAS ACTIVAS',
                  value: data.activeWorks.toString(),
                  accentColor: AppColors.psBlue,
                  subtitle: data.newWorksThisMonth > 0
                      ? '+${data.newWorksThisMonth} este mes'
                      : 'Sin cambios este mes',
                  subtitleColor: data.newWorksThisMonth > 0
                      ? AppColors.success
                      : context.colors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MiniKpiCard(
                  label: 'TAREAS URGENTES',
                  value: data.urgentTasks.length.toString(),
                  accentColor: data.urgentTasks.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                  subtitle: data.urgentTasks.isEmpty
                      ? 'Sin pendientes'
                      : 'Requieren acción',
                  subtitleColor: data.urgentTasks.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // CTA principal
        AnimatedListItem(
          index: animIdx++,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.push(AppRoutes.pactNew),
              label: const Text('Crear nueva obra'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (data.urgentTasks.isNotEmpty) ...[
          AnimatedListItem(
            index: animIdx++,
            child: DashboardSectionHeader(
              title: 'Tareas urgentes',
              onViewAll: onViewAllPacts,
              viewAllLabel: 'Ver todas →',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final t in data.urgentTasks.take(3))
            AnimatedListItem(
              index: animIdx++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: UrgentTaskCard(
                  task: t,
                  onTap: () => context.push('/pacts/${t.pactId}'),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],

        AnimatedListItem(
          index: animIdx++,
          child: DashboardSectionHeader(
            title: 'Mis obras activas',
            onViewAll: onViewAllPacts,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.activePacts.isEmpty)
          AnimatedListItem(
            index: animIdx++,
            child: const EmptyWorksCard(
              message: 'Todavía no tienes obras activas. Crea tu primera obra '
                  'para empezar a gestionar pagos en custodia.',
            ),
          )
        else
          for (final p in data.activePacts)
            AnimatedListItem(
              index: animIdx++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: WorkCard(
                  pact: p,
                  onTap: () => context.push('/pacts/${p.id}'),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),

        // CHART · Flujo de fondos (datos reales de sf_get_monthly_series:
        // hitos pagados/mes como promotor; empty state si no hay datos)
        AnimatedListItem(
          index: animIdx++,
          child: const MonthlySeriesChart(
            kind: MonthlySeriesKind.fundFlow,
            title: 'Flujo de fondos',
            barColor: AppColors.psBlue,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  static String? _nextReleaseSubtitle(DashboardNextRelease? r) {
    if (r == null) return 'No hay nada por liberar';
    if (r.targetDate != null) {
      final d = r.targetDate!;
      const months = [
        'ene','feb','mar','abr','may','jun',
        'jul','ago','sep','oct','nov','dic'
      ];
      return 'Hito · ${d.day} ${months[d.month - 1]}';
    }
    if (r.milestoneName != null) return r.milestoneName;
    return null;
  }
}
