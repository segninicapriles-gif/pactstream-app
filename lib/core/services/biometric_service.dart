import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Gate biométrico para acciones de alto valor (pagos, firmas, movimientos de dinero).
///
/// En debug se salta la verificación para no bloquear el desarrollo.
/// Si el dispositivo no soporta biometría, deja pasar (no bloquea al usuario).
abstract final class BiometricService {
  static final _auth = LocalAuthentication();

  /// Devuelve `true` si el usuario se autenticó correctamente (o el dispositivo
  /// no soporta biometría / estamos en debug).
  static Future<bool> authenticate({
    String reason = 'Confirma tu identidad para continuar',
  }) async {
    if (kDebugMode) return true; // Skip in debug

    try {
      final canCheck =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return true; // Device doesn't support biometrics, allow through

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
        ),
      );
    } catch (_) {
      return true; // On error, don't block the user
    }
  }
}
