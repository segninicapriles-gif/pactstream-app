import 'package:intl/intl.dart';

import '../i18n/app_language.dart';
import 'currency.dart';

/// Formatters siguiendo el glosario de Design Handoff §6.4.
///
/// Importes: BIGINT en la subunidad (céntimos). Mostrar como `42.500 €` (ES) o
/// `$42,500` (US) en listas, con decimales en detalles financieros.
///
/// **Dos ejes independientes**, y esto es deliberado:
///
///   - [activeCurrency] — se deriva del PAÍS del usuario (`country_iso`). Decide
///     el símbolo y la agrupación de miles del dinero.
///   - [activeLanguage] — se deriva del IDIOMA elegido por el usuario. Decide el
///     orden y las palabras de las fechas.
///
/// Un contratista estadounidense con una obra en España ve `Oct 15, 2024` y
/// `42.500 €` a la vez. Fusionar ambos ejes en un solo `locale` haría eso
/// imposible.
///
/// Los textos relativos ("hace 5 min", "5 min ago") viven en una tabla interna
/// aquí en vez de en los ARB. Es la única excepción consciente al "todo texto en
/// ARB", y el motivo es que estos formatters se llaman también desde
/// generación de PDF y desde el pipeline de notificaciones, donde no hay
/// `BuildContext` del que colgar `AppLocalizations`.
abstract final class AppFormatters {
  AppFormatters._();

  static CurrencyInfo _activeCurrency = CurrencyInfo.eur;
  static AppLanguage _activeLanguage = AppLanguage.fallback;

  static CurrencyInfo get activeCurrency => _activeCurrency;
  static AppLanguage get activeLanguage => _activeLanguage;

  /// Fija la moneda activa directamente.
  static void configureCurrency(CurrencyInfo currency) =>
      _activeCurrency = currency;

  /// Fija la moneda activa a partir del país del usuario (ISO 3166-1 alpha-2).
  /// `null`/desconocido → EUR/España.
  static void configureFromCountry(String? countryIso) =>
      _activeCurrency = CurrencyInfo.forCountry(countryIso);

  /// Fija el idioma activo. Lo llama `AppLanguageController` en cada cambio.
  static void configureLanguage(AppLanguage language) {
    _activeLanguage = language;
    _dateCache.clear();
  }

  // NumberFormat/DateFormat son caros de construir; se cachean.
  static final Map<String, NumberFormat> _shortCache = {};
  static final Map<String, NumberFormat> _longCache = {};
  static final Map<String, DateFormat> _dateCache = {};

  static NumberFormat _formatter(CurrencyInfo c, int decimalDigits) {
    final cache = decimalDigits == 0 ? _shortCache : _longCache;
    return cache.putIfAbsent(
      c.code,
      () => NumberFormat.currency(
        locale: c.locale,
        symbol: c.symbol,
        decimalDigits: decimalDigits,
      ),
    );
  }

  static DateFormat _date(String key, DateFormat Function(String) build) =>
      _dateCache.putIfAbsent(key, () => build(_activeLanguage.intlLocale));

  // -------------------------------------------------------------------
  // Dinero
  // -------------------------------------------------------------------

  /// Formato corto sin decimales. Usar en listas, tablas, dashboards.
  ///
  /// Ejemplo (ES): 42500_00 céntimos → "42.500 €"; (US) → "$42,500".
  static String moneyShort(int cents, {CurrencyInfo? currency}) {
    final amount = cents / 100.0;
    return _formatter(currency ?? _activeCurrency, 0).format(amount);
  }

  /// Formato largo con decimales. Usar en cards de detalle financiero,
  /// modales de pago, certificados.
  ///
  /// Ejemplo (ES): 42500_00 céntimos → "42.500,00 €"; (US) → "$42,500.00".
  static String moneyLong(int cents, {CurrencyInfo? currency}) {
    final amount = cents / 100.0;
    return _formatter(currency ?? _activeCurrency, 2).format(amount);
  }

  // -------------------------------------------------------------------
  // Fechas y horas
  // -------------------------------------------------------------------

  /// Hora del día. ES → "14:30" (24 h). US → "2:30 PM" (12 h + meridiano).
  ///
  /// `DateFormat.jm()` resuelve la convención horaria desde el locale en vez de
  /// hardcodear `HH:mm`, que es lo que había antes y que en inglés
  /// norteamericano se lee como un horario militar.
  static String timeOfDay(DateTime when) =>
      _date('jm', (l) => DateFormat.jm(l)).format(when);

  /// Fecha media. ES → "15 oct 2024". US → "Oct 15, 2024".
  static String dateMedium(DateTime when) =>
      _date('yMMMd', (l) => DateFormat.yMMMd(l)).format(when);

  /// Fecha corta numérica. ES → "15/10/2024". US → "10/15/2024".
  ///
  /// El orden día/mes es la trampa clásica: "05/10/2024" son dos días
  /// distintos según el mercado. Nunca construir esta cadena a mano.
  static String dateNumeric(DateTime when) =>
      _date('yMd', (l) => DateFormat.yMd(l)).format(when);

  /// Día y mes sin año, para listas dentro del año en curso.
  /// ES → "15 oct". US → "Oct 15".
  static String dayMonth(DateTime when) =>
      _date('MMMd', (l) => DateFormat.MMMd(l)).format(when);

  /// Formato relativo para timestamps recientes en listas.
  ///
  /// Reglas (Design Handoff §6.4):
  ///   < 1 min  → "ahora" / "just now"
  ///   < 1 h    → "hace X min" / "X min ago"
  ///   hoy      → "Hoy, 14:30" / "Today, 2:30 PM"
  ///   ayer     → "Ayer, 14:30" / "Yesterday, 2:30 PM"
  ///   < año    → "15 oct" / "Oct 15"
  ///   resto    → "15 oct 2024" / "Oct 15, 2024"
  static String timeRelative(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(when);
    final s = _strings;

    if (diff.inSeconds < 60) return s.justNow;
    if (diff.inMinutes < 60) return s.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24 && _isSameDay(when, reference)) {
      return '${s.today}, ${timeOfDay(when)}';
    }
    if (_isSameDay(when, reference.subtract(const Duration(days: 1)))) {
      return '${s.yesterday}, ${timeOfDay(when)}';
    }
    if (when.year == reference.year) return dayMonth(when);
    return dateMedium(when);
  }

  /// Formato detalle de cards.
  /// ES → "15 oct 2024 a las 11:45". US → "Oct 15, 2024 at 11:45 AM".
  static String dateTimeDetail(DateTime when) =>
      '${dateMedium(when)} ${_strings.at} ${timeOfDay(when)}';

  /// ISO 8601 UTC para timestamps forenses, audit log, certificados.
  ///
  /// NO se localiza nunca: es un identificador legal, no texto de interfaz.
  static String dateTimeForensic(DateTime when) =>
      when.toUtc().toIso8601String();

  // -------------------------------------------------------------------
  // Plazos
  // -------------------------------------------------------------------

  /// Countdown del plazo de objeción / resolución. Ejemplo: "47:58:02".
  /// Igual en ambos idiomas: es un cronómetro, no prosa.
  static String countdown(Duration remaining) {
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Formato amigable de plazo.
  /// ES → "9 d, 14 h restantes". US → "9d 14h left".
  static String deadline(DateTime until, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final remaining = until.difference(reference);
    final s = _strings;

    if (remaining.isNegative) return s.deadlinePassed;
    if (remaining.inDays > 0) {
      final hours = remaining.inHours - remaining.inDays * 24;
      return s.daysHoursLeft(remaining.inDays, hours);
    }
    if (remaining.inHours > 0) return s.hoursLeft(remaining.inHours);
    return s.minutesLeft(remaining.inMinutes);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static _RelativeStrings get _strings => switch (_activeLanguage) {
        // es-419 comparte los relativos con el peninsular: "hace 5 min",
        // "Ayer" y "Plazo vencido" son idénticos en toda la hispanofonía. Lo
        // que separa a las dos variantes es el vocabulario de dominio, que
        // vive en los ARB, no aquí.
        AppLanguage.es || AppLanguage.es419 => const _RelativeStringsEs(),
        AppLanguage.en => const _RelativeStringsEn(),
      };
}

/// Contrato de los textos relativos. Al añadir un idioma, el `switch` exhaustivo
/// de `_strings` deja de compilar hasta que existe su implementación — que es
/// exactamente el recordatorio que queremos.
abstract class _RelativeStrings {
  const _RelativeStrings();
  String get justNow;
  String get today;
  String get yesterday;
  String get at;
  String get deadlinePassed;
  String minutesAgo(int minutes);
  String daysHoursLeft(int days, int hours);
  String hoursLeft(int hours);
  String minutesLeft(int minutes);
}

class _RelativeStringsEs extends _RelativeStrings {
  const _RelativeStringsEs();
  @override
  String get justNow => 'ahora';
  @override
  String get today => 'Hoy';
  @override
  String get yesterday => 'Ayer';
  @override
  String get at => 'a las';
  @override
  String get deadlinePassed => 'Plazo vencido';
  @override
  String minutesAgo(int minutes) => 'hace $minutes min';
  @override
  String daysHoursLeft(int days, int hours) => '$days d, $hours h restantes';
  @override
  String hoursLeft(int hours) => '$hours h restantes';
  @override
  String minutesLeft(int minutes) => '$minutes min restantes';
}

class _RelativeStringsEn extends _RelativeStrings {
  const _RelativeStringsEn();
  @override
  String get justNow => 'just now';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  String get at => 'at';
  @override
  String get deadlinePassed => 'Past due';
  @override
  String minutesAgo(int minutes) => '$minutes min ago';
  @override
  String daysHoursLeft(int days, int hours) => '${days}d ${hours}h left';
  @override
  String hoursLeft(int hours) => '${hours}h left';
  @override
  String minutesLeft(int minutes) => '$minutes min left';
}
