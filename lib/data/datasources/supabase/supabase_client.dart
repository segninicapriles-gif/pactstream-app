import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure storage adapter for Supabase session persistence.
///
/// Uses flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android) instead of the default SharedPreferences, so the JWT and
/// refresh token are encrypted at rest.
class SecureLocalStorage extends LocalStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _sessionKey = 'supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    final session = await retrievePersistedSession();
    return session; // Supabase SDK parses the token from the session string
  }

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.containsKey(key: _sessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _sessionKey);
  }

  @override
  Future<String?> retrievePersistedSession() async {
    return _storage.read(key: _sessionKey);
  }
}

/// Cliente Supabase singleton.
///
/// Inicializar en main.dart antes de runApp:
/// ```dart
/// await SupabaseConfig.initialize();
/// ```
abstract final class SupabaseConfig {
  SupabaseConfig._();

  /// Compile-time constants injected via --dart-define-from-file.
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (_supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL no está definido. Usa --dart-define-from-file=dart_defines.env.',
      );
    }
    if (_supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY no está definido. Usa --dart-define-from-file=dart_defines.env.',
      );
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      // SECURITY: Store JWT in encrypted storage instead of SharedPreferences
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureLocalStorage(),
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
