import '../../l10n/gen/app_localizations.dart';
import '../utils/currency.dart';
import 'app_language.dart';

/// Tipo de división administrativa de primer nivel.
///
/// Es lo ÚNICO del perfil de país que hay que traducir de verdad: "provincia",
/// "estado", "departamento" y "región" son palabras comunes con equivalente en
/// inglés. Los documentos fiscales (RIF, RFC, NIT…) no entran aquí porque son
/// nombres propios y no se traducen.
enum AdminAreaKind {
  province,
  state,
  department,
  region,
  district;

  String label(AppLocalizations l10n) => switch (this) {
        AdminAreaKind.province => l10n.adminAreaProvince,
        AdminAreaKind.state => l10n.adminAreaState,
        AdminAreaKind.department => l10n.adminAreaDepartment,
        AdminAreaKind.region => l10n.adminAreaRegion,
        AdminAreaKind.district => l10n.adminAreaDistrict,
      };
}

/// Convenciones administrativas de un país.
///
/// Traducir la interfaz no basta: un formulario en inglés que pide "CIF" con
/// prefijo "+34" está roto aunque cada palabra esté bien traducida. El idioma
/// decide el TEXTO; el país decide QUÉ SE PIDE y CÓMO se valida.
///
/// Por eso [RegionProfile] es independiente de [AppLanguage]: un promotor
/// venezolano que prefiere leer en inglés ve la app en inglés pero se le sigue
/// pidiendo un RIF y un teléfono +58.
///
/// ─── Por qué los nombres de documento van como DATO y no como clave ARB ───
/// RIF, RFC, NIT, CUIT, RUT, EIN son nombres propios: no se traducen. Si cada
/// uno tuviera su clave por idioma harían falta ~110 claves para 11 países.
/// Aquí el documento es un `String` y lo único localizado es el envoltorio:
/// "Identificación fiscal (RIF)" / "Tax ID (RIF)".
///
/// ⚠️ Los organismos profesionales (`licenseBoardHint`) son ejemplos
/// ilustrativos, no listas cerradas. Conviene validarlos con el contacto local
/// de cada mercado antes de lanzar allí.
enum RegionProfile {
  // ── Mercados activos ─────────────────────────────────────────────
  // Estos tres son los que CostPact tiene sembrados en `pais_config`.

  es(
    countryIso: 'ES',
    flagEmoji: '🇪🇸',
    dialCode: '+34',
    phoneHint: '600 000 000',
    nationalPhoneDigits: 9,
    personalTaxId: 'NIF',
    personalTaxIdHint: '12345678X',
    companyTaxId: 'CIF',
    companyTaxIdHint: 'B12345678',
    adminArea: AdminAreaKind.province,
    adminAreaHint: 'Madrid',
    licenseBoardHint: 'COAM Madrid',
    licenseNumberHint: '14582',
  ),

  ve(
    countryIso: 'VE',
    flagEmoji: '🇻🇪',
    dialCode: '+58',
    phoneHint: '412 000 0000',
    nationalPhoneDigits: 10,
    // El RIF identifica tanto a personas (V-) como a empresas (J-); es el
    // mismo documento con distinto prefijo, no dos documentos.
    personalTaxId: 'RIF',
    personalTaxIdHint: 'V-12345678-9',
    companyTaxId: 'RIF',
    companyTaxIdHint: 'J-12345678-9',
    adminArea: AdminAreaKind.state,
    adminAreaHint: 'Miranda',
    licenseBoardHint: 'Colegio de Ingenieros de Venezuela (CIV)',
    licenseNumberHint: '123456',
  ),

  sv(
    countryIso: 'SV',
    flagEmoji: '🇸🇻',
    dialCode: '+503',
    phoneHint: '7000 0000',
    nationalPhoneDigits: 8,
    personalTaxId: 'DUI',
    personalTaxIdHint: '01234567-8',
    companyTaxId: 'NIT',
    companyTaxIdHint: '0614-123456-001-2',
    adminArea: AdminAreaKind.department,
    adminAreaHint: 'San Salvador',
    licenseBoardHint: 'Junta de Vigilancia (JVPIA)',
    licenseNumberHint: '1234',
  ),

  // ── Resto de LATAM del plan de expansión ─────────────────────────

  mx(
    countryIso: 'MX',
    flagEmoji: '🇲🇽',
    dialCode: '+52',
    phoneHint: '55 1234 5678',
    nationalPhoneDigits: 10,
    personalTaxId: 'RFC',
    personalTaxIdHint: 'GOMA800101AB1',
    companyTaxId: 'RFC',
    companyTaxIdHint: 'ABC800101XY2',
    adminArea: AdminAreaKind.state,
    adminAreaHint: 'Jalisco',
    licenseBoardHint: 'Cédula profesional (SEP)',
    licenseNumberHint: '1234567',
  ),

  co(
    countryIso: 'CO',
    flagEmoji: '🇨🇴',
    dialCode: '+57',
    phoneHint: '300 1234567',
    nationalPhoneDigits: 10,
    personalTaxId: 'CC',
    personalTaxIdHint: '1020304050',
    companyTaxId: 'NIT',
    companyTaxIdHint: '900123456-7',
    adminArea: AdminAreaKind.department,
    adminAreaHint: 'Antioquia',
    licenseBoardHint: 'Matrícula profesional (COPNIA)',
    licenseNumberHint: 'AN123-456789',
  ),

  pe(
    countryIso: 'PE',
    flagEmoji: '🇵🇪',
    dialCode: '+51',
    phoneHint: '987 654 321',
    nationalPhoneDigits: 9,
    personalTaxId: 'DNI',
    personalTaxIdHint: '12345678',
    companyTaxId: 'RUC',
    companyTaxIdHint: '20123456789',
    adminArea: AdminAreaKind.department,
    adminAreaHint: 'Lima',
    licenseBoardHint: 'Colegio de Ingenieros del Perú (CIP)',
    licenseNumberHint: '123456',
  ),

  cl(
    countryIso: 'CL',
    flagEmoji: '🇨🇱',
    dialCode: '+56',
    phoneHint: '9 1234 5678',
    nationalPhoneDigits: 9,
    personalTaxId: 'RUT',
    personalTaxIdHint: '12.345.678-9',
    companyTaxId: 'RUT',
    companyTaxIdHint: '76.123.456-7',
    adminArea: AdminAreaKind.region,
    adminAreaHint: 'Metropolitana',
    licenseBoardHint: 'Colegio de Ingenieros de Chile',
    licenseNumberHint: '12345',
  ),

  ar(
    countryIso: 'AR',
    flagEmoji: '🇦🇷',
    dialCode: '+54',
    phoneHint: '11 1234 5678',
    nationalPhoneDigits: 10,
    personalTaxId: 'CUIL',
    personalTaxIdHint: '20-12345678-9',
    companyTaxId: 'CUIT',
    companyTaxIdHint: '30-12345678-9',
    adminArea: AdminAreaKind.province,
    adminAreaHint: 'Buenos Aires',
    licenseBoardHint: 'Consejo Profesional (CPIC)',
    licenseNumberHint: '12345',
  ),

  pa(
    countryIso: 'PA',
    flagEmoji: '🇵🇦',
    dialCode: '+507',
    phoneHint: '6000 0000',
    nationalPhoneDigits: 8,
    personalTaxId: 'Cédula',
    personalTaxIdHint: '8-123-4567',
    companyTaxId: 'RUC',
    companyTaxIdHint: '155123456-2-2017',
    adminArea: AdminAreaKind.province,
    adminAreaHint: 'Panamá',
    licenseBoardHint: 'Junta Técnica (JTIA)',
    licenseNumberHint: '12345',
  ),

  // ── Mercados no hispanohablantes ─────────────────────────────────

  us(
    countryIso: 'US',
    flagEmoji: '🇺🇸',
    dialCode: '+1',
    phoneHint: '(555) 010-0199',
    nationalPhoneDigits: 10,
    personalTaxId: 'SSN / ITIN',
    personalTaxIdHint: '123-45-6789',
    companyTaxId: 'EIN',
    companyTaxIdHint: '12-3456789',
    adminArea: AdminAreaKind.state,
    adminAreaHint: 'California',
    licenseBoardHint: 'California Architects Board',
    licenseNumberHint: 'C-12345',
  ),

  pt(
    countryIso: 'PT',
    flagEmoji: '🇵🇹',
    dialCode: '+351',
    phoneHint: '912 345 678',
    nationalPhoneDigits: 9,
    personalTaxId: 'NIF',
    personalTaxIdHint: '123456789',
    companyTaxId: 'NIPC',
    companyTaxIdHint: '500123456',
    adminArea: AdminAreaKind.district,
    adminAreaHint: 'Lisboa',
    licenseBoardHint: 'Ordem dos Engenheiros',
    licenseNumberHint: '12345',
  );

  const RegionProfile({
    required this.countryIso,
    required this.flagEmoji,
    required this.dialCode,
    required this.phoneHint,
    required this.nationalPhoneDigits,
    required this.personalTaxId,
    required this.personalTaxIdHint,
    required this.companyTaxId,
    required this.companyTaxIdHint,
    required this.adminArea,
    required this.adminAreaHint,
    required this.licenseBoardHint,
    required this.licenseNumberHint,
  });

  /// ISO 3166-1 alpha-2. Es lo que se persiste en `users.country_iso`.
  final String countryIso;

  final String flagEmoji;

  /// Prefijo telefónico internacional, incluido el `+`.
  final String dialCode;

  /// Ejemplo de número NACIONAL (sin prefijo) con el formato del país.
  final String phoneHint;

  /// Dígitos del número nacional para considerarlo completo.
  final int nationalPhoneDigits;

  /// Nombre del documento fiscal de una PERSONA. Nombre propio: no se traduce.
  final String personalTaxId;
  final String personalTaxIdHint;

  /// Nombre del documento fiscal de una EMPRESA. En varios países (VE, MX, CL)
  /// coincide con el de persona; ahí cambia solo el formato del número.
  final String companyTaxId;
  final String companyTaxIdHint;

  final AdminAreaKind adminArea;
  final String adminAreaHint;

  /// Ejemplo de organismo que emite la licencia profesional. Ilustrativo:
  /// pendiente de validar con el contacto local de cada mercado.
  final String licenseBoardHint;
  final String licenseNumberHint;

  static const RegionProfile fallback = RegionProfile.es;

  /// Orden de aparición en el selector: primero los mercados con `pais_config`
  /// sembrado en CostPact, luego el resto de LATAM, luego los demás. Un país
  /// que no se puede usar en las dos apps no debería salir el primero.
  static const List<RegionProfile> pickerOrder = [
    RegionProfile.es,
    RegionProfile.ve,
    RegionProfile.sv,
    RegionProfile.mx,
    RegionProfile.co,
    RegionProfile.pe,
    RegionProfile.cl,
    RegionProfile.ar,
    RegionProfile.pa,
    RegionProfile.us,
    RegionProfile.pt,
  ];

  /// Región por defecto para un idioma recién elegido.
  ///
  /// Es solo una SEMILLA, no una atadura: quien elige inglés arranca con
  /// EE. UU. preseleccionado, pero el selector de país manda sobre esto.
  static RegionProfile seedFor(AppLanguage language) => switch (language) {
        AppLanguage.es => RegionProfile.es,
        // Venezuela es el mercado LATAM con reuniones activas y uno de los
        // tres países que CostPact tiene sembrados en `pais_config`. Sembrar
        // aquí un país sin `pais_config` dejaría al usuario eligiendo algo que
        // luego no puede usar en la otra app del ecosistema.
        AppLanguage.es419 => RegionProfile.ve,
        AppLanguage.en => RegionProfile.us,
      };

  static RegionProfile fromCountry(String? countryIso) {
    if (countryIso == null || countryIso.isEmpty) return fallback;
    final normalized = countryIso.toUpperCase();
    for (final region in RegionProfile.values) {
      if (region.countryIso == normalized) return region;
    }
    return fallback;
  }

  /// Moneda asociada. Delega en la tabla única de `CurrencyInfo` para que no
  /// existan dos fuentes de verdad sobre qué moneda usa un país.
  CurrencyInfo get currency => CurrencyInfo.forCountry(countryIso);

  /// Prefijo + número nacional en E.164, tal y como lo espera Supabase.
  String toE164(String nationalNumber) {
    final digits = nationalNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return '$dialCode$digits';
  }

  /// Quita el prefijo de un E.164 para volver a pintarlo en el campo.
  String nationalPart(String e164) =>
      e164.startsWith(dialCode) ? e164.substring(dialCode.length) : e164;

  bool isPhoneComplete(String nationalNumber) =>
      nationalNumber.replaceAll(RegExp(r'[^0-9]'), '').length >=
      nationalPhoneDigits;

  // -----------------------------------------------------------------
  // Etiquetas: el documento es dato, el envoltorio se localiza.
  // -----------------------------------------------------------------

  String taxIdLabel(AppLocalizations l10n) =>
      l10n.regionTaxIdLabel(personalTaxId);

  String companyTaxIdLabel(AppLocalizations l10n) =>
      l10n.regionCompanyTaxIdLabel(companyTaxId);

  String adminAreaLabel(AppLocalizations l10n) => adminArea.label(l10n);

  String licenseBoardLabel(AppLocalizations l10n) => l10n.regionLicenseBoard;

  String licenseNumberLabel(AppLocalizations l10n) =>
      l10n.regionLicenseNumber;

  /// Nombre del país en el idioma activo.
  String countryName(AppLocalizations l10n) => switch (this) {
        RegionProfile.es => l10n.countryES,
        RegionProfile.ve => l10n.countryVE,
        RegionProfile.sv => l10n.countrySV,
        RegionProfile.mx => l10n.countryMX,
        RegionProfile.co => l10n.countryCO,
        RegionProfile.pe => l10n.countryPE,
        RegionProfile.cl => l10n.countryCL,
        RegionProfile.ar => l10n.countryAR,
        RegionProfile.pa => l10n.countryPA,
        RegionProfile.us => l10n.countryUS,
        RegionProfile.pt => l10n.countryPT,
      };
}
