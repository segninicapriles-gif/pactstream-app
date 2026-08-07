import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/locale_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/supabase/supabase_client.dart';

/// Provider de perfil del usuario actual.
///
/// Llama a `sf_get_my_profile_extended` y devuelve el mapa completo del
/// perfil (nombre, rol, KYC, organización, etc.).
///
/// Para forzar una recarga (p.ej. tras editar nombre o avatar), basta con:
/// ```dart
/// ref.invalidate(myProfileProvider);
/// ```
/// Todos los widgets que estén escuchando con `ref.watch` recibirán el
/// nuevo valor automáticamente.
///
/// Es además el punto donde el perfil del servidor se reconcilia con las
/// preferencias locales: MONEDA desde `country_iso` e IDIOMA desde `locale`.
/// Ambas cosas ocurren aquí y solo aquí porque este es el primer momento del
/// ciclo de vida en el que existen a la vez sesión y fila de `users`.
final myProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final rows =
      await SupabaseConfig.client.rpc('sf_get_my_profile_extended');
  if (rows is List && rows.isNotEmpty) {
    final profile = rows.first as Map<String, dynamic>;

    // Moneda: si el RPC aún no expone `country_iso`, queda null → EUR/España.
    AppFormatters.configureFromCountry(profile['country_iso'] as String?);

    // Idioma: el dispositivo manda sobre el servidor. Si el usuario ya eligió
    // idioma aquí, `adoptServerLocale` respeta esa elección y en su lugar
    // actualiza el perfil remoto. Solo hereda del servidor en instalaciones
    // nuevas. Ver `AppLanguageController.adoptServerLocale`.
    //
    // No se espera (`unawaited` implícito por no usar await): es una
    // reconciliación de preferencias, y bloquear la carga del perfil por ella
    // dejaría al usuario mirando un spinner por un cambio cosmético.
    ref
        .read(appLanguageProvider.notifier)
        .adoptServerLocale(profile['locale'] as String?);

    return profile;
  }
  return null;
});
