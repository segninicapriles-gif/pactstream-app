import 'package:flutter/material.dart';

/// Paleta de colores de PactStream.
///
/// Basada en el Design System v1.0 (PactStream-DesignSystem.html).
/// Cualquier color hardcoded fuera de este archivo es un bug.
abstract final class AppColors {
  AppColors._();

  // === BRAND ===
  static const Color psNavy = Color(0xFF080D42);
  static const Color psBlue = Color(0xFF0121DC);
  static const Color psCyan = Color(0xFFA9F3FF);

  // Gradients
  static const LinearGradient psGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [psCyan, psBlue],
  );

  static const LinearGradient psGradientDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [psBlue, psNavy],
  );

  // === INK (escala neutra) ===
  static const Color ink900 = Color(0xFF0A0E2A);
  static const Color ink800 = Color(0xFF14193D);
  static const Color ink700 = Color(0xFF2A2F5C);
  static const Color ink600 = Color(0xFF4D5380);
  static const Color ink500 = Color(0xFF767BA3);
  static const Color ink400 = Color(0xFFA4A8C4);
  static const Color ink300 = Color(0xFFD0D3E3);
  static const Color ink200 = Color(0xFFE7E9F1);
  static const Color ink100 = Color(0xFFF3F4F9);
  static const Color ink50 = Color(0xFFFAFBFD);
  static const Color white = Color(0xFFFFFFFF);

  // === SEMÁNTICOS ===
  static const Color success = Color(0xFF00C389);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF4D6D);
  static const Color info = psBlue;

  // Backgrounds suaves para los semánticos
  static const Color successBg = Color(0x1A00C389); // 10% alpha
  static const Color warningBg = Color(0x24FFB020); // ~14% alpha
  static const Color errorBg = Color(0x1AFF4D6D); // 10% alpha
  static const Color infoBg = Color(0x140121DC); // ~8% alpha

  // === ROL DEL TÉCNICO ===
  // El header del técnico se cambió de verde (P0-13) a uno que no
  // colisiona con success. Se elige naranja arena.
  static const Color tecnicoAccent = Color(0xFFC97A2B);
  static const Color tecnicoAccentDark = Color(0xFFA56423);

  // === MATERIALCOLOR del azul principal ===
  // Para ColorScheme.fromSeed
  static const MaterialColor psBlueSwatch = MaterialColor(
    0xFF0121DC,
    <int, Color>{
      50: Color(0xFFE0E4FB),
      100: Color(0xFFB3BCF6),
      200: Color(0xFF8090F1),
      300: Color(0xFF4D63EB),
      400: Color(0xFF2742E6),
      500: Color(0xFF0121DC),
      600: Color(0xFF011DD8),
      700: Color(0xFF0118D3),
      800: Color(0xFF0114CE),
      900: Color(0xFF000BC5),
    },
  );
}
