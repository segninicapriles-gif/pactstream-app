import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'success_check_animation.dart';

/// Muestra una overlay efímera con la animación de check + mensaje.
///
/// Se usa tras acciones exitosas (depósito confirmado, contrato firmado,
/// certificación creada…). Se cierra automáticamente tras la animación.
///
/// ```dart
/// final ok = await PactActionsV2.fundDeposit(...);
/// if (ok && mounted) {
///   await showSuccessOverlay(context, message: 'Depósito confirmado');
/// }
/// ```
Future<void> showSuccessOverlay(
  BuildContext context, {
  required String message,
  Duration displayDuration = const Duration(milliseconds: 1400),
}) {
  AppHaptics.success();
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: AppMotion.fast,
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(opacity: anim, child: child);
    },
    pageBuilder: (ctx, _, __) {
      return _SuccessOverlayContent(
        message: message,
        displayDuration: displayDuration,
      );
    },
  );
}

class _SuccessOverlayContent extends StatefulWidget {
  const _SuccessOverlayContent({
    required this.message,
    required this.displayDuration,
  });

  final String message;
  final Duration displayDuration;

  @override
  State<_SuccessOverlayContent> createState() => _SuccessOverlayContentState();
}

class _SuccessOverlayContentState extends State<_SuccessOverlayContent> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss tras la duración indicada
    Future.delayed(widget.displayDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          margin: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessCheckAnimation(size: 64),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
