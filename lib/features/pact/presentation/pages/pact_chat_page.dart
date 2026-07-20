import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/pact_chat.dart';

/// Chat entre las partes del pacto (F2.4b MVP · sin realtime, sin
/// attachments). Envío + lista + soft-delete propio. Al abrir marca
/// como leídos.
class PactChatPage extends ConsumerStatefulWidget {
  const PactChatPage({
    super.key,
    required this.pactId,
    required this.pactTitle,
  });

  final String pactId;
  final String pactTitle;

  @override
  ConsumerState<PactChatPage> createState() => _PactChatPageState();
}

class _PactChatPageState extends ConsumerState<PactChatPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Marcar leído al abrir. Best-effort — no bloqueamos la UI.
    Future.microtask(() => markPactRead(widget.pactId));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await sendPactMessage(widget.pactId, body);
      _controller.clear();
      // Recargar la lista; también resetea el badge de no leídos.
      ref.invalidate(pactMessagesProvider(widget.pactId));
      ref.invalidate(pactUnreadCountProvider(widget.pactId));
      // Scroll al final (la lista está reverse:true así que jump(0)).
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pactMessagesProvider(widget.pactId));

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: context.colors.headerGradient),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chat', style: AppTypography.body.copyWith(color: AppColors.white, fontWeight: FontWeight.w700)),
            Text(widget.pactTitle,
                style: AppTypography.caption.copyWith(color: AppColors.white.withOpacity(0.7)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: AppColors.error),
                    ),
                  ),
                ),
                data: (messages) => messages.isEmpty
                    ? _EmptyChat(pactTitle: widget.pactTitle)
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(pactMessagesProvider(widget.pactId));
                          await ref.read(pactMessagesProvider(widget.pactId).future);
                        },
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true, // lo más reciente abajo
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                              horizontal: AppSpacing.sm),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final m = messages[i];
                            final prev = i + 1 < messages.length ? messages[i + 1] : null;
                            // Agrupamos consecutivos del mismo autor
                            // (sin repetir cabecera).
                            final showHeader = prev == null ||
                                prev.senderUserId != m.senderUserId ||
                                m.createdAt.difference(prev.createdAt).inMinutes.abs() > 10;
                            return _MessageBubble(
                              message: m,
                              showHeader: showHeader,
                              onDelete: m.isMine && !m.isDeleted
                                  ? () async {
                                      try {
                                        await deletePactMessage(m.id);
                                        ref.invalidate(pactMessagesProvider(widget.pactId));
                                      } on Exception catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                                content: Text(e
                                                    .toString()
                                                    .replaceFirst('Exception: ', ''))),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
              ),
            ),
            _InputBar(
              controller: _controller,
              focusNode: _focusNode,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.pactTitle});

  final String pactTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48, color: context.colors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Aún no hay mensajes',
              style: AppTypography.h3.copyWith(color: context.colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Coordinar por aquí queda registrado en el pacto y protege '
              'a ambas partes si algo se discute más adelante.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showHeader,
    required this.onDelete,
  });

  final PactMessage message;
  final bool showHeader;
  final VoidCallback? onDelete;

  Color _roleColor(BuildContext context) {
    switch (message.senderRole) {
      case 'promotor':
        return AppColors.psBlue;
      case 'tecnico':
        return AppColors.tecnicoAccent;
      case 'constructor':
        return AppColors.success;
      default:
        return context.colors.textTertiary;
    }
  }

  String _roleLabel() {
    switch (message.senderRole) {
      case 'promotor':
        return 'Promotor';
      case 'tecnico':
        return 'Técnico';
      case 'constructor':
        return 'Constructor';
      default:
        return 'Miembro';
    }
  }

  String _time() {
    final h = message.createdAt.hour.toString().padLeft(2, '0');
    final m = message.createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMine
        ? context.colors.brandAccentBg
        : context.colors.card;
    return Padding(
      padding: EdgeInsets.only(
        top: showHeader ? AppSpacing.md : 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (showHeader && !isMine)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.senderName ?? _roleLabel(),
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _roleColor(context).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _roleLabel(),
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: _roleColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: GestureDetector(
              onLongPress: onDelete == null
                  ? null
                  : () => _showDeleteSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: AppRadius.lgAll,
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isDeleted)
                      Text(
                        'mensaje eliminado',
                        style: AppTypography.bodyS.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.colors.textTertiary,
                        ),
                      )
                    else
                      Text(
                        message.body ?? '',
                        style: AppTypography.body.copyWith(
                          color: context.colors.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _time(),
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Eliminar mi mensaje'),
              subtitle: const Text(
                  'Se marcará como "mensaje eliminado" en el hilo. El resto seguirá viendo el hueco.'),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete?.call();
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 4,
              minLines: 1,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              enabled: !sending,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje…',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: context.colors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Icon(Icons.send),
            onPressed: sending ? null : onSend,
            tooltip: 'Enviar',
          ),
        ],
      ),
    );
  }
}
