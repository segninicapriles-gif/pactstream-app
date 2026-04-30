import 'package:flutter/material.dart';

/// Sombras de PactStream (Design System v1.0).
///
/// Reservar `glow` solo para 1-2 CTAs primarios. Su uso indiscriminado
/// resta sensación de seriedad fintech (P1 del design critique).
abstract final class AppShadows {
  AppShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F080D42), // 6% alpha sobre navy
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1A080D42), // 10% alpha
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x29080D42), // 16% alpha
      offset: Offset(0, 16),
      blurRadius: 40,
    ),
  ];

  /// Glow azul. Reservar para botón primario de cierre del flujo.
  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x330121DC), // 20% alpha sobre psBlue
      offset: Offset(0, 8),
      blurRadius: 32,
    ),
  ];
}
