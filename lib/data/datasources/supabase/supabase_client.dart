import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente Supabase singleton.
///
/// Inicializar en main.dart antes de runApp:
/// ```dart
/// await SupabaseConfig.initialize();
/// ```
abstract final class SupabaseConfig {
  SupabaseConfig._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw StateError(
        'SUPABASE_URL no está definido. Copia .env.example a .env y rellena.',
      );
    }
    if (anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY no está definido. Copia .env.example a .env y rellena.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // Persistencia local del JWT
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      // Realtime con backoff sensato
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
      debug: false,
    );
  }

  /// Helper: usuario autenticado actual o null.
  static User? get currentUser => client.auth.currentUser;

  /// Helper: stream de cambios de auth.
  static Stream<AuthState> get authStream => client.auth.onAuthStateChange;
}
