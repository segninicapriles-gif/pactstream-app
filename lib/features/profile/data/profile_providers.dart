import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final myProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final rows =
      await SupabaseConfig.client.rpc('sf_get_my_profile_extended');
  if (rows is List && rows.isNotEmpty) {
    final profile = rows.first as Map<String, dynamic>;
    // Configura la moneda activa de la sesión desde el país del usuario.
    // Si el RPC aún no expone `country_iso`, queda null → EUR/España (sin
    // regresión). Punto único: aquí es donde el perfil se carga por primera vez.
    AppFormatters.configureFromCountry(profile['country_iso'] as String?);
    return profile;
  }
  return null;
});
