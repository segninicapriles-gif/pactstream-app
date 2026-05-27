import 'package:flutter/widgets.dart';

/// Material 3 responsive breakpoints for PactStream.
///
/// ```
///   compact        medium         expanded
///   (phone)       (tablet)       (desktop)
/// ──|──────────|─────────────|─────────────|──
///   0         600           840          1200
/// ```
///
/// Use the static helpers ([isCompact], [isMedium], [isExpanded]) to
/// branch layouts in build methods.  For hot-reload-friendly checks
/// inside `LayoutBuilder`, prefer comparing against the constants
/// directly.
abstract final class AppBreakpoints {
  AppBreakpoints._();

  // ─── widths ───────────────────────────────────────────────────

  /// < 600 dp – phones.
  static const double compact = 600;

  /// 600 – 839 dp – small tablets / large phones in landscape.
  static const double medium = 840;

  /// ≥ 840 dp – large tablets, foldables, desktops.
  static const double expanded = 1200;

  // ─── max-widths for ResponsiveWrapper ─────────────────────────

  /// Content max-width on medium screens (tablet portrait).
  static const double mediumMaxWidth = 600;

  /// Content max-width on expanded screens (desktop / landscape).
  static const double expandedMaxWidth = 560;

  /// Minimum effective width to show NavigationRail instead of
  /// BottomNavigationBar.
  static const double railThreshold = 560;

  // ─── convenience helpers ──────────────────────────────────────

  /// True when the viewport is phone-sized (<600 dp).
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  /// True when the viewport is tablet-sized (600–839 dp).
  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compact && w < medium;
  }

  /// True when the viewport is desktop/wide-tablet-sized (≥840 dp).
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  /// True when there is enough horizontal room for a NavigationRail
  /// inside the constrained wrapper.  Use inside `LayoutBuilder`.
  static bool shouldShowRail(double effectiveWidth) =>
      effectiveWidth >= railThreshold;
}
