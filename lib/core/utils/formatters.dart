import 'package:intl/intl.dart';

/// Formatters siguiendo el glosario de Design Handoff §6.4.
///
/// Importes: BIGINT en céntimos. Mostrar como `42.500 €` (sin céntimos en
/// listas) o `42.500,00 €` (con céntimos en detalles financieros).
abstract final class AppFormatters {
  AppFormatters._();

  static final NumberFormat _moneyShort = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 0,
  );

  static final NumberFormat _moneyLong = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 2,
  );

  /// Formato corto sin céntimos. Usar en listas, tablas, dashboards.
  ///
  /// Ejemplo: 42500_00 céntimos → "42.500 €"
  static String moneyShort(int cents) {
    final euros = cents / 100.0;
    return _moneyShort.format(euros);
  }

  /// Formato largo con céntimos. Usar en cards de detalle financiero,
  /// modales de pago, certificados.
  ///
  /// Ejemplo: 42500_00 céntimos → "42.500,00 €"
  static String moneyLong(int cents) {
    final euros = cents / 100.0;
    return _moneyLong.format(euros);
  }

  /// Formato relativo para timestamps recientes en listas.
  ///
  /// Reglas (Design Handoff §6.4):
  ///   < 1 min  → "ahora"
  ///   < 1 h    → "hace X min"
  ///   < 24 h   → "hace X h"
  ///   ayer     → "Ayer, HH:mm"
  ///   hoy      → "Hoy, HH:mm"
  ///   < año    → "DD MMM"
  ///   resto    → "DD MMM YYYY"
  static String timeRelative(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(when);

    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24 && _isSameDay(when, reference)) {
      return 'Hoy, ${DateFormat('HH:mm').format(when)}';
    }
    if (_isSameDay(when, reference.subtract(const Duration(days: 1)))) {
      return 'Ayer, ${DateFormat('HH:mm').format(when)}';
    }
    if (when.year == reference.year) {
      return DateFormat('d MMM', 'es_ES').format(when);
    }
    return DateFormat('d MMM yyyy', 'es_ES').format(when);
  }

  /// Formato detalle de cards: "15 oct 2024 a las 11:45".
  static String dateTimeDetail(DateTime when) {
    final date = DateFormat("d MMM yyyy", 'es_ES').format(when);
    final time = DateFormat('HH:mm').format(when);
    return '$date a las $time';
  }

  /// ISO 8601 UTC para timestamps forenses, audit log, certificados.
  static String dateTimeForensic(DateTime when) {
    return when.toUtc().toIso8601String();
  }

  /// Formato del countdown para plazo de objeción / resolución.
  ///
  /// Ejemplo: 47h 58m 02s → "47:58:02"
  static String countdown(Duration remaining) {
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Formato amigable de plazo: "9 días, 14h restantes".
  static String deadline(DateTime until, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final remaining = until.difference(reference);
    if (remaining.isNegative) return 'Plazo vencido';
    if (remaining.inDays > 0) {
      final hours = remaining.inHours - remaining.inDays * 24;
      return '${remaining.inDays} d, $hours h restantes';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours} h restantes';
    }
    return '${remaining.inMinutes} min restantes';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
