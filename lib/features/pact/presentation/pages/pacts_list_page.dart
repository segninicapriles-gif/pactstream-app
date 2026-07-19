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
import '../../data/pact_archive_prefs.dart';
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
    'Archivadas',
  ];

  List<PactSummary> _applyFilters(List<PactSummary> pacts, Set<String> archivedIds) {
    var filtered = pacts;

    // Archive filter
    if (_selectedFilter == 'Archivadas') {
      filtered = filtered.where((p) => archivedIds.contains(p.pactId)).toList();
    } else {
      // All other tabs exclude archived pacts
      filtered = filtered.where((p) => !archivedIds.contains(p.pactId)).toList();

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
            'Completadas' =>
              p.state == 'completed' || p.state == 'closed',
            'En disputa' => p.state == 'disputed',
            _ => true,
          };
        }).toList();
      }
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
    final archivedIds = ref.watch(archivedPactIdsProvider);

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

          final filtered = _applyFilters(pacts, archivedIds);

          // Show a friendly empty state when filters yield no results
          if (filtered.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // Keep subtitle row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Gestiona tus obras de construcción',
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textTertiary),
                      ),
                    ),
                    Text(
                      '${pacts.length} total',
                      style: AppTypography.caption.copyWith(
                        color: context.colors.textHint,
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
                        .copyWith(color: context.colors.textHint),
                    prefixIcon: Icon(Icons.search,
                        color: context.colors.textHint, size: 20),
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
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedFilter = label),
                          borderRadius: AppRadius.smAll,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 13,
                            ),
                            child: Text(
                              label,
                              style: AppTypography.bodyS.copyWith(
                                color: selected
                                    ? AppColors.psBlue
                                    : context.colors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        'Gestiona tus obras de construcción',
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textTertiary),
                      ),
                    ),
                    Text(
                      '$active activa${active == 1 ? '' : 's'} · ${pacts.length} total',
                      style: AppTypography.caption.copyWith(
                        color: context.colors.textHint,
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
                        .copyWith(color: context.colors.textHint),
                    prefixIcon: Icon(Icons.search,
                        color: context.colors.textHint, size: 20),
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
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedFilter = label),
                          borderRadius: AppRadius.smAll,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 13,
                            ),
                            child: Text(
                              label,
                              style: AppTypography.bodyS.copyWith(
                                color: selected
                                    ? AppColors.psBlue
                                    : context.colors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
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
              final isArchived = archivedIds.contains(pact.pactId);
              return AnimatedListItem(
                index: i,
                child: _SwipeablePactCard(
                  pact: pact,
                  isArchived: isArchived,
                  onTap: () => context.push('/pacts/${pact.pactId}'),
                  onArchive: () {
                    final notifier = ref.read(archivedPactIdsProvider.notifier);
                    if (isArchived) {
                      notifier.unarchive(pact.pactId);
                      _showSnackBar(context, 'Obra restaurada', Icons.unarchive_outlined);
                    } else {
                      notifier.archive(pact.pactId);
                      _showSnackBar(context, 'Obra archivada', Icons.archive_outlined,
                        undoAction: () => notifier.unarchive(pact.pactId),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, IconData icon,
      {VoidCallback? undoAction}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(message),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        action: undoAction != null
            ? SnackBarAction(
                label: 'Deshacer',
                textColor: AppColors.psCyan,
                onPressed: undoAction,
              )
            : null,
      ),
    );
  }
}

/// Pact card with swipe-to-archive gesture.
class _SwipeablePactCard extends StatelessWidget {
  const _SwipeablePactCard({
    required this.pact,
    required this.isArchived,
    required this.onTap,
    required this.onArchive,
  });

  final PactSummary pact;
  final bool isArchived;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('pact_${pact.pactId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onArchive();
        return false; // Don't actually remove — we handle state via provider
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: isArchived ? AppColors.psBlue : AppColors.ink500,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: AppColors.white,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              isArchived ? 'Restaurar' : 'Archivar',
              style: AppTypography.caption.copyWith(
                color: AppColors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      child: _PactCard(pact: pact, onTap: onTap),
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
    final co = context.colors;
    final stateStyle = PactStateStyle.forPactState(pact.state, context);
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
          color: co.card,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: co.border),
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
                          color: co.textPrimary,
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
                                .copyWith(fontSize: 11, color: co.textTertiary),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('·',
                              style: AppTypography.bodyS
                                  .copyWith(color: co.textHint)),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(Icons.location_on_outlined,
                              size: 12, color: co.textTertiary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              pact.locationShort,
                              style: AppTypography.bodyS
                                  .copyWith(color: co.textTertiary),
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
                  style: AppTypography.h3.copyWith(fontSize: 18, color: co.textPrimary),
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
                  backgroundColor: co.border,
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
                        .copyWith(color: co.textTertiary),
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
                    .copyWith(color: co.textTertiary),
              ),
            ],

            // Próximo hito (si lo hay)
            if (pact.nextMilestoneName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: co.scaffold,
                  borderRadius: AppRadius.microAll,
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 14, color: co.textTertiary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Próximo: ${pact.nextMilestoneName}',
                        style: AppTypography.bodyS
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              color: co.textPrimary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pact.nextMilestoneAmountCents != null)
                      Text(
                        AppFormatters.moneyShort(
                            pact.nextMilestoneAmountCents!),
                        style: AppTypography.bodyS
                            .copyWith(
                              fontWeight: FontWeight.w800,
                              color: co.textPrimary,
                            ),
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
    final co = context.colors;
    final isMenor = pactType == 'obra_menor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: co.chipBg,
        borderRadius: AppRadius.xlAll,
      ),
      child: Text(
        isMenor ? 'Obra menor' : 'Obra mayor',
        style: AppTypography.caption.copyWith(
          color: co.chipText,
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
        color: context.colors.brandAccent,
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
