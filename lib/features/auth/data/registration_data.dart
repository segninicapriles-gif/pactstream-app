import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/region_profile.dart';

/// Estado del wizard de registro. Se mantiene en memoria mientras
/// el usuario navega entre los 3 pasos.
class RegistrationData {
  String fullName = '';
  String email = '';

  /// Número NACIONAL, sin prefijo. El E.164 se compone con [region] al vuelo:
  /// guardarlo ya prefijado obligaba a reescribirlo entero cada vez que el
  /// usuario cambia de país a mitad del formulario.
  String phoneNational = '';

  String password = '';

  /// 'promotor' | 'constructor' | 'tecnico'
  String? role;

  // Campos profesionales (varían por rol)
  String organizationName = '';
  String cifOrNif = '';
  String province = '';
  String profession = '';
  String colegio = '';
  String numColegiacion = '';

  /// Idioma de interfaz elegido en el paso 1. Viaja en la metadata del
  /// `signUp()` porque la fila de `users` todavía no existe cuando se elige.
  AppLanguage language = AppLanguage.fallback;

  /// País, que decide moneda, identificación fiscal y prefijo telefónico.
  /// Se siembra desde el idioma y el usuario puede cambiarlo.
  RegionProfile region = RegionProfile.fallback;

  // Consentimientos
  bool acceptedTerms = false;
  bool acceptedPrivacy = false;

  // Versiones aceptadas (en V2 se leen del backend)
  static const String termsVersion = '1.0';
  static const String privacyVersion = '1.0';

  /// Teléfono en E.164, tal y como lo espera Supabase.
  String get phoneE164 => region.toE164(phoneNational);

  /// Validación razonable de email: algo@algo.tld sin espacios.
  static final RegExp _emailRegExp =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  bool get step1Valid =>
      fullName.trim().isNotEmpty &&
      _emailRegExp.hasMatch(email.trim()) &&
      // Longitud REAL del país (9 en España, 10 en EE. UU.). Antes se exigía
      // `phoneE164.length >= 9`, que un "+34600" ya satisfacía porque contaba
      // también los caracteres del prefijo.
      region.isPhoneComplete(phoneNational) &&
      password.length >= 8;

  bool get step2Valid {
    if (role == null) return false;
    if (role == 'tecnico') {
      return colegio.trim().isNotEmpty && numColegiacion.trim().isNotEmpty;
    }
    if (role == 'constructor') {
      return organizationName.trim().isNotEmpty &&
          cifOrNif.trim().isNotEmpty;
    }
    // promotor: solo identificación fiscal
    return cifOrNif.trim().isNotEmpty;
  }

  bool get step3Valid => acceptedTerms && acceptedPrivacy;

  /// Construye el payload para llamar la RPC sf_complete_registration.
  Map<String, dynamic> toRpcArgs() => {
        'p_full_name': fullName.trim(),
        'p_phone_e164': phoneE164,
        'p_primary_role': role,
        'p_organization_name':
            organizationName.trim().isEmpty ? null : organizationName.trim(),
        'p_cif_or_nif': cifOrNif.trim().isEmpty ? null : cifOrNif.trim(),
        'p_province': province.trim().isEmpty ? null : province.trim(),
        'p_profession': profession.trim().isEmpty ? null : profession.trim(),
        'p_colegio': colegio.trim().isEmpty ? null : colegio.trim(),
        'p_num_colegiacion':
            numColegiacion.trim().isEmpty ? null : numColegiacion.trim(),
        'p_terms_version': termsVersion,
        'p_privacy_version': privacyVersion,
        'p_locale': language.code,
        'p_country_iso': region.countryIso,
      };
}
