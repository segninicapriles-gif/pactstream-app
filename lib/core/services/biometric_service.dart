import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Gate biométrico para acciones de alto valor (pagos, firmas, movimientos de dinero).
///
/// En debug se salta la verificación para no bloquear el desarrollo.
///
/// SEGURIDAD (fail-closed): si el dispositivo SÍ soporta biometría y la
/// comprobación falla o lanza excepción, se DENIEGA el acceso (return false).
/// Nunca se deja pasar por un error en el camino sensible.
/// Para pagos/firmas usar [authenticateStrict], que además deniega si el
/// dispositivo no tiene biometría configurada.
abstract final class BiometricService {
  static final _auth = LocalAuthentication();

  /// Devuelve `true` solo si el usuario se autenticó correctamente.
  ///
  /// - En debug se salta la verificación (return true).
  /// - Si el dispositivo NO soporta biometría: por defecto deja pasar para no
  ///   bloquear a usuarios legítimos sin biometría configurada. Pasa
  ///   [required] = true (o usa [authenticateStrict]) para denegar también en
  ///   ese caso en acciones de alto valor.
  /// - SEGURIDAD (fail-closed): si el dispositivo soporta biometría pero la
  ///   comprobación falla o lanza excepción, devuelve `false` (denegar).
  static Future<bool> authenticate({
    String reason = 'Confirma tu identidad para continuar',
    bool required = false,
  }) async {
    if (kDebugMode) return true; // Skip in debug

    try {
      final canCheck =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        // SEGURIDAD: sin biometría en el dispositivo. Fail-closed solo cuando
        // la acción lo exige ([required]); si no, se permite para no bloquear
        // a usuarios legítimos sin biometría configurada.
        return !required;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
        ),
      );
    } catch (_) {
      // SEGURIDAD: fail-closed. El dispositivo soporta biometría (o falló al
      // comprobarlo), así que un error NO puede traducirse en acceso concedido.
      return false;
    }
  }

  /// Variante estricta para pagos, firmas y movimientos de dinero.
  ///
  /// SEGURIDAD: nunca falla-abierto. Deniega ante cualquier error y también
  /// cuando el dispositivo no tiene biometría/credencial configurada.
  static Future<bool> authenticateStrict({
    String reason = 'Confirma tu identidad para continuar',
  }) =>
      authenticate(reason: reason, required: true);
}
