import 'package:posthog_flutter/posthog_flutter.dart';

/// Analytics de producto (PostHog, EU Cloud).
///
/// **Inerte sin key:** igual que el guard de Sentry en `main.dart`, si
/// `POSTHOG_KEY` no está definido (vía `--dart-define`/`--dart-define-from-file`)
/// no se inicializa nada y todas las llamadas son no-ops. Así, instrumentar
/// eventos es siempre seguro aunque no haya proyecto de PostHog configurado.
///
/// Región de datos: EU (`eu.i.posthog.com`) por defecto — RGPD-friendly.
abstract final class Analytics {
  Analytics._();

  static bool _on = false;
  static bool get isOn => _on;

  static Future<void> initialize() async {
    const key = String.fromEnvironment('POSTHOG_KEY');
    // No puede ser const: `.contains` no es expresión constante (mismo motivo
    // que el guard de Sentry) y dart2js lo trataría como error fatal.
    final valid = key != '' && !key.contains('xxxxx');
    if (!valid) return;

    const host = String.fromEnvironment(
      'POSTHOG_HOST',
      defaultValue: 'https://eu.i.posthog.com',
    );

    final config = PostHogConfig(key)
      ..host = host
      ..captureApplicationLifecycleEvents = true;
    await Posthog().setup(config);
    _on = true;
  }

  static Future<void> capture(String event, [Map<String, Object>? props]) async {
    if (!_on) return;
    await Posthog().capture(eventName: event, properties: props);
  }

  /// Asocia los eventos siguientes a un usuario (tras autenticar).
  static Future<void> identify(String userId) async {
    if (!_on) return;
    await Posthog().identify(userId: userId);
  }

  /// Corta la asociación (al cerrar sesión).
  static Future<void> reset() async {
    if (!_on) return;
    await Posthog().reset();
  }
}
