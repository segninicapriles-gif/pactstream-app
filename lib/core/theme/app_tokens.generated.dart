// GENERADO POR design-system/tooling/generate.mjs — NO EDITAR A MANO.
// Fuente única: design-system/tokens.json
// Cambiar un valor allí y ejecutar: node design-system/tooling/generate.mjs
// El verificador (tooling/verify.mjs) falla si este fichero se toca a mano.
// Superficie: pactstream  ·  Marca: pactstream

import 'package:flutter/material.dart';

/// Tokens generados del Sistema ARCO. Fuente: design-system/tokens.json
class ArcoTokens {
  ArcoTokens._();

  // Marca — canon §8
  static const Color brandPrimary = Color(0xFF0121DC);
  static const Color brandDeep = Color(0xFF080D42);
  static const Color brandLight = Color(0xFFA9F3FF);
  static const Color brandHover = Color(0xFF011DD8);

  // Tinta — derivada del profundo de la marca a luminancia fija
  static const Color ink900 = Color(0xFF12142D);
  static const Color ink800 = Color(0xFF171A36);
  static const Color ink700 = Color(0xFF2D3152);
  static const Color ink600 = Color(0xFF4F5480);
  static const Color ink500 = Color(0xFF787C9D);
  static const Color ink400 = Color(0xFF878AA5);
  static const Color ink300 = Color(0xFFD2D3E0);
  static const Color ink200 = Color(0xFFE8E9F0);
  static const Color ink100 = Color(0xFFF3F4F8);
  static const Color ink50 = Color(0xFFFAFAFD);

  // Neutrales "Porcelana" — canon §4
  static const Color canvas = Color(0xFFF6F6F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEFEFEA);

  // Semánticos — par fill+ink. NUNCA usar fill como color de texto.
  static const Color successFill = Color(0xFF00C389);
  static const Color successInk = Color(0xFF00795C);
  static const Color warningFill = Color(0xFFFFB020);
  static const Color warningInk = Color(0xFFB45309);
  static const Color errorFill = Color(0xFFFF4D6D);
  static const Color errorInk = Color(0xFFC1223C);
  static const Color infoFill = Color(0xFF5EAFFF);
  static const Color infoInk = Color(0xFF0068CE);

  // Radios — canon §5
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;
  static const double radiusPill = 999.0;

  // Espaciado — sistema 4pt
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;
  static const double spaceXxl = 32.0;
  static const double spaceXxxl = 48.0;
  static const double spaceHuge = 64.0;
  static const double spaceMassive = 96.0;

  // Motion — canon §7
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionBase = Duration(milliseconds: 240);
  static const Duration motionEmphasis = Duration(milliseconds: 420);
  static const Duration motionStagger = Duration(milliseconds: 60);

  // Lockup — geometría del logo
  static const double lockupNameRatio = 0.556;
  static const double lockupTaglineRatio = 0.25;
  static const double lockupGapRatio = 0.22;
  static const double lockupStackGapRatio = 0.06;
  static const double lockupSizeSidebar = 24.0;
  static const double lockupSizeSm = 34.0;
  static const double lockupSizeMd = 36.0;
  static const double lockupSizeLg = 44.0;
  static const double iconAspect = 0.82681;
}
