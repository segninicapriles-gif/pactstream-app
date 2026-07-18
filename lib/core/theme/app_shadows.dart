import 'package:flutter/material.dart';

/// Sombras de PactStream — Sistema ARCO (DESIGN-ECOSISTEMA.md 2026-07-18).
///
/// Recetas s1/s2/s3 tintadas al profundo de marca D = navy (8,13,66),
/// nunca negro puro. `soft`→s1, `medium`→s2, `high`→s3 (nombres de campo
/// conservados por compatibilidad con los widgets existentes).
///
/// Reservar `glow` solo para 1-2 CTAs primarios. Su uso indiscriminado
/// resta sensación de seriedad fintech (P1 del design critique).
abstract final class AppShadows {
  AppShadows._();

  /// s1: `0 1px 2px rgba(D,.05), 0 0 0 1px rgba(D,.04)`.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0D080D42), // 5% alpha sobre navy
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color(0x0A080D42), // 4% alpha sobre navy
      offset: Offset.zero,
      blurRadius: 0,
      spreadRadius: 1,
    ),
  ];

  /// s2: `0 10px 28px -10px rgba(D,.16)`.
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x29080D42), // 16% alpha sobre navy
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -10,
    ),
  ];

  /// s3: `0 28px 56px -16px rgba(D,.22)`.
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x38080D42), // 22% alpha sobre navy
      offset: Offset(0, 28),
      blurRadius: 56,
      spreadRadius: -16,
    ),
  ];

  /// Glow cyan (el glow de la bóveda) al 16%. Reservar para el botón
  /// primario de cierre del flujo.
  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x29A9F3FF), // 16% alpha sobre psCyan
      offset: Offset(0, 8),
      blurRadius: 32,
    ),
  ];
}
