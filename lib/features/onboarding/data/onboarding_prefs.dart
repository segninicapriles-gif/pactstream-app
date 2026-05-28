import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingCompleteKey = 'pactstream_onboarding_complete';

/// Whether the user has completed the welcome onboarding flow.
///
/// Reads SharedPreferences synchronously after first load and exposes
/// a simple boolean.  Call `complete()` once the user finishes or
/// skips the onboarding.
final onboardingCompleteProvider =
    StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) => OnboardingNotifier(),
);

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(true) {
    // Default to true (skip onboarding) until we know otherwise.
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kOnboardingCompleteKey) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
  }

  /// Reset for testing — shows onboarding again.
  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingCompleteKey);
  }
}
