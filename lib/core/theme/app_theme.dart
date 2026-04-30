import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Theme principal de PactStream para Material 3.
abstract final class AppTheme {
  AppTheme._();

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
        textTheme: AppTypography.textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.psNavy,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.nunito(
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
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            textStyle: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
            minimumSize: const Size.fromHeight(48),
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
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.ink200,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.psBlue,
          unselectedItemColor: AppColors.ink500,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.ink100,
          labelStyle: AppTypography.caption.copyWith(color: AppColors.ink700),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: const StadiumBorder(),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.ink900,
          contentTextStyle: AppTypography.body.copyWith(color: AppColors.white),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      );

  // Modo oscuro pendiente — V2.
  static ThemeData get dark => light;
}
