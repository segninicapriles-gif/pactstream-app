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
import 'core/analytics/analytics.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/locale_provider.dart';
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
  // Bundled in assets/google_fonts/: Nunito (display),
  // Hanken Grotesk (UI), JetBrains Mono (datos).
  // Merriweather (PDF) usa PdfGoogleFonts de `printing`, vía red aparte.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Variables de entorno via --dart-define-from-file (no bundled en APK).

  // Símbolos de fecha de cada idioma soportado. `intl` lanza si se pide un
  // DateFormat de un locale que no se inicializó, así que se recorre el enum
  // en vez de listarlos a mano: añadir un idioma no puede olvidarse aquí.
  for (final language in AppLanguage.values) {
    await initializeDateFormatting(language.intlLocale);
  }

  // Preferencia de idioma guardada, ANTES del primer frame para que la app no
  // arranque en español y salte a inglés a mitad de renderizado.
  final storedLanguageCode = await readStoredLanguageCode();
  final bootLanguage = AppLanguageController.resolveInitialLanguage(
    storedCode: storedLanguageCode,
    systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
  );

  // Bloquear orientación a portrait en mobile (en V2 considerar tablets)
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Security: detect rooted/jailbroken devices
  await SecurityChecks.run();
  if (SecurityChecks.isCompromised) {
    // Esta pantalla se pinta ANTES de que exista el árbol de `AppLocalizations`
    // (aborta el arranque), así que su texto no puede venir de los ARB. Es el
    // único texto de la app traducido a mano, y va aquí a propósito: un
    // dispositivo rooteado no debe llegar a cargar Supabase ni el router.
    final blockedMessage = switch (bootLanguage) {
      AppLanguage.es ||
      AppLanguage.es419 =>
        'PactStream no puede ejecutarse en este dispositivo.\n\n'
          '${SecurityChecks.reason}.\n\n'
          'Por seguridad, las aplicaciones financieras no funcionan '
          'en dispositivos comprometidos.',
      AppLanguage.en => 'PactStream can’t run on this device.\n\n'
          '${SecurityChecks.reason}.\n\n'
          'For your security, financial apps don’t run on '
          'compromised devices.',
    };
    runApp(MaterialApp(
      locale: bootLanguage.locale,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              blockedMessage,
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

  // Analytics de producto (PostHog EU) — inerte sin POSTHOG_KEY.
  await Analytics.initialize();

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
      appRunner: () => runApp(_bootstrap(storedLanguageCode)),
    );
  } else {
    runApp(_bootstrap(storedLanguageCode));
  }
}

/// Raíz de la app con la preferencia de idioma ya resuelta desde disco.
///
/// El override es lo que permite que `AppLanguageController.build()` sea
/// síncrono: el trabajo asíncrono (leer SharedPreferences) ya ocurrió en
/// `main()`, así que el provider arranca con el valor definitivo.
Widget _bootstrap(String? storedLanguageCode) {
  return ProviderScope(
    overrides: [
      storedLanguageCodeProvider.overrideWithValue(storedLanguageCode),
    ],
    child: const PactStreamApp(),
  );
}
