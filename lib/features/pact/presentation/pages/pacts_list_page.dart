import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/pressable_card.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/pact_providers.dart';
import '../../data/pact_summary.dart';
import '../widgets/pact_state_badge.dart';

/// Lista de pactos del usuario. Sustituye el placeholder del bottom nav.
///
/// Estados:
///   - loading: spinner centrado
///   - empty: ilustración + CTA "Crear nueva obra"
///   - data: cards con resumen, click → detalle
///   - error: mensaje + retry
class PactsListPage extends ConsumerWidget {
  const PactsListPage({super.key, this.canCreate = true});

  /// Si el rol del usuario puede crear pactos. El constructor no.
  final bool canCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pactsAsync = ref.watch(myPactsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPactsProvider);
        await ref.read(myPactsProvider.future);
      },
      child: pactsAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudieron cargar tus obras',
          message: e.toString(),
          onRetry: () => ref.invalidate(myPactsProvider),
        ),
        data: (pacts) {
          if (pacts.isEmpty) {
            return EmptyStateView(
              icon: Icons.folder_outlined,
              title: canCreate ? 'Aún no tienes obras' : 'Sin obras asignadas',
              subtitle: canCreate
                  ? 'Crea tu primera obra para empezar a gestionar pagos por hitos con custodia.'
                  : 'Cuando un promotor o técnico te invite a una obra, aparecerá aquí.',
              actionLabel: canCreate ? 'Crear nueva obra' : null,
              onAction: canCreate ? () => context.push(AppRoutes.pactNew) : null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: pacts.length + (canCreate ? 1 : 0),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (ctx, i) {
              if (canCreate && i == 0) {
                return AnimatedListItem(
                  index: 0,
                  child: const _CreateCta(),
                );
              }
              final idx = i - (canCreate ? 1 : 0);
              final pact = pacts[idx];
              return AnimatedListItem(
                index: i,
                child: _PactCard(
                  pact: pact,
                  onTap: () => context.push('/pacts/${pact.pactId}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateCta extends StatelessWidget {
  const _CreateCta();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => context.push(AppRoutes.pactNew),
        label: const Text('Crear nueva obra'),
      ),
    );
  }
}

// _EmptyState y _ErrorView ahora usan los widgets reutilizables
// EmptyStateView y ErrorStateView de core/widgets/empty_state_view.dart.

class _PactCard extends StatelessWidget {
  const _PactCard({required this.pact, required this.onTap});

  final PactSummary pact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateStyle = PactStateStyle.forPactState(pact.state);
    final progress = pact.milestonesTotal > 0
        ? '${pact.milestonesPaid} de ${pact.milestonesTotal} hitos pagados'
        : '';
    final amount = AppFormatters.moneyShort(pact.totalAmountCents);

    return Semantics(
      button: true,
      label: '${pact.title}. ${stateStyle.label}. $amount. '
          '${pact.locationShort}. $progress',
      child: PressableCard(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.ink200),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pact.title,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            pact.displayId,
                            style: AppTypography.mono
                                .copyWith(fontSize: 11),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('·',
                              style: AppTypography.bodyS
                                  .copyWith(color: AppColors.ink400)),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.ink500),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              pact.locationShort,
                              style: AppTypography.bodyS
                                  .copyWith(color: AppColors.ink500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PactStateBadge(style: stateStyle),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Importe + tipo
            Row(
              children: [
                Text(
                  AppFormatters.moneyShort(pact.totalAmountCents),
                  style: AppTypography.h3.copyWith(fontSize: 18),
                ),
                const SizedBox(width: AppSpacing.sm),
                _TypePill(pactType: pact.pactType),
                const Spacer(),
                _RolePill(role: pact.myRole),
              ],
            ),

            // Si hay hitos: barra de progreso
            if (pact.milestonesTotal > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.xxsAll,
                child: LinearProgressIndicator(
                  value: pact.progress,
                  minHeight: 4,
                  backgroundColor: AppColors.ink200,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.psBlue),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${pact.milestonesPaid}/${pact.milestonesTotal} hitos pagados',
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink500),
                  ),
                  if (pact.partiesAccepted < pact.partiesTotal)
                    Text(
                      '${pact.partiesAccepted}/${pact.partiesTotal} partes aceptaron',
                      style: AppTypography.bodyS.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ] else if (pact.partiesTotal > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${pact.partiesAccepted} de ${pact.partiesTotal} partes han aceptado',
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.ink500),
              ),
            ],

            // Próximo hito (si lo hay)
            if (pact.nextMilestoneName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.ink50,
                  borderRadius: AppRadius.microAll,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined,
                        size: 14, color: AppColors.ink500),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Próximo: ${pact.nextMilestoneName}',
                        style: AppTypography.bodyS
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pact.nextMilestoneAmountCents != null)
                      Text(
                        AppFormatters.moneyShort(
                            pact.nextMilestoneAmountCents!),
                        style: AppTypography.bodyS
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.pactType});

  final String pactType;

  @override
  Widget build(BuildContext context) {
    final isMenor = pactType == 'obra_menor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: AppRadius.xlAll,
      ),
      child: Text(
        isMenor ? 'Obra menor' : 'Obra mayor',
        style: AppTypography.caption.copyWith(
          color: AppColors.ink600,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final spec = switch (role) {
      'promotor' => (
        label: 'Promotor',
        color: AppColors.psBlue,
      ),
      'tecnico' => (
        label: 'Técnico',
        color: AppColors.tecnicoAccent,
      ),
      'constructor' => (
        label: 'Constructor',
        color: AppColors.success,
      ),
      _ => (label: role, color: AppColors.ink500),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.xlAll,
      ),
      child: Text(
        spec.label,
        style: AppTypography.caption.copyWith(
          color: spec.color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
