import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/responsive_wrapper.dart';

class PactStreamApp extends ConsumerWidget {
  const PactStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      scrollBehavior: const AppScrollBehavior(),
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
