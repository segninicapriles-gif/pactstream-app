import 'dart:ui' show Locale;

/// Idiomas soportados por PactStream.
///
/// El idioma va **desacoplado del país**: `country_iso` resuelve la MONEDA
/// (ver `core/utils/currency.dart`) y este enum resuelve el TEXTO. Un
/// contratista estadounidense que ejecuta una obra en España quiere la app en
/// inglés pero los importes en euros; si idioma y moneda comparten variable eso
/// es imposible de expresar.
///
/// Al añadir un idioma nuevo hay que tocar cuatro sitios y solo cuatro:
///   1. Un valor más en este enum.
///   2. Un `lib/l10n/app_<code>.arb`.
///   3. Una rama en `_RelativeStrings` de `core/utils/formatters.dart`
///      (el `switch` exhaustivo deja de compilar hasta que existe).
///   4. El CHECK de `users.locale` en Supabase.
enum AppLanguage {
  /// Español de España — idioma original de la app y plantilla ARB.
  es(
    code: 'es',
    locale: Locale('es', 'ES'),
    nativeName: 'Español (España)',
    englishName: 'Spanish (Spain)',
    intlLocale: 'es_ES',
    flagEmoji: '🇪🇸',
  ),

  /// Español latinoamericano. `419` es el código UN M49 de "Latinoamérica y
  /// Caribe": no es un país, es la forma estándar de decir "español de LATAM"
  /// sin casarse con uno concreto.
  ///
  /// Existe porque la app se escribió en español peninsular y el vocabulario
  /// no viaja: *cotización* en vez de *presupuesto* para la oferta al cliente,
  /// *remodelación* en vez de *reforma*, *celular* en vez de *móvil*.
  es419(
    code: 'es-419',
    locale: Locale('es', '419'),
    nativeName: 'Español (Latinoamérica)',
    englishName: 'Spanish (Latin America)',
    // `intl` no trae símbolos de fecha para `es_419`; se usan los de México,
    // que son representativos de la región y estructuralmente idénticos a los
    // de España. La diferencia entre es-ES y es-419 está en el VOCABULARIO de
    // la app, no en cómo se escribe una fecha.
    intlLocale: 'es_MX',
    flagEmoji: '🌎',
  ),

  /// Inglés norteamericano — fechas MM/DD/YYYY, terminología de construcción
  /// estadounidense (owner / general contractor / progress billing).
  en(
    code: 'en',
    locale: Locale('en', 'US'),
    nativeName: 'English (US)',
    englishName: 'English (US)',
    intlLocale: 'en_US',
    flagEmoji: '🇺🇸',
  );

  const AppLanguage({
    required this.code,
    required this.locale,
    required this.nativeName,
    required this.englishName,
    required this.intlLocale,
    required this.flagEmoji,
  });

  /// Lo que se persiste en `users.locale` y en SharedPreferences.
  ///
  /// `es` sigue siendo `es` a propósito: las filas creadas antes de que
  /// existiera es-419 no hay que migrarlas y siguen significando lo mismo.
  final String code;

  /// Locale de Flutter para `MaterialApp.locale`.
  final Locale locale;

  /// Nombre en su propio idioma. Un selector de idioma SIEMPRE se etiqueta en
  /// el idioma de destino: quien no entiende la interfaz actual necesita
  /// reconocer "English", no "Inglés".
  final String nativeName;

  /// Nombre en inglés, para logs y paneles internos.
  final String englishName;

  /// Identificador para `intl` (`DateFormat`, `NumberFormat`).
  final String intlLocale;

  final String flagEmoji;

  /// Idioma por defecto cuando no hay preferencia guardada ni coincidencia con
  /// el dispositivo. España sigue siendo el mercado principal.
  static const AppLanguage fallback = AppLanguage.es;

  /// Locales que se declaran en `MaterialApp.supportedLocales`.
  static List<Locale> get supportedLocales =>
      AppLanguage.values.map((l) => l.locale).toList(growable: false);

  /// Países hispanohablantes de América. Un dispositivo en `es-VE` o `es-MX`
  /// debe arrancar en es-419, no en español peninsular.
  static const Set<String> _latamCountries = {
    'AR', 'BO', 'CL', 'CO', 'CR', 'CU', 'DO', 'EC', 'GT', 'HN',
    'MX', 'NI', 'PA', 'PE', 'PR', 'PY', 'SV', 'UY', 'VE', '419',
  };

  /// Resuelve desde un código persistido.
  ///
  /// Acepta `'es'`, `'en'`, `'es-419'`, `'es_419'`, y también códigos de país
  /// concretos como `'es-VE'` o `'es-MX'`, que caen en es-419. Eso último
  /// importa porque `Accept-Language` y el locale del sistema traen el país
  /// real del dispositivo, no la macro-región.
  ///
  /// Devuelve `null` si no hay match, para que quien llama decida el fallback.
  static AppLanguage? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final parts = code.replaceAll('_', '-').split('-');
    final language = parts.first.toLowerCase();
    final region = parts.length > 1 ? parts[1].toUpperCase() : null;

    if (language == 'en') return AppLanguage.en;
    if (language != 'es') return null;

    // Sin región → español peninsular, que es lo que significaba `es` antes de
    // que existiera es-419. No reinterpretar datos ya guardados.
    if (region == null) return AppLanguage.es;
    if (region == 'ES') return AppLanguage.es;
    return _latamCountries.contains(region)
        ? AppLanguage.es419
        : AppLanguage.es;
  }

  /// Resuelve desde un [Locale] del sistema, conservando el país para poder
  /// distinguir `es-ES` de `es-CO`.
  static AppLanguage? fromLocale(Locale? locale) {
    if (locale == null) return null;
    final country = locale.countryCode;
    return fromCode(
      country == null || country.isEmpty
          ? locale.languageCode
          : '${locale.languageCode}-$country',
    );
  }
}
