import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsListProvider),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          return Column(
            children: [
              if (unread > 0) _MarkAllReadHeader(unread: unread),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (ctx, i) => _NotificationCard(item: items[i]),
                ),
              ),
            ],
          );
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
      color: AppColors.infoBg,
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              color: AppColors.psBlue, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${widget.unread} sin leer',
              style: AppTypography.bodyS.copyWith(
                color: AppColors.psBlue,
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
                  color: AppColors.psBlue,
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
    final spec = _specFor(item.notificationType);
    final isUnread = item.isUnread;

    return InkWell(
      onTap: () => _open(context, ref),
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.infoBg : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: isUnread ? AppColors.psBlue : AppColors.ink200,
            width: isUnread ? 1 : 1,
          ),
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
                            color: AppColors.ink900,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.psBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink600, height: 1.4),
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
                            color: AppColors.ink100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.pactDisplayId!,
                            style: AppTypography.mono.copyWith(
                              fontSize: 10,
                              color: AppColors.ink600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        AppFormatters.timeRelative(item.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink500,
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
    );
  }
}

// =====================================================================
// EMPTY / ERROR
// =====================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.infoBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined,
                color: AppColors.psBlue, size: 44),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Sin avisos',
          textAlign: TextAlign.center,
          style: AppTypography.h2,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Aquí verás invitaciones, validaciones pendientes, pagos liberados y otras alertas de tus obras.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('No se pudieron cargar los avisos',
                textAlign: TextAlign.center, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.ink500)),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// MAPEO TIPO → ICONO + COLOR
// =====================================================================

class _NotifSpec {
  const _NotifSpec({required this.icon, required this.bg, required this.fg});
  final IconData icon;
  final Color bg;
  final Color fg;
}

_NotifSpec _specFor(String type) {
  switch (type) {
    case 'pact_invitation':
      return const _NotifSpec(
        icon: Icons.mail_outline,
        bg: AppColors.infoBg,
        fg: AppColors.psBlue,
      );
    case 'all_parties_accepted':
    case 'contract_fully_signed':
      return const _NotifSpec(
        icon: Icons.draw_outlined,
        bg: AppColors.infoBg,
        fg: AppColors.psBlue,
      );
    case 'pact_funded':
      return const _NotifSpec(
        icon: Icons.play_arrow_rounded,
        bg: AppColors.successBg,
        fg: AppColors.success,
      );
    case 'milestone_pending_tech_review':
      return const _NotifSpec(
        icon: Icons.architecture,
        bg: AppColors.warningBg,
        fg: AppColors.tecnicoAccent,
      );
    case 'milestone_pending_promotor':
      return const _NotifSpec(
        icon: Icons.account_balance_wallet_outlined,
        bg: AppColors.warningBg,
        fg: AppColors.warning,
      );
    case 'milestone_needs_rework':
      return const _NotifSpec(
        icon: Icons.help_outline,
        bg: AppColors.errorBg,
        fg: AppColors.error,
      );
    case 'milestone_paid':
      return const _NotifSpec(
        icon: Icons.verified,
        bg: AppColors.successBg,
        fg: AppColors.success,
      );
    case 'milestone_disputed':
      return const _NotifSpec(
        icon: Icons.gavel,
        bg: AppColors.errorBg,
        fg: AppColors.error,
      );
    case 'pact_completed':
      return const _NotifSpec(
        icon: Icons.celebration,
        bg: AppColors.successBg,
        fg: AppColors.success,
      );
    default:
      return const _NotifSpec(
        icon: Icons.notifications_outlined,
        bg: AppColors.ink100,
        fg: AppColors.ink600,
      );
  }
}
