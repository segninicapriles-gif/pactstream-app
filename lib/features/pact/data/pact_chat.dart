import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_humanizer.dart';
import '../../../data/datasources/supabase/supabase_client.dart';

/// Un mensaje del chat de un pacto.
class PactMessage {
  const PactMessage({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.deletedAt,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String senderUserId;
  final String? senderName;
  final String? senderRole; // 'promotor' | 'constructor' | 'tecnico' | null
  /// null cuando el mensaje está soft-deleted por su autor.
  final String? body;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final bool isMine;

  bool get isDeleted => deletedAt != null;

  factory PactMessage.fromJson(Map<String, dynamic> j) => PactMessage(
        id: j['id'] as String,
        senderUserId: j['sender_user_id'] as String,
        senderName: j['sender_name'] as String?,
        senderRole: j['sender_role'] as String?,
        body: j['body'] as String?,
        deletedAt: j['deleted_at'] == null
            ? null
            : DateTime.parse(j['deleted_at'] as String).toLocal(),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        isMine: (j['is_mine'] as bool?) ?? false,
      );
}

/// Provider de mensajes de un pacto. `family` sobre pactId. autoDispose
/// para liberar memoria cuando el usuario sale del chat.
///
/// Refresco: la UI llama `ref.invalidate(pactMessagesProvider(pactId))`
/// tras enviar; el pull-to-refresh o un timer pueden invalidar cada X
/// segundos para simular tiempo real sin realtime.
final pactMessagesProvider = FutureProvider.autoDispose
    .family<List<PactMessage>, String>((ref, pactId) async {
  final raw = await SupabaseConfig.client.rpc('sf_list_pact_messages',
      params: {'p_pact_id': pactId, 'p_limit': 100});
  final list = (raw as List).cast<Map<String, dynamic>>();
  return list.map(PactMessage.fromJson).toList();
});

/// Contador de no leídos por pacto. Se pinta como badge en `pact_detail`
/// y en la home. Cachea 30 s para no martillear la BD.
final pactUnreadCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, pactId) async {
  ref.keepAlive();
  try {
    final r = await SupabaseConfig.client
        .rpc('sf_unread_pact_messages_count', params: {'p_pact_id': pactId});
    return (r as int?) ?? 0;
  } on Exception {
    return 0;
  }
});

/// Envía un mensaje. Devuelve el `id` del mensaje creado.
Future<String> sendPactMessage(String pactId, String body) async {
  try {
    final r = await SupabaseConfig.client.rpc('sf_send_pact_message',
        params: {'p_pact_id': pactId, 'p_body': body});
    final map = (r as Map<String, dynamic>);
    return map['id'] as String;
  } on Exception catch (e) {
    throw Exception(humanizeError(e));
  }
}

/// Marca el chat como leído hasta ahora. Best-effort (fallo se ignora).
Future<void> markPactRead(String pactId) async {
  try {
    await SupabaseConfig.client
        .rpc('sf_mark_pact_read', params: {'p_pact_id': pactId});
  } on Exception {
    // silencioso — el badge se corregirá en la próxima carga
  }
}

/// Soft-delete de un mensaje propio.
Future<void> deletePactMessage(String messageId) async {
  try {
    await SupabaseConfig.client
        .rpc('sf_delete_pact_message', params: {'p_message_id': messageId});
  } on Exception catch (e) {
    throw Exception(humanizeError(e));
  }
}
