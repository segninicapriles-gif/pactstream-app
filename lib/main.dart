import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'data/datasources/supabase/supabase_client.dart';

Future<void> main() async {
  // Eliminar el fragmento /#/ de las URLs en web para que los deep links
  // (invitaciones de org, verify-email) funcionen como rutas normales.
  if (kIsWeb) usePathUrlStrategy();

  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // Inicializar locale español
  await initializeDateFormatting('es_ES');

  // Bloquear orientación a portrait en mobile (en V2 considerar tablets)
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
        options.tracesSampleRate = 1.0; // 100% en pre-MVP, bajar en prod
        options.attachScreenshot = true;
      },
      appRunner: () => runApp(const ProviderScope(child: PactStreamApp())),
    );
  } else {
    runApp(const ProviderScope(child: PactStreamApp()));
  }
}
