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

/// Dashboard del Promotor (cableado a datos reales).
///
/// Hero KPI: "Cuánto dinero tengo en custodia".
/// KPIs secundarios: obras activas, próxima liberación.
/// Secciones: Tareas urgentes, Mis obras activas.
class DashboardPromotor extends ConsumerWidget {
  const DashboardPromotor({super.key, required this.userName});

  final String userName;

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
            'Resumen de tu actividad como Promotor',
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
        // HERO · dinero en custodia
        HeroKpiCard(
          eyebrow: 'EN CUSTODIA',
          amount: AppFormatters.moneyShort(data.inCustodyCents),
          subtitle: data.inCustodyCents > 0
              ? 'Garantizado'
              : 'Sin obras con depósito todavía',
          subtitleColor: data.inCustodyCents > 0
              ? AppColors.success
              : AppColors.psCyan,
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
                label: 'PRÓXIMA LIBERACIÓN',
                value: data.nextRelease != null
                    ? AppFormatters.moneyShort(data.nextRelease!.amountCents)
                    : '—',
                subtitle: _nextReleaseSubtitle(data.nextRelease),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // CTA principal
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push(AppRoutes.pactNew),
            label: const Text('Crear nueva obra'),
          ),
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
            message: 'Todavía no tienes obras activas. Crea tu primera obra '
                'para empezar a gestionar pagos en custodia.',
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
