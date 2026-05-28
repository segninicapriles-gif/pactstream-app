import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../data/dashboard_data.dart';
import '../../data/dashboard_providers.dart';
import 'dashboard_shared.dart';
import 'mini_bar_chart.dart';

/// Dashboard del Técnico (cableado a datos reales).
///
/// Hero KPI: obras que está supervisando.
/// KPIs secundarios: tareas urgentes (validaciones/firmas).
/// Secciones: Tareas urgentes, Mis obras activas.
class DashboardTecnico extends ConsumerWidget {
  const DashboardTecnico({
    super.key,
    required this.userName,
    this.organizationName,
    this.onViewAllPacts,
  });

  final String userName;
  final String? organizationName;

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

  /// Returns true if the task kind involves validation by the técnico.
  static bool _isValidationKind(String kind) {
    return kind == 'milestone_pending_tech_review' ||
        kind == 'milestone_pending_validation';
  }

  @override
  Widget build(BuildContext context) {
    var animIdx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO · Obras supervisadas + Trust Score del tecnico
        // Uses a custom gradient incorporating tecnicoAccent to
        // visually differentiate from promotor/constructor dashboards.
        AnimatedListItem(
          index: animIdx++,
          child: HeroKpiScoreCard(
            eyebrow: 'OBRAS SUPERVISADAS',
            amount: data.activeWorks.toString(),
            subtitle: data.newWorksThisMonth > 0
                ? '+${data.newWorksThisMonth} este mes'
                : 'Todas tus obras como técnico',
            subtitleColor: data.newWorksThisMonth > 0
                ? AppColors.success
                : AppColors.psCyan,
            icon: Icons.architecture_outlined,
            gradientColors: const [
              AppColors.psNavy,
              AppColors.tecnicoAccentDark,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        AnimatedListItem(
          index: animIdx++,
          child: Row(
            children: [
              Expanded(
                child: MiniKpiCard(
                  label: 'POR VALIDAR / FIRMAR',
                  value: data.urgentTasks.length.toString(),
                  accentColor: data.urgentTasks.isEmpty
                      ? AppColors.success
                      : AppColors.tecnicoAccent,
                  subtitle: data.urgentTasks.isEmpty
                      ? 'Sin pendientes'
                      : 'Acciones tuyas',
                  subtitleColor: data.urgentTasks.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MiniKpiCard(
                  label: 'NUEVAS ESTE MES',
                  value: data.newWorksThisMonth.toString(),
                  accentColor: AppColors.psBlue,
                  subtitle: 'Obras donde participas',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (data.urgentTasks.isNotEmpty) ...[
          AnimatedListItem(
            index: animIdx++,
            child: DashboardSectionHeader(
              title: 'Tareas urgentes',
              onViewAll: onViewAllPacts,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final t in data.urgentTasks.take(3))
            AnimatedListItem(
              index: animIdx++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _isValidationKind(t.kind)
                    ? TecnicoValidationTaskCard(
                        task: t,
                        onTap: () => context.push('/pacts/${t.pactId}'),
                      )
                    : UrgentTaskCard(
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
              message:
                  'Todavía no supervisas ninguna obra. Cuando un promotor te '
                  'incluya como técnico, las verás aquí.',
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

        // CHART · Validaciones mensuales
        AnimatedListItem(
          index: animIdx++,
          child: MiniBarChart(
            title: 'Validaciones mensuales',
            barColor: AppColors.tecnicoAccent,
            data: _buildValidationData(),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// Genera datos demo de validaciones de los últimos 6 meses.
  /// TODO(sprint-3): sustituir por datos reales de sf_get_validation_summary.
  static List<BarChartItem> _buildValidationData() {
    final now = DateTime.now();
    const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    // Datos demo — simula validaciones de un técnico activo.
    const demoValues = [4.0, 6.0, 3.0, 8.0, 5.0, 7.0];
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - 5 + i);
      return BarChartItem(
        label: months[month.month - 1],
        value: demoValues[i],
      );
    });
  }
}
