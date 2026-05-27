import 'dart:ui';

import 'package:flutter/material.dart';

/// Custom scroll behaviour for PactStream.
///
/// Applies iOS-style bouncing physics on ALL platforms (including web
/// and Android) for a premium, consistent feel.  Also enables mouse-drag
/// scrolling on web/desktop so lists feel native on non-touch devices.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // BouncingScrollPhysics gives the elastic over-scroll that iOS users
    // expect and that feels premium on Android/web too.
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        // Allow mouse + touch + stylus drag for web/desktop support.
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
