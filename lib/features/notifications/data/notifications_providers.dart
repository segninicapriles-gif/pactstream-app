import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase/supabase_client.dart';
import 'notification_item.dart';

/// Repo de notificaciones in-app.
class NotificationsRepository {
  NotificationsRepository();

  Future<List<NotificationItem>> listMyNotifications({
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    final rows = await SupabaseConfig.client.rpc(
      'sf_list_my_notifications',
      params: {'p_limit': limit, 'p_only_unread': onlyUnread},
    );
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(NotificationItem.fromRpcRow)
        .toList(growable: false);
  }

  Future<int> countUnread() async {
    final raw =
        await SupabaseConfig.client.rpc('sf_count_unread_notifications');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<void> markAsRead(String notificationId) async {
    await SupabaseConfig.client.rpc(
      'sf_mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<int> markAllAsRead() async {
    final raw =
        await SupabaseConfig.client.rpc('sf_mark_all_notifications_read');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}

final notificationsRepoProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository());

/// Tamaño de página de notificaciones (P2-2).
const int kNotificationsPageSize = 50;

/// Límite actual de notificaciones a cargar. "Cargar más" lo incrementa
/// en bloques de [kNotificationsPageSize].
final notificationsLimitProvider =
    StateProvider<int>((ref) => kNotificationsPageSize);

/// Lista de notificaciones del usuario (hasta el límite actual).
final notificationsListProvider =
    FutureProvider<List<NotificationItem>>((ref) {
  final limit = ref.watch(notificationsLimitProvider);
  return ref
      .watch(notificationsRepoProvider)
      .listMyNotifications(limit: limit);
});

/// Contador de no leídas. Usado para el badge.
final unreadNotificationsProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationsRepoProvider).countUnread();
});
