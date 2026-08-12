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
  // Rutas legales verificadas con curl contra produccion el 12-ago-2026.
  // Las tres primeras devuelven 200; no inventar sub-rutas /legal/*, que
  // devuelven 404 (fue asi como termsUrl y privacyUrl acabaron rotos).
  static const String legalNoticeUrl = 'https://pactstream.io/legal';
  static const String termsUrl = 'https://pactstream.io/terminos';
  static const String privacyUrl = 'https://pactstream.io/privacidad';

  // 🔴 Sigue sin existir: /legal/escrow devuelve 404 y no hay documento de
  // condiciones de escrow publicado. Hoy no se usa en ninguna pantalla; si
  // se llega a usar, publicar la pagina antes.
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
