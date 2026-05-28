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
            context: context,
            maxWidth: AppBreakpoints.mediumMaxWidth,
            child: child,
          );
        }

        // Desktop / wide tablet: slightly narrower (phone-sim with rail).
        return _centeredChrome(
          context: context,
          maxWidth: AppBreakpoints.expandedMaxWidth,
          child: child,
        );
      },
    );
  }

  /// Shared decoration: gray background, centered card with shadow.
  Widget _centeredChrome({
    required BuildContext context,
    required double maxWidth,
    required Widget child,
  }) {
    final c = context.colors;
    return ColoredBox(
      color: c.scaffold,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.zero,
              boxShadow: const [
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
