/// Resolución de moneda por país — ecosistema PactStream.
///
/// PactStream nació con el importe formateado como `42.500 €` fijo
/// (`AppFormatters`, locale `es_ES`, símbolo `€`). CostPact ya es multi-moneda
/// (deriva moneda/locale del país de la empresa). Para que un usuario que cruza
/// de una app a otra vea SU moneda —no siempre €— la moneda se resuelve aquí a
/// partir del `country_iso` (mismo criterio: el país manda).
///
/// **Esta tabla debe cuadrar con `pais_config` de CostPact.** Es el mismo
/// usuario cruzando de una app a otra: si aquí Venezuela fuera VES y allí USD,
/// el mismo presupuesto importado cambiaría de moneda al pasar de app.
///
/// Los importes se siguen guardando como enteros en la subunidad (céntimos);
/// esto solo afecta a cómo se PRESENTAN.
class CurrencyInfo {
  final String code; // ISO 4217: 'EUR', 'MXN', 'PEN'…
  final String locale; // separadores de miles/decimales: 'es_ES', 'es_MX'…
  final String symbol; // '€', '$', 'S/'

  const CurrencyInfo({
    required this.code,
    required this.locale,
    required this.symbol,
  });

  /// Euro / España — el valor por defecto histórico y el mercado actual.
  static const eur = CurrencyInfo(code: 'EUR', locale: 'es_ES', symbol: '€');

  /// Tabla país (ISO 3166-1 alpha-2) → moneda. Cubre España, EE. UU. y los
  /// mercados LATAM del plan de expansión.
  /// Cualquier país no listado cae a EUR/España.
  static const Map<String, CurrencyInfo> _byCountry = {
    'ES': eur,
    'PT': CurrencyInfo(code: 'EUR', locale: 'pt_PT', symbol: '€'),
    'US': CurrencyInfo(code: 'USD', locale: 'en_US', symbol: r'$'),

    // ── Economías dolarizadas ────────────────────────────────────────
    // Venezuela: la moneda OPERATIVA es el dólar y el bolívar es la
    // secundaria — así está en `pais_config` de CostPact y así se factura
    // realmente allí. Poner VES aquí rompería la paridad entre las dos apps
    // y haría que un presupuesto importado cambiase de moneda.
    'VE': CurrencyInfo(code: 'USD', locale: 'es_VE', symbol: r'$'),
    // El Salvador está dolarizado desde 2001; no tiene moneda propia.
    'SV': CurrencyInfo(code: 'USD', locale: 'es_SV', symbol: r'$'),
    // Panamá: el balboa está anclado 1:1 al dólar y el dólar circula como
    // moneda de curso legal. Se factura en USD.
    'PA': CurrencyInfo(code: 'USD', locale: 'es_PA', symbol: r'$'),

    // ── Monedas propias ──────────────────────────────────────────────
    'MX': CurrencyInfo(code: 'MXN', locale: 'es_MX', symbol: r'$'),
    'CO': CurrencyInfo(code: 'COP', locale: 'es_CO', symbol: r'$'),
    'PE': CurrencyInfo(code: 'PEN', locale: 'es_PE', symbol: 'S/'),
    'CL': CurrencyInfo(code: 'CLP', locale: 'es_CL', symbol: r'$'),
    'AR': CurrencyInfo(code: 'ARS', locale: 'es_AR', symbol: r'$'),
  };

  /// Resuelve la moneda para un código de país. `null`/desconocido → EUR/España.
  static CurrencyInfo forCountry(String? countryIso) {
    if (countryIso == null || countryIso.isEmpty) return eur;
    return _byCountry[countryIso.toUpperCase()] ?? eur;
  }

  @override
  bool operator ==(Object other) =>
      other is CurrencyInfo &&
      other.code == code &&
      other.locale == locale &&
      other.symbol == symbol;

  @override
  int get hashCode => Object.hash(code, locale, symbol);
}
