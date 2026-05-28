/// Pantalla del asistente conversacional de PactStream.
///
/// Scoped a un pacto: cada pacto tiene su propio hilo de conversación.
/// Se accede desde la pestaña "Asistente" en PactDetailPage o desde
/// un FloatingActionButton en MilestoneDetailPage.
///
/// Características:
///   - Historial cargado desde `ai_assistant_messages` al entrar.
///   - Optimismo: el mensaje del usuario aparece inmediatamente.
///   - Tool call proposals: botones Confirmar / Cancelar bajo la burbuja.
///   - Chips de acciones rápidas para los intents más frecuentes.
///   - Badge DEMO cuando el asistente responde en modo fixture.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/ai_models.dart';
import '../../data/ai_providers.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({
    super.key,
    required this.pactId,
    required this.pactTitle,
  });

  final String pactId;
  final String pactTitle;

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _scrollController = ScrollController();
  final _inputCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Cargar historial al entrar (fuera del build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        ref
            .read(assistantNotifierProvider(widget.pactId).notifier)
            .loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send({String? quickIntent, String? intentKey}) async {
    final text = quickIntent ?? _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    FocusScope.of(context).unfocus();

    await ref
        .read(assistantNotifierProvider(widget.pactId).notifier)
        .send(text, intentKey: intentKey);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantNotifierProvider(widget.pactId));

    // Hacer scroll al final cada vez que llega un mensaje nuevo.
    if (state.messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.psCyan, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text('Asistente Pact',
                    style: AppTypography.h3
                        .copyWith(color: AppColors.white)),
              ],
            ),
            Text(
              widget.pactTitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.psCyan,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: state.messages.isEmpty && !state.isSending
                ? const _EmptyConversation()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md),
                    itemCount: state.messages.length +
                        (state.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = state.messages[index];
                      return _MessageBubble(
                        message: msg,
                        onConfirmTool: () => ref
                            .read(assistantNotifierProvider(widget.pactId)
                                .notifier)
                            .resolveToolCall(
                                messageId: msg.id, confirmed: true),
                        onCancelTool: () => ref
                            .read(assistantNotifierProvider(widget.pactId)
                                .notifier)
                            .resolveToolCall(
                                messageId: msg.id, confirmed: false),
                      );
                    },
                  ),
          ),
          // Error banner
          if (state.error != null)
            _ErrorBanner(
              message: state.error!,
              onDismiss: () => ref
                  .read(assistantNotifierProvider(widget.pactId).notifier)
                  .clearError(),
            ),
          // Chips de acciones rápidas (solo si no hay mensajes aún)
          if (state.messages.isEmpty)
            _QuickActionsBar(onSelected: _send),
          // Input
          _InputBar(
            controller: _inputCtrl,
            isSending: state.isSending,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ESTADO VACÍO
// =====================================================================

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.psGradientDeep,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.psCyan, size: 28),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Hola, soy Pact',
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Puedo explicarte el estado de la obra, '
              'los hitos, el análisis de evidencias y '
              'ayudarte a tomar acciones.',
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(color: context.colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// BURBUJAS DE CHAT
// =====================================================================

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onConfirmTool,
    required this.onCancelTool,
  });

  final AiAssistantMessage message;
  final VoidCallback onConfirmTool;
  final VoidCallback onCancelTool;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Burbuja
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _AvatarDot(),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.psBlue : context.colors.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.lg),
                      topRight: const Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
                      bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
                    ),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Text(
                    message.content ?? '',
                    style: AppTypography.body.copyWith(
                      color: isUser ? AppColors.white : context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: AppSpacing.xs),
                _UserDot(),
              ],
            ],
          ),
          // Metadata (demo badge + hora)
          Padding(
            padding: EdgeInsets.only(
              top: AppSpacing.xs,
              left: isUser ? 0 : 36,
              right: isUser ? 36 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser && message.isDemo == true)
                  _DemoBadge(),
                if (!isUser && message.isDemo == true)
                  const SizedBox(width: AppSpacing.xs),
                Text(
                  _fmtTime(message.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: context.colors.textHint,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          // Tool call proposal (solo asistente)
          if (!isUser && message.hasToolCallProposal) ...[
            const SizedBox(height: AppSpacing.xs),
            _ToolCallProposal(
              name: message.toolCallName!,
              onConfirm: onConfirmTool,
              onCancel: onCancelTool,
            ),
          ],
          // Tool call resultada (confirmada / cancelada)
          if (!isUser &&
              (message.toolCallStatus == 'confirmed' ||
                  message.toolCallStatus == 'cancelled'))
            Padding(
              padding: const EdgeInsets.only(left: 36, top: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.toolCallStatus == 'confirmed'
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 13,
                    color: message.toolCallStatus == 'confirmed'
                        ? AppColors.success
                        : context.colors.textHint,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    message.toolCallStatus == 'confirmed'
                        ? 'Acción confirmada'
                        : 'Cancelado',
                    style: AppTypography.caption.copyWith(
                      color: message.toolCallStatus == 'confirmed'
                          ? AppColors.success
                          : context.colors.textHint,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _AvatarDot() => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          gradient: AppColors.psGradientDeep,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome,
            size: 13, color: AppColors.psCyan),
      );

  Widget _UserDot() => Builder(builder: (context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: context.colors.brandAccent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person_outline,
            size: 15, color: context.colors.brandAccent),
      ));

  Widget _DemoBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.psNavy.withValues(alpha: 0.08),
          borderRadius: AppRadius.xsAll,
          border: Border.all(
              color: AppColors.psNavy.withValues(alpha: 0.2)),
        ),
        child: Text(
          'DEMO',
          style: AppTypography.caption.copyWith(
            color: AppColors.psNavy,
            fontWeight: FontWeight.w800,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      );

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// =====================================================================
// TOOL CALL PROPOSAL
// =====================================================================

class _ToolCallProposal extends StatelessWidget {
  const _ToolCallProposal({
    required this.name,
    required this.onConfirm,
    required this.onCancel,
  });

  final String name;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final label = switch (name) {
      'request_evidence' => '¿Solicitar evidencias a la constructora?',
      'raise_objection'  => '¿Abrir disputa sobre este hito?',
      'summarize_pact'   => '¿Generar resumen ejecutivo del pacto?',
      _ => '¿Ejecutar esta acción?',
    };
    return Container(
      margin: const EdgeInsets.only(left: 36),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppRadius.smAll,
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyS.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    foregroundColor: context.colors.textSecondary,
                    side:
                        BorderSide(color: context.colors.border),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    backgroundColor: AppColors.psBlue,
                  ),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// TYPING INDICATOR
// =====================================================================

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: AppColors.psGradientDeep,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                size: 13, color: AppColors.psCyan),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.xs),
              ),
              boxShadow: AppShadows.soft,
            ),
            child: const SizedBox(
              height: 16,
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Dot(delay: 0),
                  _Dot(delay: 150),
                  _Dot(delay: 300),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: context.colors.textHint,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// =====================================================================
// CHIPS DE ACCIONES RÁPIDAS
// =====================================================================

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({required this.onSelected});

  final void Function({String? quickIntent, String? intentKey}) onSelected;

  static const _actions = [
    (
      label: '¿En qué hito estamos?',
      icon: Icons.location_on_outlined,
      intentKey: 'intent_estado_pacto',
    ),
    (
      label: '¿Cuánto queda por liberar?',
      icon: Icons.account_balance_wallet_outlined,
      intentKey: 'intent_cuanto_falta_liberar',
    ),
    (
      label: 'Explica el análisis IA',
      icon: Icons.auto_awesome_outlined,
      intentKey: 'intent_explicar_dictamen',
    ),
    (
      label: 'Resumen del pacto',
      icon: Icons.summarize_outlined,
      intentKey: 'intent_resumen_pacto',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.card,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final a in _actions)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ActionChip(
                  avatar: Icon(a.icon, size: 16),
                  label: Text(a.label),
                  labelStyle: AppTypography.caption
                      .copyWith(letterSpacing: 0, color: context.colors.textSecondary),
                  onPressed: () => onSelected(
                    quickIntent: a.label,
                    intentKey: a.intentKey,
                  ),
                  backgroundColor: context.colors.chipBg,
                  side: BorderSide(color: context.colors.border),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// INPUT BAR
// =====================================================================

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: context.colors.card,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Pregunta algo sobre la obra…',
                  hintStyle: AppTypography.body
                      .copyWith(color: context.colors.textHint),
                  filled: true,
                  fillColor: context.colors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.xlAll,
                    borderSide:
                        BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.xlAll,
                    borderSide:
                        BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.xlAll,
                    borderSide:
                        const BorderSide(color: AppColors.psBlue, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isSending ? null : AppColors.psGradientDeep,
                color: isSending ? context.colors.border : null,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.white, size: 20),
                      onPressed: onSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ERROR BANNER
// =====================================================================

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.errorBg,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: AppColors.error, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
