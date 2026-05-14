import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/dashboard_data.dart';
import '../../data/dashboard_providers.dart';
import 'dashboard_shared.dart';

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
                : 'Resumen de actividad como Constructor',
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
    final next = data.nextRelease;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO · Próxima liberación = lo que cobra el constructor a continuación
        HeroKpiCard(
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
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: MiniKpiCard(
                label: 'OBRAS ACTIVAS',
                value: data.activeWorks.toString(),
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
                'Todavía no estás en ninguna obra. Cuando un promotor te invite, '
                'verás aquí las obras donde participas.',
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

  static String _dateLabel(DateTime? d) {
    if (d == null) return 'Sin fecha';
    const months = [
      'ene','feb','mar','abr','may','jun',
      'jul','ago','sep','oct','nov','dic'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
