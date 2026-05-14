import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/dashboard_data.dart';
import '../../data/dashboard_providers.dart';
import 'dashboard_shared.dart';

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
  });

  final String userName;
  final String? organizationName;

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
          Text('Hola, ${userName.split(' ').first}', style: AppTypography.h1),
          Text(
            organizationName != null
                ? 'Resumen de actividad para $organizationName'
                : 'Resumen de actividad como Arquitecto técnico',
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            loading: () => const DashboardSkeleton(),
            error: (e, _) => DashboardErrorBlock(
              message: e.toString(),
              onRetry: () => ref.invalidate(dashboardDataProvider),
            ),
            data: (data) => _Content(data: data),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroKpiCard(
          eyebrow: 'OBRAS SUPERVISADAS',
          amount: data.activeWorks.toString(),
          subtitle: data.newWorksThisMonth > 0
              ? '+${data.newWorksThisMonth} este mes'
              : 'Todas tus obras como técnico',
          subtitleColor: data.newWorksThisMonth > 0
              ? AppColors.success
              : AppColors.psCyan,
          icon: Icons.architecture_outlined,
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: MiniKpiCard(
                label: 'POR VALIDAR / FIRMAR',
                value: data.urgentTasks.length.toString(),
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
                subtitle: 'Obras donde participas',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        if (data.urgentTasks.isNotEmpty) ...[
          DashboardSectionHeader(title: 'Tareas urgentes'),
          const SizedBox(height: AppSpacing.sm),
          for (final t in data.urgentTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: UrgentTaskCard(
                task: t,
                onTap: () => context.push('/pacts/${t.pactId}'),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],

        DashboardSectionHeader(title: 'Mis obras activas'),
        const SizedBox(height: AppSpacing.sm),
        if (data.activePacts.isEmpty)
          const EmptyWorksCard(
            message:
                'Todavía no supervisas ninguna obra. Cuando un promotor te '
                'incluya como técnico, las verás aquí.',
          )
        else
          for (final p in data.activePacts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: WorkCard(
                pact: p,
                onTap: () => context.push('/pacts/${p.id}'),
              ),
            ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
