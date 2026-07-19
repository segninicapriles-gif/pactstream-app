import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Theme principal de PactStream para Material 3.
abstract final class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.psBlue,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.psCyan,
          onPrimaryContainer: AppColors.psNavy,
          secondary: AppColors.psNavy,
          onSecondary: AppColors.white,
          tertiary: AppColors.psCyan,
          surface: AppColors.white,
          onSurface: AppColors.ink900,
          surfaceContainerLowest: AppColors.ink50,
          surfaceContainerLow: AppColors.ink100,
          surfaceContainer: AppColors.ink100,
          surfaceContainerHigh: AppColors.ink200,
          surfaceContainerHighest: AppColors.ink200,
          error: AppColors.error,
          onError: AppColors.white,
          outline: AppColors.ink300,
          outlineVariant: AppColors.ink200,
        ),
        scaffoldBackgroundColor: AppColors.ink50,
        textTheme: AppTypography.textTheme.apply(
          bodyColor: AppColors.ink800,
          displayColor: AppColors.ink900,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.psNavy,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.hankenGrotesk(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.psBlue,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.ink200,
            disabledForegroundColor: AppColors.ink500,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.psBlue,
            side: const BorderSide(color: AppColors.ink200, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.psBlue,
            textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.ink200, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.ink200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.psBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          labelStyle: AppTypography.bodyS.copyWith(color: AppColors.ink700),
          hintStyle: AppTypography.body.copyWith(color: AppColors.ink400),
          errorStyle: AppTypography.bodyS.copyWith(color: AppColors.error),
        ),
        // Gramática §8b: tarjetas SIN borde visible (shape sin `side` →
        // BorderSide.none por defecto en RoundedRectangleBorder). Material's
        // CardThemeData no soporta boxShadow multi-capa (AppShadows.s1), así
        // que se aproxima con elevación muy baja + shadowColor navy tenue.
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 1,
          shadowColor: AppColors.psNavy.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.ink200,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.psBlue,
          unselectedItemColor: AppColors.ink500,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          // Gramática §8b: label activa w800 (antes w700), inactiva gris.
          // Sin subrayado/indicador — BottomNavigationBarThemeData no
          // dibuja chip ni caja alrededor del ítem seleccionado.
          selectedLabelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
          unselectedLabelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        // Gramática §8b: chips = mini-pill tintada ~12%, sin borde.
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.psBlue.withValues(alpha: 0.12),
          labelStyle: AppTypography.caption.copyWith(color: AppColors.psBlue),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: const StadiumBorder(),
          side: BorderSide.none,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.ink900,
          contentTextStyle: AppTypography.body.copyWith(color: AppColors.white),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.psBlue,
          onPrimary: AppColors.white,
          primaryContainer: Color(0xFF1530B0), // brighter navy-blue
          onPrimaryContainer: AppColors.psCyan,
          secondary: AppColors.psCyan,
          onSecondary: AppColors.psNavy,
          tertiary: AppColors.psCyan,
          surface: AppColors.darkSurface,
          onSurface: AppColors.ink200,
          surfaceContainerLowest: AppColors.darkBg,
          surfaceContainerLow: AppColors.darkSurface,
          surfaceContainer: AppColors.darkSurfaceElevated,
          surfaceContainerHigh: AppColors.darkSurfaceHigh,
          surfaceContainerHighest: Color(0xFF2E3460),
          error: AppColors.error,
          onError: AppColors.white,
          outline: AppColors.darkBorder,
          outlineVariant: AppColors.darkSurfaceHigh,
        ),
        scaffoldBackgroundColor: AppColors.darkBg,
        textTheme: AppTypography.textTheme.apply(
          bodyColor: AppColors.ink200,
          displayColor: AppColors.ink200,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.hankenGrotesk(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkPrimaryButton,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.darkSurfaceHigh,
            disabledForegroundColor: AppColors.ink500,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.psCyan,
            side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.psCyan,
            textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceElevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.psBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          labelStyle: AppTypography.bodyS.copyWith(color: AppColors.ink400),
          hintStyle: AppTypography.body.copyWith(color: AppColors.ink600),
          errorStyle: AppTypography.bodyS.copyWith(color: AppColors.error),
        ),
        // Gramática §8b: tarjetas SIN borde visible (antes tenían
        // BorderSide navy 0.5px — retirado). Se aproxima el efecto de
        // AppShadows.s1 con elevación muy baja + shadowColor navy tenue,
        // ya que CardThemeData no soporta boxShadow multi-capa.
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 1,
          shadowColor: AppColors.psNavy.withValues(alpha: 0.3),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.psCyan,
          unselectedItemColor: AppColors.ink500,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          // Gramática §8b: label activa w800 (antes w700), inactiva gris.
          // Sin subrayado/indicador — BottomNavigationBarThemeData no
          // dibuja chip ni caja alrededor del ítem seleccionado.
          selectedLabelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
          unselectedLabelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        // Gramática §8b: chips = mini-pill tintada ~12-14%, sin borde.
        // Tinte cyan (acento de luz de la bóveda) en vez de gris neutro,
        // consistente con el resto de acentos interactivos en dark mode.
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.psCyan.withValues(alpha: 0.14),
          labelStyle: AppTypography.caption.copyWith(color: AppColors.psCyan),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: const StadiumBorder(),
          side: BorderSide.none,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkSurfaceHigh,
          contentTextStyle:
              AppTypography.body.copyWith(color: AppColors.ink200),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.psCyan;
            }
            return AppColors.ink500;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.psBlue.withValues(alpha: 0.5);
            }
            return AppColors.darkBorder;
          }),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurfaceElevated,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurfaceElevated,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: AppColors.ink200,
          iconColor: AppColors.ink400,
        ),
      );
}
