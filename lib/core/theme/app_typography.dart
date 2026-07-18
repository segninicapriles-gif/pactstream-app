import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema tipográfico de PactStream — Sistema ARCO.
///
/// Display (XL/L/H1/H2): Bricolage Grotesque — voz diferencial del ecosistema.
/// UI/Cuerpo (H3..label): Hanken Grotesk.
/// Datos/dinero: JetBrains Mono (Cifra Viva).
/// Nunito queda reservado al wordmark (pactstream_logo.dart).
///
/// Escala:
///   Display XL: 72 / 800 / -0.03em
///   Display L:  48 / 800 / -0.02em
///   H1:         32 / 700 / -0.01em
///   H2:         24 / 700
///   H3:         20 / 600
///   Body L:     17 / 400
///   Body:       15 / 400
///   Body S:     13 / 400
///   Caption:    11 / 600 / +0.04em / UPPERCASE
///
/// **Color**: NO se define aquí. Los estilos heredan el color del
/// `TextTheme` del tema activo (light → ink900/800, dark → ink200).
/// Para colores semánticos, usar `.copyWith(color: context.colors.xxx)`.
abstract final class AppTypography {
  AppTypography._();

  static TextStyle get displayXL => GoogleFonts.bricolageGrotesque(
        fontSize: 72,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -2.16, // -0.03em
      );

  static TextStyle get displayL => GoogleFonts.bricolageGrotesque(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.96, // -0.02em
      );

  static TextStyle get h1 => GoogleFonts.bricolageGrotesque(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.32, // -0.01em
      );

  static TextStyle get h2 => GoogleFonts.bricolageGrotesque(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get h3 => GoogleFonts.hankenGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get bodyL => GoogleFonts.hankenGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.55,
      );

  static TextStyle get body => GoogleFonts.hankenGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyS => GoogleFonts.hankenGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get caption => GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.44, // 0.04em
      );

  /// Estilo para etiquetas de campos / secciones (más fuerte que body S).
  /// Usar para títulos de subsecciones dentro de cards.
  static TextStyle get label => GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: 0.5,
      );

  /// Estilo monoespaciado para metadata técnica (IDs, hashes, fechas forenses).
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  /// TextTheme completo para Material 3.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayXL,
        displayMedium: displayL,
        displaySmall: h1,
        headlineLarge: h1,
        headlineMedium: h2,
        headlineSmall: h3,
        titleLarge: h3,
        titleMedium: bodyL.copyWith(fontWeight: FontWeight.w600),
        titleSmall: body.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: bodyL,
        bodyMedium: body,
        bodySmall: bodyS,
        labelLarge: body.copyWith(fontWeight: FontWeight.w700),
        labelMedium: bodyS.copyWith(fontWeight: FontWeight.w600),
        labelSmall: caption,
      );
}
