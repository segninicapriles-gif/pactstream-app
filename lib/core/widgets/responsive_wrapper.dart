import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';

/// Wrapper responsivo para limitar el ancho del contenido en web/desktop.
///
/// En pantallas anchas, centra el contenido dentro de un ConstrainedBox y
/// añade un fondo sutil para diferenciar el canvas del contenido real.
/// En móvil o pantallas estrechas no tiene efecto visual.
///
/// **Breakpoint behaviour:**
/// | Screen width      | Max content width | Layout hint          |
/// |-------------------|-------------------|----------------------|
/// | ≤ 600 dp          | full width        | Phone (no wrapper)   |
/// | 600 – 840 dp      | 600 dp            | Tablet (wider)       |
/// | > 840 dp          | 560 dp            | Desktop (rail + sim) |
///
/// Se aplica desde el `builder` de MaterialApp.router para que todas las
/// rutas hereden la restricción sin modificar cada página.
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Phone: full width, no wrapping.
        if (screenWidth <= AppBreakpoints.compact) {
          return child;
        }

        // Tablet: wider container (room for NavigationRail + content).
        if (screenWidth <= AppBreakpoints.medium) {
          return _centeredChrome(
            maxWidth: AppBreakpoints.mediumMaxWidth,
            child: child,
          );
        }

        // Desktop / wide tablet: slightly narrower (phone-sim with rail).
        return _centeredChrome(
          maxWidth: AppBreakpoints.expandedMaxWidth,
          child: child,
        );
      },
    );
  }

  /// Shared decoration: gray background, centered white card with shadow.
  Widget _centeredChrome({
    required double maxWidth,
    required Widget child,
  }) {
    return ColoredBox(
      color: AppColors.ink100,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 24,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
