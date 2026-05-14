/// Una notificación in-app del usuario.
///
/// Mapea a la fila de `sf_list_my_notifications`.
class NotificationItem {
  NotificationItem({
    required this.id,
    required this.notificationType,
    required this.priority,
    required this.title,
    required this.body,
    required this.createdAt,
    this.pactId,
    this.pactDisplayId,
    this.pactTitle,
    this.milestoneId,
    this.ctaUrl,
    this.readAt,
  });

  final String id;
  final String notificationType;
  final String? pactId;
  final String? pactDisplayId;
  final String? pactTitle;
  final String? milestoneId;
  final String priority; // 'low' | 'normal' | 'high' | 'urgent'
  final String title;
  final String body;
  final String? ctaUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
  bool get isHighPriority => priority == 'high' || priority == 'urgent';

  factory NotificationItem.fromRpcRow(Map<String, dynamic> row) {
    return NotificationItem(
      id: row['id'] as String,
      notificationType: row['notification_type'] as String,
      pactId: row['pact_id'] as String?,
      pactDisplayId: row['pact_display_id'] as String?,
      pactTitle: row['pact_title'] as String?,
      milestoneId: row['milestone_id'] as String?,
      priority: row['priority'] as String? ?? 'normal',
      title: row['title'] as String,
      body: row['body'] as String,
      ctaUrl: row['cta_url'] as String?,
      readAt: row['read_at'] != null
          ? DateTime.parse(row['read_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
