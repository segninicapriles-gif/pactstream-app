import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralised haptic-feedback patterns for PactStream.
///
/// Every user-facing interaction that deserves tactile feedback should call
/// one of these methods rather than using [HapticFeedback] directly.  This
/// keeps the intensity grammar consistent across the whole app and makes it
/// trivial to disable haptics globally (e.g. for accessibility prefs).
///
/// On web platforms haptics are silently no-ops (the channel is not
/// available).  We skip the platform-channel call entirely in debug web
/// builds to avoid harmless error logs.
abstract final class AppHaptics {
  AppHaptics._();

  // ------------------------------------------------------------------
  // Levels — lightest → heaviest
  // ------------------------------------------------------------------

  /// Subtle tick: tab switch, toggle, chip selection.
  static void selection() {
    if (_canVibrate) HapticFeedback.selectionClick();
  }

  /// Light tap: card press, list-item tap, small CTA.
  static void light() {
    if (_canVibrate) HapticFeedback.lightImpact();
  }

  /// Medium press: primary button confirm, bottom-sheet open,
  /// drag handle lift.
  static void medium() {
    if (_canVibrate) HapticFeedback.mediumImpact();
  }

  /// Heavy thud: destructive action confirm, sign/submit, error alert.
  static void heavy() {
    if (_canVibrate) HapticFeedback.heavyImpact();
  }

  /// Success: action completed (payment released, contract signed).
  static void success() {
    if (_canVibrate) HapticFeedback.mediumImpact();
  }

  /// Warning / error: validation fail, network error.
  static void warning() {
    if (_canVibrate) HapticFeedback.heavyImpact();
  }

  // ------------------------------------------------------------------
  // Platform gate
  // ------------------------------------------------------------------

  /// True when the platform supports haptic feedback.
  static bool get _canVibrate => !kIsWeb;
}
