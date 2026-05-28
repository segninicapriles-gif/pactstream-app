import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../utils/app_haptics.dart';

/// Wrapper que añade feedback táctil rico a cualquier card/widget interactivo.
///
/// Efectos al presionar:
///   • Scale-down (0.97) con curva elástica
///   • Reducción de opacidad (→ 0.85) para sensación de "hundido"
///   • Elevación reducida (shadow desaparece) reforzando profundidad
///   • Haptic feedback ligero (opcional)
///
/// Al soltar, todos los valores se restauran con una curva de salida suave.
///
/// Uso:
/// ```dart
/// PressableCard(
///   onTap: () => context.push('/pacts/$id'),
///   child: Container(
///     padding: ...,
///     decoration: ...,
///     child: ...,
///   ),
/// )
/// ```
class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.97,
    this.haptic = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Factor de escala al presionar. 0.97 = 3% de reducción.
  final double scaleDown;

  /// Si es true, ejecuta un HapticFeedback.lightImpact al presionar.
  final bool haptic;

  /// Border radius para el InkWell splash (opcional).
  final BorderRadius? borderRadius;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.instant,
      reverseDuration: AppMotion.fast,
    );

    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: AppMotion.standard,
      reverseCurve: AppMotion.enter,
    );

    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(curved);

    _opacityAnim = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(curved);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _ctrl.forward();
    if (widget.haptic) {
      AppHaptics.light();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
  }

  void _onTapCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
