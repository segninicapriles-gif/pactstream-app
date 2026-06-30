import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/utils/security_checks.dart';
import 'data/datasources/supabase/supabase_client.dart';

Future<void> main() async {
  // Eliminar el fragmento /#/ de las URLs en web para que los deep links
  // (invitaciones de org, verify-email) funcionen como rutas normales.
  if (kIsWeb) usePathUrlStrategy();

  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  // SECURITY: .env is bundled as a Flutter asset for convenience during
  // pre-MVP. It must contain ONLY public keys (Supabase anon key) and
  // empty placeholders — never service-role keys or private secrets.
  // For production, migrate to --dart-define or --dart-define-from-file.
  await dotenv.load(fileName: '.env');

  // Inicializar locale español
  await initializeDateFormatting('es_ES');

  // Bloquear orientación a portrait en mobile (en V2 considerar tablets)
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Security: detect rooted/jailbroken devices
  await SecurityChecks.run();
  if (SecurityChecks.isCompromised) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'PactStream no puede ejecutarse en este dispositivo.\n\n'
              '${SecurityChecks.reason}.\n\n'
              'Por seguridad, las aplicaciones financieras no funcionan '
              'en dispositivos comprometidos.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // Inicializar Supabase
  await SupabaseConfig.initialize();

  // Inicializar Sentry para captura de errores (solo con DSN real)
  final sentryDsn = dotenv.env['SENTRY_DSN'];
  final hasValidSentry = sentryDsn != null &&
      sentryDsn.isNotEmpty &&
      !sentryDsn.contains('xxxxx');
  if (hasValidSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = dotenv.env['SENTRY_ENVIRONMENT'] ?? 'development';
        // SECURITY: Disable PII collection — Sentry must not capture
        // user IP addresses, cookies, or authorization headers.
        options.sendDefaultPii = false;
        // SECURITY: Disable screenshot capture to avoid leaking
        // sensitive on-screen data (KYC documents, contracts, etc.).
        options.attachScreenshot = false;
        // SECURITY: Reduce trace sampling — 100% is excessive and
        // increases the surface for data exposure. 20% is sufficient
        // for pre-MVP error monitoring.
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(const ProviderScope(child: PactStreamApp())),
    );
  } else {
    runApp(const ProviderScope(child: PactStreamApp()));
  }
}
