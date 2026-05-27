/// Modelos de datos de la capa IA de PactStream.
///
/// Mapean las respuestas de la Edge Function `ai-gateway` y las filas de
/// las tablas `milestone_ai_verifications` y `ai_assistant_messages`.
///
/// Reglas:
///  - Todos los importes en BIGINT céntimos (nunca float).
///  - Timestamps como DateTime UTC.
///  - Enums tipados para verdict y severity (no strings libres en la UI).

// =====================================================================
// ENUMS
// =====================================================================

enum AiVerdict {
  ok,
  reviewNeeded,
  block;

  static AiVerdict fromJson(String v) {
    switch (v) {
      case 'ok':
        return AiVerdict.ok;
      case 'review_needed':
        return AiVerdict.reviewNeeded;
      case 'block':
        return AiVerdict.block;
      default:
        return AiVerdict.reviewNeeded;
    }
  }

  String get label {
    switch (this) {
      case AiVerdict.ok:
        return 'Sin objeciones';
      case AiVerdict.reviewNeeded:
        return 'Revisar';
      case AiVerdict.block:
        return 'Bloqueante';
    }
  }
}

enum AiFindingSeverity {
  green,
  amber,
  red;

  static AiFindingSeverity fromJson(String v) {
    switch (v) {
      case 'green':
        return AiFindingSeverity.green;
      case 'amber':
        return AiFindingSeverity.amber;
      case 'red':
        return AiFindingSeverity.red;
      default:
        return AiFindingSeverity.amber;
    }
  }
}

// =====================================================================
// VISION — FINDINGS Y CHECKLIST
// =====================================================================

/// Un hallazgo del dictamen Vision (foto ambigua, factura incorrecta, etc.).
class AiFinding {
  AiFinding({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.evidenceRef,
  });

  final String id;

  /// 'photo' | 'invoice' | 'checklist' | 'document'
  final String type;
  final AiFindingSeverity severity;
  final String message;

  /// Ruta del fichero que generó el hallazgo (si aplica).
  final String? evidenceRef;

  factory AiFinding.fromJson(Map<String, dynamic> j) {
    return AiFinding(
      id: (j['id'] as String?) ?? '',
      type: (j['type'] as String?) ?? 'photo',
      severity: AiFindingSeverity.fromJson((j['severity'] as String?) ?? 'amber'),
      message: (j['message'] as String?) ?? '',
      evidenceRef: j['evidence_ref'] as String?,
    );
  }
}

/// Un ítem del checklist del hito contra las evidencias subidas.
class AiChecklistMatch {
  AiChecklistMatch({
    required this.taskId,
    required this.title,
    required this.evidenceOk,
    this.note,
  });

  final String taskId;
  final String title;
  final bool evidenceOk;
  final String? note;

  factory AiChecklistMatch.fromJson(Map<String, dynamic> j) {
    return AiChecklistMatch(
      taskId: (j['task_id'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      evidenceOk: (j['evidence_ok'] as bool?) ?? false,
      note: j['note'] as String?,
    );
  }
}

// =====================================================================
// VISION — VERIFICACIÓN COMPLETA
// =====================================================================

/// Dictamen completo de Claude Vision sobre las evidencias de un hito.
/// Persisted en `milestone_ai_verifications` (append-only).
class AiVerification {
  AiVerification({
    required this.id,
    required this.milestoneId,
    required this.pactId,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.score,
    required this.verdict,
    required this.summary,
    required this.findings,
    required this.checklistMatch,
    required this.recommendation,
    required this.createdAt,
    this.inputTokens,
    this.outputTokens,
    this.costCents = 0,
    this.durationMs,
    this.reviewedAt,
    this.justifications = const [],
  });

  final String id;
  final String milestoneId;
  final String pactId;

  /// 'demo' | 'live'
  final String provider;
  final String model;
  final String promptVersion;

  /// Score de 0 a 100.
  final int score;
  final AiVerdict verdict;
  final String summary;
  final List<AiFinding> findings;
  final List<AiChecklistMatch> checklistMatch;
  final String recommendation;

  final int? inputTokens;
  final int? outputTokens;

  /// Coste en céntimos de euro (0 en demo mode).
  final int costCents;
  final int? durationMs;

  final DateTime createdAt;
  final DateTime? reviewedAt;
  final List<dynamic> justifications;

  bool get isDemo => provider == 'demo';
  bool get hasFindings => findings.isNotEmpty;
  int get redFindings =>
      findings.where((f) => f.severity == AiFindingSeverity.red).length;
  int get amberFindings =>
      findings.where((f) => f.severity == AiFindingSeverity.amber).length;

  /// Construye desde la fila de `milestone_ai_verifications` devuelta
  /// por Supabase (`.select()`).
  factory AiVerification.fromRow(Map<String, dynamic> row) {
    final findingsRaw =
        (row['findings'] as List<dynamic>?) ?? const [];
    final checklistRaw =
        (row['checklist_match'] as List<dynamic>?) ?? const [];
    return AiVerification(
      id: row['id'] as String,
      milestoneId: row['milestone_id'] as String,
      pactId: row['pact_id'] as String,
      provider: (row['provider'] as String?) ?? 'demo',
      model: (row['model'] as String?) ?? '',
      promptVersion: (row['prompt_version'] as String?) ?? '',
      score: (row['score'] as num).toInt(),
      verdict: AiVerdict.fromJson(row['verdict'] as String),
      summary: (row['summary'] as String?) ?? '',
      findings: findingsRaw
          .cast<Map<String, dynamic>>()
          .map(AiFinding.fromJson)
          .toList(),
      checklistMatch: checklistRaw
          .cast<Map<String, dynamic>>()
          .map(AiChecklistMatch.fromJson)
          .toList(),
      recommendation: (row['recommendation'] as String?) ?? '',
      inputTokens: (row['input_tokens'] as num?)?.toInt(),
      outputTokens: (row['output_tokens'] as num?)?.toInt(),
      costCents: ((row['cost_cents'] as num?) ?? 0).toInt(),
      durationMs: (row['duration_ms'] as num?)?.toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
      reviewedAt: row['reviewed_at'] != null
          ? DateTime.parse(row['reviewed_at'] as String)
          : null,
      justifications:
          (row['justifications'] as List<dynamic>?) ?? const [],
    );
  }

  /// Construye desde el payload de respuesta de `ai-gateway` (runType=vision).
  factory AiVerification.fromGatewayResponse({
    required String milestoneId,
    required String pactId,
    required Map<String, dynamic> response,
  }) {
    final dictum =
        response['vision_dictum'] as Map<String, dynamic>? ?? response;
    final findingsRaw =
        (dictum['findings'] as List<dynamic>?) ?? const [];
    final checklistRaw =
        (dictum['checklist_match'] as List<dynamic>?) ?? const [];
    return AiVerification(
      id: '', // Se asignará cuando se persista en BD
      milestoneId: milestoneId,
      pactId: pactId,
      provider: (response['provider'] as String?) ?? 'demo',
      model: (response['model'] as String?) ?? '',
      promptVersion: (response['prompt_version'] as String?) ?? '',
      score: ((dictum['score'] as num?) ?? 0).toInt(),
      verdict: AiVerdict.fromJson((dictum['verdict'] as String?) ?? 'ok'),
      summary: (dictum['summary'] as String?) ?? '',
      findings: findingsRaw
          .cast<Map<String, dynamic>>()
          .map(AiFinding.fromJson)
          .toList(),
      checklistMatch: checklistRaw
          .cast<Map<String, dynamic>>()
          .map(AiChecklistMatch.fromJson)
          .toList(),
      recommendation: (dictum['recommendation'] as String?) ?? '',
      inputTokens: (response['input_tokens'] as num?)?.toInt(),
      outputTokens: (response['output_tokens'] as num?)?.toInt(),
      costCents: ((response['cost_cents'] as num?) ?? 0).toInt(),
      durationMs: (response['duration_ms'] as num?)?.toInt(),
      createdAt: DateTime.now().toUtc(),
    );
  }
}

// =====================================================================
// ASISTENTE — MENSAJES
// =====================================================================

/// Un turno del asistente o del usuario en la conversación in-app.
/// Persisted en `ai_assistant_messages`.
class AiAssistantMessage {
  AiAssistantMessage({
    required this.id,
    required this.pactId,
    required this.role,
    required this.createdAt,
    this.content,
    this.toolCallName,
    this.toolCallInput,
    this.toolCallStatus,
    this.toolCallResult,
    this.provider,
    this.feedback,
  });

  final String id;
  final String pactId;

  /// 'user' | 'assistant' | 'tool_result'
  final String role;
  final String? content;
  final String? toolCallName;
  final Map<String, dynamic>? toolCallInput;

  /// 'proposed' | 'confirmed' | 'executed' | 'cancelled'
  final String? toolCallStatus;
  final Map<String, dynamic>? toolCallResult;

  /// 'demo' | 'live'
  final String? provider;

  /// 'up' | 'down' | null
  final String? feedback;
  final DateTime createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasToolCallProposal =>
      toolCallName != null && toolCallStatus == 'proposed';
  bool get isDemo => provider == 'demo';

  factory AiAssistantMessage.fromRow(Map<String, dynamic> row) {
    return AiAssistantMessage(
      id: row['id'] as String,
      pactId: row['pact_id'] as String,
      role: row['role'] as String,
      content: row['content'] as String?,
      toolCallName: row['tool_call_name'] as String?,
      toolCallInput: row['tool_call_input'] != null
          ? Map<String, dynamic>.from(
              row['tool_call_input'] as Map<dynamic, dynamic>)
          : null,
      toolCallStatus: row['tool_call_status'] as String?,
      toolCallResult: row['tool_call_result'] != null
          ? Map<String, dynamic>.from(
              row['tool_call_result'] as Map<dynamic, dynamic>)
          : null,
      provider: row['provider'] as String?,
      feedback: row['feedback'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Copia con campos actualizados (para actualizar el status del tool call
  /// sin volver a cargar desde BD).
  AiAssistantMessage copyWith({
    String? toolCallStatus,
    Map<String, dynamic>? toolCallResult,
    String? feedback,
  }) {
    return AiAssistantMessage(
      id: id,
      pactId: pactId,
      role: role,
      content: content,
      toolCallName: toolCallName,
      toolCallInput: toolCallInput,
      toolCallStatus: toolCallStatus ?? this.toolCallStatus,
      toolCallResult: toolCallResult ?? this.toolCallResult,
      provider: provider,
      feedback: feedback ?? this.feedback,
      createdAt: createdAt,
    );
  }
}

/// Mensaje optimista creado localmente antes de persistir (sin ID real).
/// Se reemplaza en la lista cuando llega la respuesta del servidor.
class AiAssistantMessageOptimistic extends AiAssistantMessage {
  AiAssistantMessageOptimistic({
    required super.pactId,
    required super.role,
    required super.content,
    required super.createdAt,
  }) : super(id: '_optimistic_${DateTime.now().microsecondsSinceEpoch}');

  bool get isOptimistic => true;
}
