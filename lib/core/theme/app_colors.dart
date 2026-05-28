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

  // === INK (escala neutra · light) ===
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

  // Backgrounds suaves para los semánticos (light)
  static const Color successBg = Color(0x1A00C389); // 10% alpha
  static const Color warningBg = Color(0x24FFB020); // ~14% alpha
  static const Color errorBg = Color(0x1AFF4D6D); // 10% alpha
  static const Color infoBg = Color(0x140121DC); // ~8% alpha

  // === ROL DEL TÉCNICO ===
  // El header del técnico se cambió de verde (P0-13) a uno que no
  // colisiona con success. Se elige naranja arena.
  static const Color tecnicoAccent = Color(0xFFC97A2B);
  static const Color tecnicoAccentDark = Color(0xFFA56423);

  // === SCORING · Tiers de reputación ===
  static const Color tierBronce  = Color(0xFFCD7F32);
  static const Color tierPlata   = Color(0xFF94A3B8);
  static const Color tierOro     = Color(0xFFF59E0B);
  static const Color tierPlatino = Color(0xFF38BDF8);
  static const Color tierElite1  = Color(0xFF6366F1); // gradiente inicio
  static const Color tierElite2  = Color(0xFF8B5CF6); // gradiente fin

  // Backgrounds suaves para cada tier
  static const Color tierBronceBg  = Color(0x1ACD7F32);
  static const Color tierPlataBg   = Color(0x1A94A3B8);
  static const Color tierOroBg     = Color(0x1AF59E0B);
  static const Color tierPlatinoBg = Color(0x1A38BDF8);
  static const Color tierEliteBg   = Color(0x1A6366F1);

  // Gauge arc · colores del gradiente rojo→ámbar→verde
  static const Color gaugeRed    = Color(0xFFFF4D6D); // = error
  static const Color gaugeAmber  = Color(0xFFFFB020); // = warning
  static const Color gaugeGreen  = Color(0xFF00C389); // = success

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

  // ═══════════════════════════════════════════════════════════════════════
  // DARK MODE PALETTE
  // ═══════════════════════════════════════════════════════════════════════

  /// Deep navy backgrounds — no pure black, keeps the brand feel.
  static const Color darkBg = Color(0xFF0B0F28);
  static const Color darkSurface = Color(0xFF141837);
  static const Color darkSurfaceElevated = Color(0xFF1C2045);
  static const Color darkSurfaceHigh = Color(0xFF252A52);
  static const Color darkBorder = Color(0xFF2E3460);

  /// Dark gradient for AppBar / headers (slightly brighter than darkBg).
  static const LinearGradient psGradientDeepDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1530B0), Color(0xFF0B0F28)],
  );

  /// Semantic backgrounds — richer tints on dark surfaces.
  static const Color darkSuccessBg = Color(0x2600C389);
  static const Color darkWarningBg = Color(0x30FFB020);
  static const Color darkErrorBg = Color(0x26FF4D6D);
  static const Color darkInfoBg = Color(0x260121DC);
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTEXT EXTENSION · resolves semantic colors by brightness
// ═══════════════════════════════════════════════════════════════════════════

/// Extensión sobre BuildContext para obtener colores semánticos que
/// se adaptan automáticamente al modo light/dark.
///
/// Uso: `context.colors.card` en vez de `AppColors.white`.
extension AppColorSchemeX on BuildContext {
  _ResolvedColors get colors =>
      Theme.of(this).brightness == Brightness.dark
          ? const _ResolvedColors.dark()
          : const _ResolvedColors.light();
}

/// Set de colores semánticos resueltos para light o dark mode.
class _ResolvedColors {
  const _ResolvedColors.light()
      : card = AppColors.white,
        scaffold = AppColors.ink50,
        border = AppColors.ink200,
        borderSubtle = AppColors.ink100,
        divider = AppColors.ink200,
        textPrimary = AppColors.ink900,
        textSecondary = AppColors.ink600,
        textTertiary = AppColors.ink500,
        textHint = AppColors.ink400,
        headerGradient = AppColors.psGradientDeep,
        successBg = AppColors.successBg,
        warningBg = AppColors.warningBg,
        errorBg = AppColors.errorBg,
        infoBg = AppColors.infoBg,
        chipBg = AppColors.ink100,
        chipText = AppColors.ink600,
        inputFill = AppColors.white,
        shadowBase = AppColors.psNavy,
        navBg = AppColors.white,
        navBorder = AppColors.ink200,
        pillBg = const Color(0x1A0121DC), // psBlue 10%
        shimmerBase = AppColors.ink100,
        shimmerHighlight = AppColors.ink50;

  const _ResolvedColors.dark()
      : card = AppColors.darkSurface,
        scaffold = AppColors.darkBg,
        border = AppColors.darkBorder,
        borderSubtle = AppColors.darkSurfaceElevated,
        divider = AppColors.darkBorder,
        textPrimary = AppColors.ink200,
        textSecondary = AppColors.ink400,
        textTertiary = AppColors.ink500,
        textHint = AppColors.ink600,
        headerGradient = AppColors.psGradientDeepDark,
        successBg = AppColors.darkSuccessBg,
        warningBg = AppColors.darkWarningBg,
        errorBg = AppColors.darkErrorBg,
        infoBg = AppColors.darkInfoBg,
        chipBg = AppColors.darkSurfaceElevated,
        chipText = AppColors.ink400,
        inputFill = AppColors.darkSurfaceElevated,
        shadowBase = const Color(0xFF000000),
        navBg = AppColors.darkSurface,
        navBorder = AppColors.darkBorder,
        pillBg = const Color(0x260121DC), // psBlue 15%
        shimmerBase = AppColors.darkSurfaceElevated,
        shimmerHighlight = AppColors.darkSurfaceHigh;

  final Color card;
  final Color scaffold;
  final Color border;
  final Color borderSubtle;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textHint;
  final LinearGradient headerGradient;
  final Color successBg;
  final Color warningBg;
  final Color errorBg;
  final Color infoBg;
  final Color chipBg;
  final Color chipText;
  final Color inputFill;
  final Color shadowBase;
  final Color navBg;
  final Color navBorder;
  final Color pillBg;
  final Color shimmerBase;
  final Color shimmerHighlight;
}
