import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_wrapper.dart';

class PactStreamApp extends ConsumerWidget {
  const PactStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      // Dark theme pendiente (V2). Al no declarar darkTheme, Flutter
      // siempre usará el tema light, incluso en dispositivos con modo
      // oscuro activo, evitando que se vea un tema oscuro sin diseñar.
      routerConfig: router,
      builder: (context, child) =>
          ResponsiveWrapper(child: child ?? const SizedBox.shrink()),
      // Localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      locale: const Locale('es', 'ES'),
    );
  }
}
