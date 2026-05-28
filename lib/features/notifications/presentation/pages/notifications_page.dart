import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/pressable_card.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/notification_item.dart';
import '../../data/notifications_providers.dart';

/// Centro de notificaciones in-app.
/// Reemplaza el placeholder del tab "Mensajes/Avisos" del bottom nav.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final unread = unreadAsync.maybeWhen(data: (n) => n, orElse: () => 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notificationsListProvider);
        ref.invalidate(unreadNotificationsProvider);
        await ref.read(notificationsListProvider.future);
      },
      child: notifsAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudieron cargar los avisos',
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_outlined,
              title: 'Sin avisos',
              subtitle: 'Aquí verás invitaciones, validaciones pendientes, pagos liberados y otras alertas de tus obras.',
            );
          }

          // --- Temporal grouping ---
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final weekStart = todayStart.subtract(const Duration(days: 7));

          final hoy = <NotificationItem>[];
          final estaSemana = <NotificationItem>[];
          final anteriores = <NotificationItem>[];

          for (final n in items) {
            if (!n.createdAt.isBefore(todayStart)) {
              hoy.add(n);
            } else if (!n.createdAt.isBefore(weekStart)) {
              estaSemana.add(n);
            } else {
              anteriores.add(n);
            }
          }

          final groups = <(String, List<NotificationItem>)>[
            if (hoy.isNotEmpty) ('Hoy', hoy),
            if (estaSemana.isNotEmpty) ('Esta semana', estaSemana),
            if (anteriores.isNotEmpty) ('Anteriores', anteriores),
          ];

          // Build a flat list of widgets: section headers + cards
          var globalIndex = 0;
          final slivers = <Widget>[];

          if (unread > 0) {
            slivers.add(SliverToBoxAdapter(
              child: _MarkAllReadHeader(unread: unread),
            ));
          }

          for (final (label, group) in groups) {
            // Section header
            slivers.add(SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: context.colors.textTertiary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: context.colors.chipBg,
                        borderRadius: AppRadius.xlAll,
                      ),
                      child: Text(
                        '${group.length}',
                        style: AppTypography.caption.copyWith(
                          color: context.colors.chipText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Divider(
                        color: context.colors.border,
                        thickness: 1,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ));

            // Cards for this group
            slivers.add(SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final animIndex = globalIndex + i;
                    final child = AnimatedListItem(
                      index: animIndex,
                      child: _NotificationCard(item: group[i]),
                    );
                    // Add spacing between cards
                    if (i < group.length - 1) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: child,
                      );
                    }
                    return child;
                  },
                  childCount: group.length,
                ),
              ),
            ));
            globalIndex += group.length;
          }

          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }
}

// =====================================================================
// HEADER · "Marcar todas como leídas"
// =====================================================================

class _MarkAllReadHeader extends ConsumerStatefulWidget {
  const _MarkAllReadHeader({required this.unread});

  final int unread;

  @override
  ConsumerState<_MarkAllReadHeader> createState() =>
      _MarkAllReadHeaderState();
}

class _MarkAllReadHeaderState extends ConsumerState<_MarkAllReadHeader> {
  bool _marking = false;

  Future<void> _markAll() async {
    AppHaptics.medium();
    setState(() => _marking = true);
    try {
      await ref.read(notificationsRepoProvider).markAllAsRead();
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationsProvider);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      color: context.colors.infoBg,
      child: Row(
        children: [
          Icon(Icons.notifications_active,
              color: context.colors.brandAccent, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${widget.unread} sin leer',
              style: AppTypography.bodyS.copyWith(
                color: context.colors.brandAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_marking)
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _markAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(
                'Marcar todas leídas',
                style: AppTypography.bodyS.copyWith(
                  color: context.colors.brandAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// CARD · una notificación
// =====================================================================

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final NotificationItem item;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    // Marca como leída si lo estaba
    if (item.isUnread) {
      // Fire-and-forget para no bloquear navegación
      ref.read(notificationsRepoProvider).markAsRead(item.id).then((_) {
        ref.invalidate(unreadNotificationsProvider);
        ref.invalidate(notificationsListProvider);
      });
    }
    // Navega al CTA si existe
    if (item.ctaUrl != null && item.ctaUrl!.isNotEmpty) {
      if (item.ctaUrl!.startsWith('/')) {
        context.push(item.ctaUrl!);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = _specFor(item.notificationType, context);
    final isUnread = item.isUnread;

    final c = context.colors;
    return Semantics(
      button: true,
      label: '${isUnread ? "Sin leer. " : ""}${item.title}. ${item.body}',
      child: PressableCard(
        onTap: () => _open(context, ref),
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isUnread ? c.infoBg : c.card,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: isUnread ? c.brandAccent : c.border,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: spec.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(spec.icon, color: spec.fg, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTypography.body.copyWith(
                            fontWeight:
                                isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 6),
                          decoration: BoxDecoration(
                            color: context.colors.brandAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: AppTypography.bodyS
                        .copyWith(color: c.textSecondary, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (item.pactDisplayId != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.chipBg,
                            borderRadius: AppRadius.microAll,
                          ),
                          child: Text(
                            item.pactDisplayId!,
                            style: AppTypography.mono.copyWith(
                              fontSize: 10,
                              color: c.chipText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        AppFormatters.timeRelative(item.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: c.textTertiary,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// _EmptyState y _ErrorView ahora usan los widgets reutilizables
// EmptyStateView y ErrorStateView de core/widgets/empty_state_view.dart.

// =====================================================================
// MAPEO TIPO → ICONO + COLOR
// =====================================================================

class _NotifSpec {
  const _NotifSpec({required this.icon, required this.bg, required this.fg});
  final IconData icon;
  final Color bg;
  final Color fg;
}

_NotifSpec _specFor(String type, BuildContext context) {
  switch (type) {
    case 'pact_invitation':
      return _NotifSpec(
        icon: Icons.mail_outline,
        bg: context.colors.brandAccentBg,
        fg: context.colors.brandAccent,
      );
    case 'all_parties_accepted':
    case 'contract_fully_signed':
      return _NotifSpec(
        icon: Icons.draw_outlined,
        bg: context.colors.brandAccentBg,
        fg: context.colors.brandAccent,
      );
    case 'pact_funded':
      return _NotifSpec(
        icon: Icons.play_arrow_rounded,
        bg: context.colors.successBg,
        fg: AppColors.success,
      );
    case 'milestone_pending_tech_review':
      return _NotifSpec(
        icon: Icons.architecture,
        bg: context.colors.warningBg,
        fg: AppColors.tecnicoAccent,
      );
    case 'milestone_pending_promotor':
      return _NotifSpec(
        icon: Icons.account_balance_wallet_outlined,
        bg: context.colors.warningBg,
        fg: AppColors.warning,
      );
    case 'milestone_needs_rework':
      return _NotifSpec(
        icon: Icons.help_outline,
        bg: context.colors.errorBg,
        fg: AppColors.error,
      );
    case 'milestone_paid':
      return _NotifSpec(
        icon: Icons.verified,
        bg: context.colors.successBg,
        fg: AppColors.success,
      );
    case 'milestone_disputed':
      return _NotifSpec(
        icon: Icons.gavel,
        bg: context.colors.errorBg,
        fg: AppColors.error,
      );
    case 'pact_completed':
      return _NotifSpec(
        icon: Icons.celebration,
        bg: context.colors.successBg,
        fg: AppColors.success,
      );
    default:
      return _NotifSpec(
        icon: Icons.notifications_outlined,
        bg: context.colors.chipBg,
        fg: context.colors.textSecondary,
      );
  }
}
