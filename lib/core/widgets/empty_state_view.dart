import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_motion.dart';

/// Vista reutilizable para estados vacíos.
///
/// Muestra un icono circular con fondo branded, título, subtítulo y un CTA
/// opcional. Incluye una animación de entrada sutil (fade + scale).
///
/// ```dart
/// EmptyStateView(
///   icon: Icons.folder_outlined,
///   title: 'Sin obras',
///   subtitle: 'Crea tu primera obra para empezar.',
///   actionLabel: 'Crear obra',
///   onAction: () => context.push(AppRoutes.pactNew),
/// )
/// ```
class EmptyStateView extends StatefulWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.scrollable = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Si es true, envuelve en ListView para que funcione con RefreshIndicator.
  final bool scrollable;

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.emphasis,
    );
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: AppMotion.enter,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: AppMotion.emphasize),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      label: '${widget.title}. ${widget.subtitle}',
      child: FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              // Icono circular branded
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.colors.brandAccentBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: context.colors.brandAccent, size: 48),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(color: context.colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: context.colors.textTertiary),
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  icon: Icon(widget.actionIcon ?? Icons.add_circle_outline),
                  onPressed: widget.onAction,
                  label: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    ),  // close Semantics
    );

    if (widget.scrollable) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [content],
      );
    }
    return Center(child: content);
  }
}

/// Vista reutilizable para estados de error.
///
/// Muestra icono de error con fondo circular, mensaje, detalle técnico
/// y botón de reintentar.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.scrollable = true,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      liveRegion: true,
      label: 'Error. $title. $message',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 64),
            // Icono circular
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.colors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center, style: AppTypography.h3.copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );

    if (scrollable) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [content],
      );
    }
    return Center(child: content);
  }
}
