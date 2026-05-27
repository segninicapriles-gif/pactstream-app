import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Variante de color del logo.
enum PactStreamLogoVariant {
  /// Icono con gradiente + texto en psNavy / ink500 — para fondos claros.
  dark,

  /// Icono con gradiente + texto en blanco / blanco70 — para fondos oscuros.
  light,
}

/// Logo horizontal de PactStream.
///
/// Combina el icono SVG (sólo paths, sin texto) con las tipografías Flutter
/// reales (Nunito via google_fonts) para evitar problemas de renderizado SVG.
///
/// Uso:
/// ```dart
/// PactStreamLogo(height: 52)                        // fondo claro
/// PactStreamLogo(height: 52, variant: .light)       // fondo oscuro
/// ```
class PactStreamLogo extends StatelessWidget {
  const PactStreamLogo({
    super.key,
    this.height = 44,
    this.variant = PactStreamLogoVariant.dark,
  });

  /// Altura total del logo (icono + texto quedan alineados a este valor).
  final double height;
  final PactStreamLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final isLight = variant == PactStreamLogoVariant.light;

    final wordmarkColor = isLight ? Colors.white : const Color(0xFF080D42);
    final taglineColor = isLight
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF767BA3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icono P con gradiente (solo paths — sin texto SVG)
        SvgPicture.asset(
          'assets/images/pactstream_icon.svg',
          height: height,
          fit: BoxFit.contain,
        ),

        SizedBox(width: height * 0.22),

        // Wordmark + tagline en Flutter
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PactStream',
              style: GoogleFonts.nunito(
                fontSize: height * 0.58,
                fontWeight: FontWeight.w700,
                color: wordmarkColor,
                height: 1.05,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'confidence to build',
              style: GoogleFonts.nunito(
                fontSize: height * 0.24,
                fontWeight: FontWeight.w400,
                color: taglineColor,
                height: 1.2,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
