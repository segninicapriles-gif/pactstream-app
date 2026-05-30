import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_haptics.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';

/// Botón canónico de PactStream.
///
/// Variantes:
///   - `PsButton.primary` — azul con glow (CTA principal de cierre de flujo)
///   - `PsButton.secondary` — outlined ghost
///   - `PsButton.text` — solo texto azul
///   - `PsButton.danger` — rojo (acciones destructivas o disputa)
///
/// Reserva del glow para 1-2 momentos por pantalla (ver Design Handoff §3.4).
class PsButton extends StatelessWidget {
  const PsButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.glow = false,
    super.key,
  })  : _variant = _PsButtonVariant.primary,
        _isDestructive = false;

  const PsButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    super.key,
  })  : _variant = _PsButtonVariant.secondary,
        glow = false,
        _isDestructive = false;

  const PsButton.text({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = false,
    super.key,
  })  : _variant = _PsButtonVariant.text,
        glow = false,
        _isDestructive = false;

  const PsButton.danger({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    super.key,
  })  : _variant = _PsButtonVariant.primary,
        glow = false,
        _isDestructive = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final bool glow;
  final _PsButtonVariant _variant;
  final bool _isDestructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );

    VoidCallback? wrappedOnPressed;
    if (!disabled && onPressed != null) {
      wrappedOnPressed = () {
        AppHaptics.medium();
        onPressed!();
      };
    }

    final Widget button = switch (_variant) {
      _PsButtonVariant.primary => _PrimaryButton(
          onPressed: wrappedOnPressed,
          glow: glow,
          isDestructive: _isDestructive,
          child: child,
        ),
      _PsButtonVariant.secondary => OutlinedButton(
          onPressed: wrappedOnPressed,
          child: child,
        ),
      _PsButtonVariant.text => TextButton(
          onPressed: wrappedOnPressed,
          child: child,
        ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onPressed,
    required this.child,
    required this.glow,
    required this.isDestructive,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool glow;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? AppColors.error
        : isDark
            ? AppColors.darkPrimaryButton
            : AppColors.psBlue;
    return Container(
      decoration: BoxDecoration(
        boxShadow: glow ? AppShadows.glow : null,
        borderRadius: AppRadius.mdAll,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

enum _PsButtonVariant { primary, secondary, text }
