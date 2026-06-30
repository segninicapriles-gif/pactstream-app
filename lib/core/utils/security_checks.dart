import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:safe_device/safe_device.dart';

abstract final class SecurityChecks {
  SecurityChecks._();

  static bool _compromised = false;
  static String _reason = '';

  static bool get isCompromised => _compromised;
  static String get reason => _reason;

  static Future<void> run() async {
    if (kIsWeb || kDebugMode) return;

    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      if (jailbroken) {
        _compromised = true;
        _reason = 'Dispositivo con root/jailbreak detectado';
        return;
      }

      final isRealDevice = await SafeDevice.isRealDevice;
      if (!isRealDevice) {
        _compromised = true;
        _reason = 'Emulador detectado';
        return;
      }
    } catch (_) {
      // Detection libraries may fail on some devices — allow gracefully
    }
  }
}
