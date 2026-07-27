import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/supabase/supabase_client.dart';
import '../utils/formatters.dart';
import 'app_language.dart';

/// Clave de SharedPreferences donde vive la preferencia de idioma del
/// dispositivo. Es la fuente que se lee ANTES de `runApp()`.
const String kLocalePrefsKey = 'app_locale';

/// Idioma leído de disco en `main()`, inyectado por override en `ProviderScope`.
///
/// Se resuelve antes del primer frame a propósito: si se resolviera dentro de un
/// `FutureProvider`, la app pintaría un frame en español y luego saltaría a
/// inglés — un parpadeo visible en cada arranque en frío.
final storedLanguageCodeProvider = Provider<String?>(
  (ref) => throw UnimplementedError(
    'storedLanguageCodeProvider debe sobreescribirse en main() con el valor '
    'leído de SharedPreferences.',
  ),
);

/// Idioma activo de la app. `MaterialApp` observa este provider.
final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
  AppLanguageController.new,
);

/// Azúcar para widgets que solo necesitan el [Locale].
final appLocaleProvider = Provider<Locale>(
  (ref) => ref.watch(appLanguageProvider).locale,
);

class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final stored = ref.watch(storedLanguageCodeProvider);
    final language = resolveInitialLanguage(
      storedCode: stored,
      systemLocales: PlatformDispatcher.instance.locales,
    );
    AppFormatters.configureLanguage(language);
    return language;
  }

  /// Precedencia de resolución del idioma en el arranque.
  ///
  /// DECISIÓN DE PRODUCTO — comportamiento actual: **la elección explícita del
  /// usuario gana siempre**, y solo si nunca eligió se mira el idioma del
  /// dispositivo; si el dispositivo no está en un idioma soportado, español.
  ///
  /// El perfil del servidor (`users.locale`) NO entra aquí a propósito: en el
  /// arranque todavía no se ha cargado la sesión. Se reconcilia después, en
  /// [adoptServerLocale], y con la regla "el dispositivo manda" (ver allí).
  ///
  /// Es `static` y sin dependencias de Riverpod por dos motivos: es testeable
  /// directo, y `main()` la reutiliza para saber en qué idioma pintar la
  /// pantalla de dispositivo comprometido, que aborta antes de que exista
  /// `ProviderScope`.
  static AppLanguage resolveInitialLanguage({
    required String? storedCode,
    required List<Locale> systemLocales,
  }) {
    // 1. Elección explícita previa del usuario.
    final stored = AppLanguage.fromCode(storedCode);
    if (stored != null) return stored;

    // 2. Primer idioma del dispositivo que sepamos hablar. Se recorre la lista
    //    entera (no solo `locales.first`) porque en iOS y Android el usuario
    //    puede tener varios idiomas preferidos ordenados.
    for (final locale in systemLocales) {
      final match = AppLanguage.fromLocale(locale);
      if (match != null) return match;
    }

    // 3. Mercado principal.
    return AppLanguage.fallback;
  }

  /// Cambia el idioma por acción explícita del usuario (selector de idioma).
  ///
  /// Persiste en local SIEMPRE y en el servidor solo si hay sesión: durante el
  /// wizard de registro todavía no existe la fila de `users`, así que el idioma
  /// elegido en el paso 1 viaja en la metadata del `signUp()` y el trigger de
  /// alta lo escribe. Ver `20260727000001_user_locale.sql`.
  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    state = language;
    AppFormatters.configureLanguage(language);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocalePrefsKey, language.code);

    await _pushToServer(language);
  }

  /// Reconcilia con el idioma guardado en el perfil del servidor al cargar la
  /// sesión.
  ///
  /// Regla: **el dispositivo manda sobre el servidor**. Si el usuario ya eligió
  /// idioma en ESTE dispositivo, esa elección se respeta y en su lugar se
  /// empuja al servidor. El servidor solo decide cuando el dispositivo no tiene
  /// preferencia (instalación nueva, login en un móvil recién estrenado), que es
  /// justo el caso en el que heredar del perfil aporta algo.
  Future<void> adoptServerLocale(String? serverCode) async {
    final prefs = await SharedPreferences.getInstance();
    final hasLocalChoice = prefs.getString(kLocalePrefsKey) != null;

    if (hasLocalChoice) {
      // El dispositivo ya tiene voto. Alinea el servidor si difiere.
      if (AppLanguage.fromCode(serverCode) != state) {
        await _pushToServer(state);
      }
      return;
    }

    final serverLanguage = AppLanguage.fromCode(serverCode);
    if (serverLanguage == null) {
      // Perfil sin idioma (usuario anterior a esta versión): sube el actual.
      await _pushToServer(state);
      return;
    }

    if (serverLanguage != state) {
      state = serverLanguage;
      AppFormatters.configureLanguage(serverLanguage);
    }
    await prefs.setString(kLocalePrefsKey, serverLanguage.code);
  }

  Future<void> _pushToServer(AppLanguage language) async {
    if (SupabaseConfig.client.auth.currentUser == null) return;
    try {
      await SupabaseConfig.client.rpc(
        'sf_set_my_locale',
        params: {'p_locale': language.code},
      );
    } catch (_) {
      // La preferencia de idioma no es crítica: si el RPC falla, la app se
      // queda en el idioma correcto localmente y reintenta en el próximo
      // cambio. Nunca se bloquea al usuario por esto.
    }
  }
}

/// Lee la preferencia de idioma de disco. Se llama desde `main()`.
Future<String?> readStoredLanguageCode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kLocalePrefsKey);
  } catch (_) {
    return null;
  }
}
