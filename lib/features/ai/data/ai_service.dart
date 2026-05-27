/// Servicio que comunica Flutter con la capa IA de PactStream.
///
/// Responsabilidades:
///  1. Invocar la Edge Function `ai-gateway` para los dos runTypes:
///       - 'vision'   → dictamen de evidencias de un hito
///       - 'assistant' → turno del asistente conversacional
///  2. Leer el historial de `milestone_ai_verifications` y
///     `ai_assistant_messages` directamente desde Supabase Postgres (RLS).
///
/// No contiene lógica de UI. Todos los errores se lanzan como excepciones
/// para que los providers de Riverpod los gestionen.

import '../../../data/datasources/supabase/supabase_client.dart';
import 'ai_models.dart';

class AiService {
  AiService();

  // -------------------------------------------------------------------
  // VISION · Verificación de evidencias de un hito
  // -------------------------------------------------------------------

  /// Solicita a `ai-gateway` el dictamen Vision para un hito.
  ///
  /// En demo mode (default), devuelve un fixture pre-grabado con latencia
  /// simulada. En live mode, llama a la API de Anthropic.
  ///
  /// El gateway persiste el dictamen en `milestone_ai_verifications` y
  /// actualiza `pact_health_scores.ia_evidence_score` automáticamente.
  Future<AiVerification> requestVisionVerification({
    required String pactId,
    required String milestoneId,
  }) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'ai-gateway',
      body: {
        'runType': 'vision',
        'pactId': pactId,
        'milestoneId': milestoneId,
        'payload': {},
      },
    );

    final data = response.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Respuesta vacía del gateway IA.');
    }
    if (data['error'] != null) {
      throw Exception(data['error'] as String);
    }

    return AiVerification.fromGatewayResponse(
      milestoneId: milestoneId,
      pactId: pactId,
      response: data,
    );
  }

  /// Lee el último dictamen Vision disponible para el hito desde la BD.
  /// Devuelve `null` si aún no hay ninguno.
  Future<AiVerification?> getLatestVerification(String milestoneId) async {
    final rows = await SupabaseConfig.client
        .from('milestone_ai_verifications')
        .select()
        .eq('milestone_id', milestoneId)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows is! List || rows.isEmpty) return null;
    return AiVerification.fromRow(
        rows.first as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------
  // ASISTENTE · Chat conversacional scoped a un pacto
  // -------------------------------------------------------------------

  /// Envía un mensaje del usuario al asistente y devuelve la respuesta.
  ///
  /// [intentKey] es opcional: si el frontend detecta un intent claro
  /// (p.ej. el usuario pulsa un chip de acción rápida), lo pasa para
  /// que el gateway lo use como key de fixture en demo mode.
  Future<AiAssistantMessage> sendAssistantMessage({
    required String pactId,
    required String userMessage,
    String? intentKey,
  }) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'ai-gateway',
      body: {
        'runType': 'assistant',
        'pactId': pactId,
        'intentKey': intentKey,
        'payload': {
          'user_message': userMessage,
        },
      },
    );

    final data = response.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Respuesta vacía del asistente.');
    }
    if (data['error'] != null) {
      throw Exception(data['error'] as String);
    }

    // El gateway devuelve los IDs de los mensajes persistidos.
    // Reconstruimos el mensaje del asistente desde la respuesta.
    final assistantMsgId =
        (data['assistant_message_id'] as String?) ?? '';

    return AiAssistantMessage(
      id: assistantMsgId,
      pactId: pactId,
      role: 'assistant',
      content: data['content'] as String?,
      toolCallName: data['tool_call'] != null
          ? (data['tool_call'] as Map<String, dynamic>)['name'] as String?
          : null,
      toolCallInput: data['tool_call'] != null
          ? Map<String, dynamic>.from(
              (data['tool_call'] as Map<String, dynamic>)['input']
                  as Map<dynamic, dynamic>? ??
                  {})
          : null,
      toolCallStatus:
          data['tool_call'] != null ? 'proposed' : null,
      provider: data['provider'] as String?,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Lee el historial de mensajes del asistente para el pacto actual.
  ///
  /// RLS: el usuario solo ve su propio hilo. Los admin del pacto ven todos.
  /// Ordenados de más antiguo a más reciente para renderizar el chat.
  Future<List<AiAssistantMessage>> getAssistantHistory(
      String pactId) async {
    final rows = await SupabaseConfig.client
        .from('ai_assistant_messages')
        .select()
        .eq('pact_id', pactId)
        .order('created_at', ascending: true)
        .limit(100);

    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(AiAssistantMessage.fromRow)
        .toList(growable: false);
  }
}
