/// Constantes globales de PactStream.
abstract final class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'PactStream';
  static const String appTagline = 'Confidence to build';
  static const String appVersion = '0.1.0';

  // URLs externas
  static const String websiteUrl = 'https://pactstream.io';
  // Otras apps del ecosistema (SSO por identidad Google/email).
  static const String costpactUrl = 'https://costpact.io';
  static const String fiscalcoreUrl = 'https://fiscalcore.io';
  static const String supportEmail = 'soporte@pactstream.io';
  static const String privacyEmail = 'privacidad@pactstream.io';
  static const String dpoEmail = 'dpo@pactstream.io';
  // Rutas legales verificadas en produccion el 12-ago-2026: solo existen
  // /legal (Aviso Legal) y /privacidad (Politica de Privacidad). Todo lo
  // que cuelga de /legal/* devuelve 404.
  //
  // 🔴 termsUrl y escrowTermsUrl apuntan a paginas QUE NO EXISTEN. termsUrl
  // se usa en el registro (register_page.dart) tras "Acepto los Terminos y
  // Condiciones": hoy ese enlace da 404 y no hay ningun documento de
  // terminos publicado. No se redirige a /legal porque el Aviso Legal es
  // otro documento distinto y sustituir uno por otro es decision juridica,
  // no tecnica. Se arregla publicando las paginas en pactstream-website.
  static const String termsUrl = 'https://pactstream.io/legal/terminos';
  static const String privacyUrl = 'https://pactstream.io/privacidad';
  static const String escrowTermsUrl = 'https://pactstream.io/legal/escrow';

  // Deep links de auth (deben estar dados de alta en Supabase →
  // Auth → URL Configuration → Redirect URLs).
  static const String resetPasswordDeepLink = 'pactstream://reset-password';
  static const String loginCallbackDeepLink = 'pactstream://callback';

  // Plazos legales (alineados con plantillas legales y máquina de estados)
  /// [DECISIÓN LEGAL D-01] — pendiente de cerrar con asesoría jurídica.
  static const int objectionWindowHours = 48;

  /// [DECISIÓN LEGAL D-02] — pendiente de cerrar con asesoría jurídica.
  static const int disputeResolutionDays = 10;

  // Reglas de negocio MVP (alineadas con spec v2.1)
  static const int minMilestonesPerPact = 1;
  static const int maxMilestonesPerPact = 12;
  static const int minMilestoneAmountCents = 50000; // 500 €
  static const int maxPactAmountCents = 50000000; // 500 K€
  static const int minEvidencesPerMilestone = 3;
  static const int maxEvidencesPerMilestone = 10;

  // Geofencing
  static const double maxObraRadiusMeters = 50.0;

  // Comisión PactStream (en basis points para precisión)
  static const int platformFeeBps = 100; // 1.00%
}
