import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class AppMotion {
  AppMotion._();

  // === DURATIONS ===
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration emphasis = Duration(milliseconds: 600);

  // === CURVES ===
  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve emphasize = Curves.easeInOutCubicEmphasized;
  static const Curve spring = Curves.elasticOut;

  // === PAGE TRANSITIONS ===
  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  static Widget slideUpTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tween = Tween(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).chain(CurveTween(curve: enter));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: tween.animate(animation), child: child),
    );
  }

  static CustomTransitionPage<T> fadePage<T>({
    required Widget child,
    LocalKey? key,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: fast,
      reverseTransitionDuration: fast,
      transitionsBuilder: fadeTransition,
    );
  }

  static CustomTransitionPage<T> slideUpPage<T>({
    required Widget child,
    LocalKey? key,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      transitionsBuilder: slideUpTransition,
    );
  }
}
