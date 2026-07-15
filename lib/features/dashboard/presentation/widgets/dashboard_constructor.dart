import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../data/dashboard_data.dart';
import '../../data/dashboard_providers.dart';
import 'dashboard_shared.dart';
import 'mini_bar_chart.dart';

/// Dashboard del Constructor (cableado a datos reales).
///
/// Hero KPI: "Próxima liberación" (lo más relevante: ¿cuándo cobro?).
/// KPIs secundarios: obras activas, tareas urgentes.
/// Secciones: tareas urgentes (anexos a firmar, etc.), obras activas.
class DashboardConstructor extends ConsumerWidget {
  const DashboardConstructor({
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

  @override
  Widget build(BuildContext context) {
    final next = data.nextRelease;

    // Index counter for staggered animations across all sections.
    var animIdx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO · Proxima liberacion + Trust Score del constructor
        AnimatedListItem(
          index: animIdx++,
          child: HeroKpiScoreCard(
            eyebrow: 'PRÓXIMA LIBERACIÓN',
            amount: next != null
                ? AppFormatters.moneyShort(next.amountCents)
                : '—',
            subtitle: next != null
                ? '${next.pactTitle} · ${_dateLabel(next.targetDate)}'
                : 'Ninguna certificación validada todavía',
            subtitleColor: next != null
                ? AppColors.success
                : AppColors.psCyan,
            icon: Icons.payments_outlined,
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
                  accentColor: AppColors.success,
                  subtitle: data.newWorksThisMonth > 0
                      ? '+${data.newWorksThisMonth} este mes'
                      : null,
                  subtitleColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MiniKpiCard(
                  label: 'POR FIRMAR',
                  value: data.urgentTasks.length.toString(),
                  accentColor: data.urgentTasks.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                  subtitle: data.urgentTasks.isEmpty
                      ? 'Sin pendientes'
                      : 'Anexos / contratos',
                  subtitleColor: data.urgentTasks.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // CTA principal — el constructor es quien típicamente crea obras
        AnimatedListItem(
          index: animIdx++,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.push('/pacts/new'),
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
              message:
                  'Todavía no estás en ninguna obra. Cuando un promotor te invite, '
                  'verás aquí las obras donde participas.',
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

        // CHART · Facturación mensual
        AnimatedListItem(
          index: animIdx++,
          child: MiniBarChart(
            title: 'Facturación mensual',
            barColor: AppColors.success,
            data: _buildMonthlyData(),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// Serie de los últimos 6 meses para el gráfico de facturación.
  ///
  /// No existe todavía RPC de datos reales (sf_get_billing_summary no
  /// está en el backend), así que devolvemos valores a 0 y MiniBarChart
  /// muestra su empty state honesto ("Aún no hay datos"). NUNCA mostrar
  /// cifras inventadas al usuario.
  static List<BarChartItem> _buildMonthlyData() {
    final now = DateTime.now();
    const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - 5 + i);
      return BarChartItem(
        label: months[month.month - 1],
        value: 0,
      );
    });
  }

  static String _dateLabel(DateTime? d) {
    if (d == null) return 'Sin fecha';
    const months = [
      'ene','feb','mar','abr','may','jun',
      'jul','ago','sep','oct','nov','dic'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
