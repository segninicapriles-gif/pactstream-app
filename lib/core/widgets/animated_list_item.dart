import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Widget que anima la entrada de un elemento de lista con fade + slide-up.
///
/// Cada item arranca con un delay proporcional a su [index], creando un
/// efecto "staggered" que da vida a las listas cuando se cargan por primera
/// vez o cuando se refresca la data.
///
/// Uso:
/// ```dart
/// ListView.builder(
///   itemBuilder: (ctx, i) => AnimatedListItem(
///     index: i,
///     child: MyCard(...),
///   ),
/// )
/// ```
class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = AppMotion.normal,
    this.staggerDelay = const Duration(milliseconds: 40),
    this.slideOffset = 0.03,
    this.curve = AppMotion.enter,
  });

  /// Posicion en la lista. Determina el delay del stagger.
  final int index;

  /// Widget hijo a animar.
  final Widget child;

  /// Duracion total de la animacion de cada item.
  final Duration duration;

  /// Delay entre items consecutivos.
  final Duration staggerDelay;

  /// Offset vertical inicial (fraccion de pantalla). 0.04 = 4% hacia abajo.
  final double slideOffset;

  /// Curva de la animacion.
  final Curve curve;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(curved);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(curved);

    // Stagger: delay proporcional al index (max 8 items con delay).
    final clampedIndex = widget.index.clamp(0, 8);
    final delay = widget.staggerDelay * clampedIndex;

    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}
