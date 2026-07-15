import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Accesibilidad: generar SIEMPRE el árbol de semantics (screen readers,
  // testing). En web, sin esto el árbol solo existe si el usuario activa
  // el lector de pantalla.
  SemanticsBinding.instance.ensureSemantics();

  // SECURITY: Disable runtime font fetching from Google CDN.
  // Fonts must be bundled locally to prevent tracking and MITM risks.
  // Fonts used: Nunito, JetBrains Mono (UI), Merriweather (PDF generation).
  GoogleFonts.config.allowRuntimeFetching = false;

  // Variables de entorno via --dart-define-from-file (no bundled en APK).

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
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  // No puede ser const: .contains() no es expresión constante y dart2js
  // lo trata como error fatal (bloqueaba todo build web).
  final hasValidSentry = sentryDsn != '' && !sentryDsn.contains('xxxxx');
  if (hasValidSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        const sentryEnv = String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');
        options.environment = sentryEnv;
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
