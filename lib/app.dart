import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/locale_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/responsive_wrapper.dart';
import 'features/pact/data/evidence_queue.dart';
import 'l10n/gen/app_localizations.dart';

class PactStreamApp extends ConsumerWidget {
  const PactStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);

    // Mantener viva la cola offline de evidencias durante toda la sesión:
    // así drena al recuperar cobertura o al reanudar la app aunque no haya
    // ninguna pantalla de evidencias abierta.
    ref.watch(evidenceQueueProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) =>
          ResponsiveWrapper(child: child ?? const SizedBox.shrink()),
      // Localización.
      //
      // `AppLocalizations.delegate` va PRIMERO: si una clave existe tanto en
      // nuestros ARB como en las de Material, gana la nuestra.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLanguage.supportedLocales,
      // Locale explícito: el idioma lo decide el usuario en el selector, no el
      // sistema. La preferencia del dispositivo solo se consulta la primera vez
      // (ver `AppLanguageController.resolveInitialLanguage`).
      locale: language.locale,
    );
  }
}
