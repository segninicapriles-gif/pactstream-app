import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte excepciones técnicas (Supabase Auth, PostgREST, red) en
/// mensajes claros en español para mostrar al usuario.
///
/// Uso:
///   catch (e) { setState(() => _error = humanizeError(e)); }
///
/// Nunca devuelve jerga técnica: si no reconoce el error, cae en un
/// mensaje genérico. Los detalles siguen disponibles en el objeto
/// original para logging/Sentry.
String humanizeError(Object error) {
  // ── Errores de autenticación (Supabase Auth) ─────────────────────
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Tu email aún no está verificado. Revisa tu bandeja de entrada.';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'Ya existe una cuenta con este email. Prueba a iniciar sesión.';
    }
    if (msg.contains('rate limit') ||
        msg.contains('too many requests') ||
        error.statusCode == '429') {
      return 'Demasiados intentos. Espera unos minutos y vuelve a probarlo.';
    }
    if (msg.contains('password should be at least') ||
        msg.contains('password is too short')) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (msg.contains('user not found')) {
      return 'No existe ninguna cuenta con este email.';
    }
    if (msg.contains('expired')) {
      return 'El enlace ha caducado. Solicita uno nuevo.';
    }
    return 'No se pudo completar la autenticación. Inténtalo de nuevo.';
  }

  // ── Errores de base de datos / RPCs (PostgREST) ──────────────────
  if (error is PostgrestException) {
    // Permisos (RLS) — el usuario no puede hacer esta operación.
    if (error.code == '42501' || error.code == 'PGRST301') {
      return 'No tienes permisos para realizar esta acción.';
    }
    // Las RPCs de negocio (sf_*) lanzan RAISE EXCEPTION con mensajes
    // pensados para el usuario; los mostramos si parecen legibles
    // (frase corta con espacios, sin trazas técnicas).
    final msg = error.message.trim();
    final looksHuman = msg.isNotEmpty &&
        msg.length < 200 &&
        msg.contains(' ') &&
        !msg.toLowerCase().contains('function') &&
        !msg.toLowerCase().contains('schema') &&
        !msg.toLowerCase().contains('column') &&
        !msg.toLowerCase().contains('violates');
    if (looksHuman) return msg;
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  // ── Errores de Storage (subida de archivos) ──────────────────────
  if (error is StorageException) {
    if (error.statusCode == '413') {
      return 'El archivo es demasiado grande.';
    }
    return 'No se pudo subir el archivo. Comprueba tu conexión e inténtalo de nuevo.';
  }

  // ── Errores de red / timeout ─────────────────────────────────────
  if (error is TimeoutException) {
    return 'La operación tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.';
  }
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('clientexception')) {
    return 'Sin conexión. Comprueba tu red e inténtalo de nuevo.';
  }

  // ── Fallback genérico ────────────────────────────────────────────
  return 'Algo salió mal. Inténtalo de nuevo.';
}
