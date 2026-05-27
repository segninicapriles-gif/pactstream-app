/// Providers Riverpod de la capa IA de PactStream.
///
/// Jerarquía:
///   aiServiceProvider           → singleton de AiService
///   milestoneVerificationProvider(milestoneId) → lee el último dictamen
///   assistantHistoryProvider(pactId)           → historial del asistente
///   assistantNotifierProvider(pactId)          → StateNotifier para enviar msgs

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_models.dart';
import 'ai_service.dart';

// =====================================================================
// SERVICIO
// =====================================================================

final aiServiceProvider = Provider<AiService>((ref) => AiService());

// =====================================================================
// VISION · Último dictamen de un hito
// =====================================================================

/// Lee el dictamen más reciente de `milestone_ai_verifications` para
/// el hito indicado. Devuelve `null` si aún no hay ninguno.
///
/// Se invalida automáticamente cuando el usuario lanza una nueva
/// verificación desde la UI (via ref.invalidate en el notifier de vision).
final milestoneVerificationProvider =
    FutureProvider.family<AiVerification?, String>((ref, milestoneId) {
  return ref.watch(aiServiceProvider).getLatestVerification(milestoneId);
});

// =====================================================================
// VISION · Notifier de la acción "Verificar con IA"
// =====================================================================

/// Estado de la solicitud de verificación Vision (idle → loading → done/error).
sealed class VisionVerifyState {
  const VisionVerifyState();
}

class VisionVerifyIdle extends VisionVerifyState {
  const VisionVerifyIdle();
}

class VisionVerifyLoading extends VisionVerifyState {
  const VisionVerifyLoading();
}

class VisionVerifyDone extends VisionVerifyState {
  const VisionVerifyDone(this.verification);
  final AiVerification verification;
}

class VisionVerifyError extends VisionVerifyState {
  const VisionVerifyError(this.message);
  final String message;
}

class VisionVerifyNotifier extends StateNotifier<VisionVerifyState> {
  VisionVerifyNotifier(this._ref) : super(const VisionVerifyIdle());

  final Ref _ref;

  Future<void> verify({
    required String pactId,
    required String milestoneId,
  }) async {
    state = const VisionVerifyLoading();
    try {
      final result = await _ref
          .read(aiServiceProvider)
          .requestVisionVerification(
            pactId: pactId,
            milestoneId: milestoneId,
          );
      // Invalida el provider de lectura para que recargue el nuevo dictamen.
      _ref.invalidate(milestoneVerificationProvider(milestoneId));
      state = VisionVerifyDone(result);
    } catch (e) {
      state = VisionVerifyError(e.toString());
    }
  }

  void reset() => state = const VisionVerifyIdle();
}

final visionVerifyNotifierProvider = StateNotifierProvider.autoDispose
    .family<VisionVerifyNotifier, VisionVerifyState, String>(
  (ref, milestoneId) => VisionVerifyNotifier(ref),
);

// =====================================================================
// ASISTENTE · Historial + envío de mensajes
// =====================================================================

/// Historial de mensajes del asistente para un pacto.
/// Se invalida tras cada turno nuevo.
final assistantHistoryProvider =
    FutureProvider.family<List<AiAssistantMessage>, String>(
        (ref, pactId) {
  return ref.watch(aiServiceProvider).getAssistantHistory(pactId);
});

// -------------------------------------------------------------------
// Notifier del asistente
// -------------------------------------------------------------------

/// Estado del asistente conversacional.
class AssistantState {
  AssistantState({
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  final List<AiAssistantMessage> messages;
  final bool isSending;
  final String? error;

  AssistantState copyWith({
    List<AiAssistantMessage>? messages,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  AssistantNotifier(this._ref, this._pactId)
      : super(AssistantState());

  final Ref _ref;
  final String _pactId;

  // Inicializa el notifier con el historial existente desde BD.
  Future<void> loadHistory() async {
    final msgs = await _ref.read(aiServiceProvider).getAssistantHistory(_pactId);
    if (mounted) {
      state = state.copyWith(messages: msgs, clearError: true);
    }
  }

  Future<void> send(String userMessage, {String? intentKey}) async {
    if (userMessage.trim().isEmpty || state.isSending) return;

    // Optimismo: añadimos el mensaje del usuario inmediatamente.
    final optimisticUser = AiAssistantMessageOptimistic(
      pactId: _pactId,
      role: 'user',
      content: userMessage.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    state = state.copyWith(
      messages: [...state.messages, optimisticUser],
      isSending: true,
      clearError: true,
    );

    try {
      final assistantMsg = await _ref.read(aiServiceProvider).sendAssistantMessage(
            pactId: _pactId,
            userMessage: userMessage.trim(),
            intentKey: intentKey,
          );

      if (!mounted) return;

      // Reemplazamos el mensaje optimista con el real y añadimos la respuesta.
      final updatedMessages = state.messages
          .where((m) => m.id != optimisticUser.id)
          .toList();

      // Añadir el mensaje de usuario persistido (usamos el optimista como
      // representación visual — sin ID real para el user msg, guardamos tal cual).
      updatedMessages.add(
        AiAssistantMessage(
          id: assistantMsg.id.isNotEmpty
              ? '${assistantMsg.id}_user' // proxy
              : optimisticUser.id,
          pactId: _pactId,
          role: 'user',
          content: userMessage.trim(),
          provider: assistantMsg.provider,
          createdAt: optimisticUser.createdAt,
        ),
      );
      updatedMessages.add(assistantMsg);

      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
      );
    } catch (e) {
      if (!mounted) return;
      // Eliminamos el mensaje optimista si falló.
      final revertedMessages =
          state.messages.where((m) => m.id != optimisticUser.id).toList();
      state = state.copyWith(
        messages: revertedMessages,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  /// El usuario confirma o cancela una tool call propuesta.
  Future<void> resolveToolCall({
    required String messageId,
    required bool confirmed,
  }) async {
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(
        toolCallStatus: confirmed ? 'confirmed' : 'cancelled',
      );
    }).toList();
    state = state.copyWith(messages: updated);

    // TODO Sprint 7 chunk 3+: si confirmed=true, ejecutar la tool via RPC.
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final assistantNotifierProvider = StateNotifierProvider.autoDispose
    .family<AssistantNotifier, AssistantState, String>(
  (ref, pactId) => AssistantNotifier(ref, pactId),
);
