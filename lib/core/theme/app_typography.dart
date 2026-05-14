import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Sistema tipográfico de PactStream basado en Nunito.
///
/// Escala según Design System v1.0:
///   Display XL: 72 / 800 / -0.03em
///   Display L:  48 / 800 / -0.02em
///   H1:         32 / 700 / -0.01em
///   H2:         24 / 700
///   H3:         20 / 600
///   Body L:     17 / 400
///   Body:       15 / 400
///   Body S:     13 / 400
///   Caption:    11 / 600 / +0.04em / UPPERCASE
abstract final class AppTypography {
  AppTypography._();

  static TextStyle get displayXL => GoogleFonts.nunito(
        fontSize: 72,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -2.16, // -0.03em
        color: AppColors.ink900,
      );

  static TextStyle get displayL => GoogleFonts.nunito(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.96, // -0.02em
        color: AppColors.ink900,
      );

  static TextStyle get h1 => GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.32, // -0.01em
        color: AppColors.ink900,
      );

  static TextStyle get h2 => GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.ink900,
      );

  static TextStyle get h3 => GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.ink900,
      );

  static TextStyle get bodyL => GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: AppColors.ink800,
      );

  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.ink800,
      );

  static TextStyle get bodyS => GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.ink700,
      );

  static TextStyle get caption => GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.44, // 0.04em
        color: AppColors.ink600,
      );

  /// Estilo para etiquetas de campos / secciones (más fuerte que body S).
  /// Usar para títulos de subsecciones dentro de cards.
  static TextStyle get label => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: 0.5,
        color: AppColors.ink600,
      );

  /// Estilo monoespaciado para metadata técnica (IDs, hashes, fechas forenses).
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.ink600,
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
