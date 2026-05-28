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
class PactsListPage extends ConsumerStatefulWidget {
  const PactsListPage({super.key, this.canCreate = true});

  /// Si el rol del usuario puede crear pactos. El constructor no.
  final bool canCreate;

  @override
  ConsumerState<PactsListPage> createState() => _PactsListPageState();
}

class _PactsListPageState extends ConsumerState<PactsListPage> {
  String _searchQuery = '';
  String _selectedFilter = 'Todas';

  static const _filters = [
    'Todas',
    'Activas',
    'Pendiente',
    'Completadas',
    'En disputa',
  ];

  List<PactSummary> _applyFilters(List<PactSummary> pacts) {
    var filtered = pacts;

    // State filter
    if (_selectedFilter != 'Todas') {
      filtered = filtered.where((p) {
        return switch (_selectedFilter) {
          'Activas' =>
            p.state == 'in_execution' || p.state == 'funded',
          'Pendiente' =>
            p.state == 'inviting' ||
            p.state == 'signing' ||
            p.state == 'signed' ||
            p.state == 'paused_pending_tech',
          'Completadas' => p.state == 'completed',
          'En disputa' => p.state == 'disputed',
          _ => true,
        };
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.displayId.toLowerCase().contains(q) ||
            p.locationShort.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
              title: widget.canCreate
                  ? 'Aún no tienes obras'
                  : 'Sin obras asignadas',
              subtitle: widget.canCreate
                  ? 'Crea tu primera obra para empezar a gestionar pagos por hitos con custodia.'
                  : 'Cuando un promotor o técnico te invite a una obra, aparecerá aquí.',
              actionLabel: widget.canCreate ? 'Crear nueva obra' : null,
              onAction: widget.canCreate
                  ? () => context.push(AppRoutes.pactNew)
                  : null,
            );
          }

          final filtered = _applyFilters(pacts);

          // Show a friendly empty state when filters yield no results
          if (filtered.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Keep subtitle row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Gestiona tus proyectos de construcción',
                        style: AppTypography.bodyS
                            .copyWith(color: AppColors.ink500),
                      ),
                    ),
                    Text(
                      '${pacts.length} total',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Keep search bar
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar obra, ciudad o NIF...',
                    hintStyle: AppTypography.bodyS
                        .copyWith(color: AppColors.ink400),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.ink400, size: 20),
                    filled: true,
                    fillColor: context.colors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide:
                          BorderSide(color: AppColors.psBlue, width: 1.5),
                    ),
                  ),
                  style: AppTypography.bodyS,
                ),
                const SizedBox(height: AppSpacing.md),
                // Keep filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((label) {
                      final selected = _selectedFilter == label;
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedFilter = label),
                          labelStyle: AppTypography.bodyS.copyWith(
                            color: selected
                                ? AppColors.white
                                : AppColors.ink600,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: AppColors.psBlue,
                          backgroundColor: context.colors.chipBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.xlAll,
                            side: BorderSide.none,
                          ),
                          side: BorderSide.none,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Empty filter result
                EmptyStateView(
                  icon: Icons.search_off_outlined,
                  title: 'Sin resultados',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'No se encontraron obras para "$_searchQuery"'
                      : 'No hay obras con el filtro "$_selectedFilter"',
                  actionLabel: 'Limpiar filtros',
                  onAction: () => setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'Todas';
                  }),
                ),
              ],
            );
          }

          // Header count: subtitle + search bar + filter chips row
          const headerCount = 3;
          final ctaCount = widget.canCreate ? 1 : 0;

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: headerCount + ctaCount + filtered.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (ctx, i) {
              // ---- Subtitle + count ----
              if (i == 0) {
                final active = pacts.where((p) =>
                    p.state == 'in_execution' || p.state == 'funded').length;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Gestiona tus proyectos de construcción',
                        style: AppTypography.bodyS
                            .copyWith(color: AppColors.ink500),
                      ),
                    ),
                    Text(
                      '$active activa${active == 1 ? '' : 's'} · ${pacts.length} total',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }
              // ---- Search bar ----
              if (i == 1) {
                return TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar obra, ciudad o NIF...',
                    hintStyle: AppTypography.bodyS
                        .copyWith(color: AppColors.ink400),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.ink400, size: 20),
                    filled: true,
                    fillColor: context.colors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide:
                          BorderSide(color: AppColors.psBlue, width: 1.5),
                    ),
                  ),
                  style: AppTypography.bodyS,
                );
              }

              // ---- Filter chips ----
              if (i == 2) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((label) {
                      final selected = _selectedFilter == label;
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedFilter = label),
                          labelStyle: AppTypography.bodyS.copyWith(
                            color: selected
                                ? AppColors.white
                                : AppColors.ink600,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: AppColors.psBlue,
                          backgroundColor: context.colors.chipBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.xlAll,
                            side: BorderSide.none,
                          ),
                          side: BorderSide.none,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }

              // ---- Create CTA ----
              if (widget.canCreate && i == headerCount) {
                return AnimatedListItem(
                  index: 0,
                  child: const _CreateCta(),
                );
              }

              // ---- Pact cards ----
              final idx = i - headerCount - ctaCount;
              if (idx < 0 || idx >= filtered.length) {
                return const SizedBox.shrink();
              }
              final pact = filtered[idx];
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

  /// Color de acento lateral según el estado del pacto.
  static Color _accentForState(String state) => switch (state) {
    'in_execution' || 'funded' => AppColors.psBlue,
    'inviting' || 'signing' || 'signed' || 'paused_pending_tech' => AppColors.warning,
    'completed' => AppColors.success,
    'disputed' => AppColors.error,
    _ => AppColors.ink400,
  };

  @override
  Widget build(BuildContext context) {
    final stateStyle = PactStateStyle.forPactState(pact.state);
    final progress = pact.milestonesTotal > 0
        ? '${pact.milestonesPaid} de ${pact.milestonesTotal} hitos pagados'
        : '';
    final amount = AppFormatters.moneyShort(pact.totalAmountCents);
    final accent = _accentForState(pact.state);

    return Semantics(
      button: true,
      label: '${pact.title}. ${stateStyle.label}. $amount. '
          '${pact.locationShort}. $progress',
      child: PressableCard(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: context.colors.border),
          boxShadow: AppShadows.soft,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent bar for quick state identification
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
      ),  // Padding
    ),  // Expanded
  ],
),  // Row
        ),  // IntrinsicHeight
      ),  // Container
    ),  // PressableCard
    );  // Semantics
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
