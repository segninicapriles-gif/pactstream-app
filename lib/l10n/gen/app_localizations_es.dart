// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'PactStream';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonNext => 'Siguiente →';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSaveChanges => 'Guardar cambios';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonAccept => 'Aceptar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String get commonOr => 'o';

  @override
  String get commonRequired => 'Obligatorio';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get commonNotAvailable => '—';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageSelectorTitle => 'Elige tu idioma';

  @override
  String get languageSelectorSubtitle =>
      'Puedes cambiarlo cuando quieras desde tu perfil.';

  @override
  String get languageChanged => 'Idioma actualizado';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginSubtitle => 'Accede a tu cuenta para gestionar tus obras';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginEmailHint => 'tu@email.com';

  @override
  String get loginEmailEmpty => 'Introduce tu email';

  @override
  String get loginEmailInvalid => 'Ese email no parece válido';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get loginPasswordEmpty => 'Introduce tu contraseña';

  @override
  String get loginPasswordTooShort => 'Mínimo 8 caracteres';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginCreateAccount => 'Crear cuenta nueva';

  @override
  String get loginContinueWithGoogle => 'Continuar con Google';

  @override
  String get loginShowPassword => 'Mostrar contraseña';

  @override
  String get loginHidePassword => 'Ocultar contraseña';

  @override
  String get resetTitle => 'Recuperar contraseña';

  @override
  String get resetBody =>
      'Te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get resetSend => 'Enviar enlace';

  @override
  String get resetSent =>
      'Revisa tu correo — te hemos enviado el enlace de recuperación.';

  @override
  String get resetFailed => 'No se pudo enviar el correo. Inténtalo de nuevo.';

  @override
  String registerStepIndicator(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get registerCreateAccountCta => 'Crear mi cuenta';

  @override
  String get registerStep1Title => 'Crea tu cuenta';

  @override
  String get registerStep1Subtitle => 'Datos personales';

  @override
  String get registerFullNameLabel => 'Nombre completo';

  @override
  String get registerFullNameHint => 'Ej: Juan Pérez';

  @override
  String get registerEmailLockedHelper =>
      'Tu equipo te invitó con este email; no se puede cambiar.';

  @override
  String get registerPhoneLabel => 'Teléfono';

  @override
  String get registerLegalPreview =>
      'Al continuar verás los términos legales en el último paso. No creamos la cuenta hasta que los aceptes.';

  @override
  String get registerStep2Title => 'Configura tu perfil';

  @override
  String get registerStep2Subtitle => 'Selecciona tu rol en PactStream';

  @override
  String get registerProfessionalDataTitle => 'Datos profesionales';

  @override
  String get roleOwnerTitle => 'Promotor';

  @override
  String get roleOwnerSubtitle => 'Quiero financiar una obra con seguridad';

  @override
  String get roleContractorTitle => 'Constructor';

  @override
  String get roleContractorSubtitle =>
      'Ejecuto obras y quiero cobrar garantizado';

  @override
  String get roleArchitectTitle => 'Técnico';

  @override
  String get roleArchitectSubtitle => 'Dirijo obras y valido hitos';

  @override
  String get registerCompanyNameLabel => 'Nombre de empresa';

  @override
  String get registerCompanyNameHint => 'Ej: Construcciones Gómez S.L.';

  @override
  String get registerStep3Title => 'Verifica tus datos';

  @override
  String get registerStep3Subtitle =>
      'Revisa la información antes de crear tu cuenta';

  @override
  String get registerSummaryTitle => 'Resumen de perfil';

  @override
  String get registerSummaryName => 'Nombre';

  @override
  String get registerSummaryEmail => 'Email';

  @override
  String get registerSummaryPhone => 'Teléfono';

  @override
  String get registerSummaryRole => 'Rol';

  @override
  String get registerSummaryCompany => 'Empresa';

  @override
  String get registerSummaryLanguage => 'Idioma';

  @override
  String get registerAcceptThe => 'Acepto los';

  @override
  String get registerTermsLink => 'Términos y Condiciones';

  @override
  String get registerAcceptThePrivacy => 'Acepto la';

  @override
  String get registerPrivacyLink => 'Política de Privacidad';

  @override
  String registerLinkOpensBrowser(String linkLabel) {
    return '$linkLabel (abre en el navegador)';
  }

  @override
  String get registerKycNotice =>
      'Tu identidad se verificará en el siguiente paso conforme a la normativa de prevención de blanqueo (KYC).';

  @override
  String get registerCouldNotCreate => 'No se pudo crear la cuenta';

  @override
  String registerLinkOpenFailed(String url) {
    return 'No se pudo abrir el documento. Visítalo en $url';
  }

  @override
  String get inviteBannerTitle => 'Te uniste como miembro de equipo';

  @override
  String inviteBannerBody(String inviter, String org) {
    return '$inviter te invitó al equipo de $org. Sólo necesitas tus datos personales — la empresa y el rol ya están definidos por tu equipo.';
  }

  @override
  String get inviteFallbackOrg => 'una organización';

  @override
  String get inviteFallbackInviter => 'tu equipo';

  @override
  String get inviteInvalidTitle => 'Invitación no disponible';

  @override
  String get inviteInvalidRevoked =>
      'La invitación ya no es válida (puede que la hayan revocado o ya la hayas aceptado).';

  @override
  String get inviteInvalidLoadFailed =>
      'No se pudo cargar la invitación. Vuelve a hacer clic en el link del email o pide una nueva invitación.';

  @override
  String get inviteGoToNormalRegister => 'Crear cuenta normal';

  @override
  String get inviteGoToLogin => 'Ya tengo cuenta · Iniciar sesión';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Comenzar';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a PactStream';

  @override
  String get onboardingWelcomeBody =>
      'La plataforma que genera confianza en cada proyecto de construcción.';

  @override
  String get onboardingWorksTitle => 'Gestiona tus obras';

  @override
  String get onboardingWorksBody =>
      'Crea contratos, invita participantes y controla los hitos de cada proyecto.';

  @override
  String get onboardingPaymentsTitle => 'Pagos seguros';

  @override
  String get onboardingPaymentsBody =>
      'Custodia protegida por póliza de caución con aseguradora líder. Los fondos se liberan al validar el trabajo.';

  @override
  String get onboardingReputationTitle => 'Tu reputación importa';

  @override
  String get onboardingReputationBody =>
      'Construye tu Trust Score con cada proyecto exitoso. Tu historial es tu mejor credencial.';

  @override
  String get kycIntroTitle => 'Verifica tu identidad';

  @override
  String get kycIntroBody =>
      'Para firmar pactos y mover dinero, necesitamos confirmar quién eres. Tarda 2 minutos.';

  @override
  String get kycBulletEscrowTitle => 'Escrow regulado';

  @override
  String get kycBulletEscrowBody =>
      'Tu dinero queda en custodia bajo licencia europea (Mangopay).';

  @override
  String get kycBulletSignatureTitle => 'Firma legal eIDAS';

  @override
  String get kycBulletSignatureBody =>
      'Tu pacto tiene validez ante un juez (Signaturit).';

  @override
  String get kycBulletTrustTitle => 'Confianza para las 3 partes';

  @override
  String get kycBulletTrustBody => 'Promotor, técnico y constructora.';

  @override
  String get kycStartCta => 'Empezar verificación';

  @override
  String get kycLaterCta => 'Hacerlo más tarde';

  @override
  String get kycProviderNote =>
      'Verificación gestionada por Veriff, proveedor europeo certificado.';

  @override
  String get kycCaptureAppBarTitle => 'Verificación de identidad';

  @override
  String get kycCaptureTitle => 'Verifica tu identidad con Veriff';

  @override
  String get kycCaptureBody =>
      'Necesitas un documento de identidad oficial o tu pasaporte, y la cámara del dispositivo. Tarda 2-3 minutos.';

  @override
  String get kycStep1Title => 'Foto del documento';

  @override
  String get kycStep1Body =>
      'Documento de identidad o pasaporte. Veriff valida la autenticidad.';

  @override
  String get kycStep2Title => 'Selfie con prueba de vida';

  @override
  String get kycStep2Body => 'Mira a la cámara y sigue las instrucciones.';

  @override
  String get kycStep3Title => 'Resultado en 30-60 segundos';

  @override
  String get kycStep3Body =>
      'Si todo va bien, accedes a la app inmediatamente.';

  @override
  String get kycStartSessionCta => 'Iniciar verificación';

  @override
  String get kycCreatingSession => 'Creando sesión…';

  @override
  String get kycWaitingTitle => 'Esperando confirmación de Veriff…';

  @override
  String get kycWaitingBody =>
      'Completa la verificación en la pestaña que se abrió. Cuando termines, vuelve aquí — detectaremos el resultado automáticamente.';

  @override
  String get kycReopenVeriff => 'Reabrir verificación de Veriff';

  @override
  String get kycCheckStatusNow => 'Comprobar estado ahora';

  @override
  String get kycCancelAndBack => 'Cancelar y volver';

  @override
  String get kycStillProcessing =>
      'Verificación aún en proceso. Espera unos segundos.';

  @override
  String get kycTimeoutTitle => 'Esto está tardando más de lo normal';

  @override
  String get kycTimeoutBody =>
      'Veriff aún no nos ha confirmado el resultado. Puedes seguir usando la app y volver más tarde — te avisaremos cuando la verificación termine — o reintentar la comprobación ahora.';

  @override
  String get kycContinueLater => 'Seguir más tarde';

  @override
  String get kycErrorNoSessionUrl => 'Veriff no devolvió una URL de sesión.';

  @override
  String get kycErrorCannotOpenUrl =>
      'No se pudo abrir la ventana de verificación de Veriff.';

  @override
  String get kycVerifiedTitle => 'Identidad verificada';

  @override
  String get kycVerifiedBody =>
      'Ya puedes firmar pactos y mover dinero en custodia.';

  @override
  String get kycVerifiedAtLabel => 'Verificada el';

  @override
  String get kycValidatedByLabel => 'Validada por';

  @override
  String get kycOperationsLabel => 'Operaciones';

  @override
  String get kycOperationsAvailable => 'Disponibles ✓';

  @override
  String get kycContinueHome => 'Continuar al inicio';

  @override
  String get kycPendingTitle => 'Revisión en curso';

  @override
  String get kycPendingBody =>
      'Hemos recibido tu documentación. Un agente revisará tu identidad en menos de 24 horas.';

  @override
  String get kycReceivedLabel => 'Recibido';

  @override
  String get kycMaxDeadlineLabel => 'Plazo máximo';

  @override
  String get kycMaxDeadlineValue => '24 horas hábiles';

  @override
  String get kycOperationsLimited => 'Limitadas hasta aprobación';

  @override
  String get kycPendingNotice =>
      'Te avisaremos por email y notificación cuando esté lista.';

  @override
  String get kycBackHome => 'Volver a inicio';

  @override
  String get kycRejectedTitle => 'Verificación rechazada';

  @override
  String get kycRejectedBody =>
      'No hemos podido validar tu identidad con la documentación aportada.';

  @override
  String get kycRejectedReasonLabel => 'Motivo';

  @override
  String get kycRejectedReasonDefault =>
      'Documento ilegible o caducado. Por favor, vuelve a intentarlo con un documento en buen estado.';

  @override
  String get kycRetryCta => 'Volver a intentar';

  @override
  String regionTaxIdLabel(String document) {
    return 'Identificación fiscal ($document)';
  }

  @override
  String regionCompanyTaxIdLabel(String document) {
    return 'Identificación fiscal de la empresa ($document)';
  }

  @override
  String get regionLicenseBoard => 'Colegio o registro profesional';

  @override
  String get regionLicenseNumber => 'Número de colegiación o licencia';

  @override
  String get adminAreaProvince => 'Provincia';

  @override
  String get adminAreaState => 'Estado';

  @override
  String get adminAreaDepartment => 'Departamento';

  @override
  String get adminAreaRegion => 'Región';

  @override
  String get adminAreaDistrict => 'Distrito';

  @override
  String get regionCountryLabel => 'País';

  @override
  String get regionCountryHelper =>
      'Determina tu moneda, tu identificación fiscal y el formato de los importes.';

  @override
  String get countryES => 'España';

  @override
  String get countryVE => 'Venezuela';

  @override
  String get countrySV => 'El Salvador';

  @override
  String get countryMX => 'México';

  @override
  String get countryCO => 'Colombia';

  @override
  String get countryPE => 'Perú';

  @override
  String get countryCL => 'Chile';

  @override
  String get countryAR => 'Argentina';

  @override
  String get countryPA => 'Panamá';

  @override
  String get countryUS => 'Estados Unidos';

  @override
  String get countryPT => 'Portugal';

  @override
  String get pdfRoleOwner => 'Promotor';

  @override
  String get pdfRoleContractor => 'Constructor';

  @override
  String get pdfRoleArchitect => 'Arquitecto técnico';

  @override
  String get pdfPactStateDraft => 'Borrador';

  @override
  String get pdfPactStateSigning => 'En firma';

  @override
  String get pdfPactStateActive => 'En ejecución';

  @override
  String get pdfPactStateCompleted => 'Completado';

  @override
  String get pdfPactStateCancelled => 'Cancelado';

  @override
  String get pdfPactStateDisputed => 'En disputa';

  @override
  String get pdfMilestoneStatePending => 'Pendiente';

  @override
  String get pdfMilestoneStateInExecution => 'En ejecución';

  @override
  String get pdfMilestoneStateInReview => 'En revisión';

  @override
  String get pdfMilestoneStateValidated => 'Validado';

  @override
  String get pdfMilestoneStateApproved => 'Aprobado';

  @override
  String get pdfMilestoneStatePaid => 'Pagado';

  @override
  String get pdfMilestoneStateDisputed => 'En disputa';

  @override
  String get pdfAddendumStateActive => 'Activo';

  @override
  String get pdfAddendumStateCancelled => 'Cancelado';

  @override
  String get pdfAddendumStatePending => 'Pendiente';

  @override
  String get pdfSigned => '✓  FIRMADO';

  @override
  String get pdfUnsigned => 'PENDIENTE';

  @override
  String pdfPageNumber(int page, int total) {
    return 'Pág. $page de $total';
  }

  @override
  String get pdfSignatureDisclaimer =>
      'Las firmas a continuación fueron realizadas mediante firma electrónica avanzada conforme al Reglamento eIDAS (UE) 910/2014 y la Ley 6/2020 española. Cada firma quedó registrada con fecha, hora, dispositivo y hash verificable en PactStream.';

  @override
  String pdfReportDocTitle(String displayId) {
    return 'Libro de la Obra · $displayId';
  }

  @override
  String get pdfReportDocSubject =>
      'Expediente completo de obra con custodia por hitos';

  @override
  String get pdfReportTitle => 'LIBRO DE LA OBRA';

  @override
  String get pdfReportSubtitle => 'Expediente completo · PactStream';

  @override
  String get pdfReportHeaderBrand => 'PactStream · Libro de la Obra';

  @override
  String get pdfReportLabelReference => 'Referencia';

  @override
  String get pdfReportLabelProject => 'Obra';

  @override
  String get pdfReportLabelLocation => 'Localización';

  @override
  String get pdfReportLabelType => 'Tipo';

  @override
  String get pdfReportMinorWork => 'Obra menor (sin licencia)';

  @override
  String get pdfReportMajorWork => 'Obra mayor';

  @override
  String get pdfReportLabelStatus => 'Estado';

  @override
  String get pdfReportLabelGenerated => 'Generado';

  @override
  String get pdfReportPartiesTitle => 'Partes intervinientes';

  @override
  String get pdfReportHeaderRole => 'Rol';

  @override
  String get pdfReportHeaderName => 'Nombre';

  @override
  String get pdfReportHeaderEmail => 'Email';

  @override
  String get pdfReportFinancialTitle => 'Resumen financiero';

  @override
  String get pdfReportOriginalEstimate => 'Presupuesto original';

  @override
  String get pdfReportChangeOrders => 'Modificados (anexos activos)';

  @override
  String get pdfReportEffectiveEstimate => 'Presupuesto efectivo';

  @override
  String get pdfReportAmountPaid => 'Importe ejecutado y pagado';

  @override
  String get pdfReportPendingPayment => 'Pendiente de pago';

  @override
  String get pdfReportPercentComplete => '% Ejecutado';

  @override
  String get pdfReportIvaIncluded => 'incluido';

  @override
  String get pdfReportIvaExcluded => 'no incluido';

  @override
  String pdfReportIvaNote(String status, String rate) {
    return 'IVA $status · tipo $rate%';
  }

  @override
  String get pdfReportTimelineTitle => 'Cronología de la obra';

  @override
  String get pdfReportPactCreated => 'Pacto creado';

  @override
  String get pdfReportEstimatedStart => 'Inicio estimado';

  @override
  String pdfReportMilestonePaid(int ordinal, String amount) {
    return 'Hito $ordinal pagado · $amount';
  }

  @override
  String pdfReportAddendumActiveEvent(int ordinal, String amount) {
    return 'Anexo #$ordinal activo · $amount';
  }

  @override
  String get pdfReportEstimatedEnd => 'Fin estimado';

  @override
  String get pdfReportEstimatedSuffix => '(estimado)';

  @override
  String pdfReportMilestonesTitle(int count) {
    return 'Hitos y certificaciones ($count)';
  }

  @override
  String get pdfReportHeaderDescription => 'Descripción';

  @override
  String get pdfReportHeaderAmount => 'Importe';

  @override
  String get pdfReportHeaderPaid => 'Pagado';

  @override
  String pdfReportAddendumTitle(int count) {
    return 'Modificados y anexos ($count)';
  }

  @override
  String get pdfReportHeaderTitleJustification => 'Título / Justificación';

  @override
  String get pdfReportHeaderExtraAmount => 'Importe extra';

  @override
  String get pdfReportHeaderExtraDays => 'Días extra';

  @override
  String get pdfReportSignaturesTitle => 'Firmas verificadas';

  @override
  String pdfReportFooterDate(String date) {
    return 'Documento generado el $date · uso confidencial';
  }

  @override
  String pdfReportFooterReference(String displayId) {
    return 'Expediente generado por PactStream · pactstream.es · Referencia: $displayId';
  }
}

/// The translations for Spanish Castilian, as used in Latin America and the Caribbean (`es_419`).
class AppLocalizationsEs419 extends AppLocalizationsEs {
  AppLocalizationsEs419() : super('es_419');

  @override
  String get appTitle => 'PactStream';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonNext => 'Siguiente →';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSaveChanges => 'Guardar cambios';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonAccept => 'Aceptar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String get commonOr => 'o';

  @override
  String get commonRequired => 'Obligatorio';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get commonNotAvailable => '—';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageSelectorTitle => 'Elige tu idioma';

  @override
  String get languageSelectorSubtitle =>
      'Puedes cambiarlo cuando quieras desde tu perfil.';

  @override
  String get languageChanged => 'Idioma actualizado';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginSubtitle => 'Ingresa a tu cuenta para gestionar tus obras';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginEmailHint => 'tu@correo.com';

  @override
  String get loginEmailEmpty => 'Ingresa tu correo';

  @override
  String get loginEmailInvalid => 'Ese correo no parece válido';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get loginPasswordEmpty => 'Ingresa tu contraseña';

  @override
  String get loginPasswordTooShort => 'Mínimo 8 caracteres';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginCreateAccount => 'Crear cuenta nueva';

  @override
  String get loginContinueWithGoogle => 'Continuar con Google';

  @override
  String get loginShowPassword => 'Mostrar contraseña';

  @override
  String get loginHidePassword => 'Ocultar contraseña';

  @override
  String get resetTitle => 'Recuperar contraseña';

  @override
  String get resetBody =>
      'Te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get resetSend => 'Enviar enlace';

  @override
  String get resetSent =>
      'Revisa tu correo — te enviamos el enlace de recuperación.';

  @override
  String get resetFailed => 'No se pudo enviar el correo. Inténtalo de nuevo.';

  @override
  String registerStepIndicator(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get registerCreateAccountCta => 'Crear mi cuenta';

  @override
  String get registerStep1Title => 'Crea tu cuenta';

  @override
  String get registerStep1Subtitle => 'Datos personales';

  @override
  String get registerFullNameLabel => 'Nombre completo';

  @override
  String get registerFullNameHint => 'Ej: Juan Pérez';

  @override
  String get registerEmailLockedHelper =>
      'Tu equipo te invitó con este correo; no se puede cambiar.';

  @override
  String get registerPhoneLabel => 'Celular';

  @override
  String get registerLegalPreview =>
      'Al continuar verás los términos legales en el último paso. No creamos la cuenta hasta que los aceptes.';

  @override
  String get registerStep2Title => 'Configura tu perfil';

  @override
  String get registerStep2Subtitle => 'Selecciona tu rol en PactStream';

  @override
  String get registerProfessionalDataTitle => 'Datos profesionales';

  @override
  String get roleOwnerTitle => 'Promotor';

  @override
  String get roleOwnerSubtitle => 'Quiero financiar una obra con seguridad';

  @override
  String get roleContractorTitle => 'Constructor';

  @override
  String get roleContractorSubtitle =>
      'Ejecuto obras y quiero cobrar garantizado';

  @override
  String get roleArchitectTitle => 'Ingeniero / Arquitecto';

  @override
  String get roleArchitectSubtitle => 'Superviso obras y apruebo avances';

  @override
  String get registerCompanyNameLabel => 'Nombre de empresa';

  @override
  String get registerCompanyNameHint => 'Ej: Constructora Gómez S.A.';

  @override
  String get registerStep3Title => 'Verifica tus datos';

  @override
  String get registerStep3Subtitle =>
      'Revisa la información antes de crear tu cuenta';

  @override
  String get registerSummaryTitle => 'Resumen de perfil';

  @override
  String get registerSummaryName => 'Nombre';

  @override
  String get registerSummaryEmail => 'Correo';

  @override
  String get registerSummaryPhone => 'Celular';

  @override
  String get registerSummaryRole => 'Rol';

  @override
  String get registerSummaryCompany => 'Empresa';

  @override
  String get registerSummaryLanguage => 'Idioma';

  @override
  String get registerAcceptThe => 'Acepto los';

  @override
  String get registerTermsLink => 'Términos y Condiciones';

  @override
  String get registerAcceptThePrivacy => 'Acepto la';

  @override
  String get registerPrivacyLink => 'Política de Privacidad';

  @override
  String registerLinkOpensBrowser(String linkLabel) {
    return '$linkLabel (abre en el navegador)';
  }

  @override
  String get registerKycNotice =>
      'Tu identidad se verificará en el siguiente paso conforme a la normativa de prevención de lavado de activos (KYC).';

  @override
  String get registerCouldNotCreate => 'No se pudo crear la cuenta';

  @override
  String registerLinkOpenFailed(String url) {
    return 'No se pudo abrir el documento. Puedes verlo en $url';
  }

  @override
  String get inviteBannerTitle => 'Te uniste como miembro del equipo';

  @override
  String inviteBannerBody(String inviter, String org) {
    return '$inviter te invitó al equipo de $org. Solo necesitas tus datos personales — la empresa y el rol ya los definió tu equipo.';
  }

  @override
  String get inviteFallbackOrg => 'una organización';

  @override
  String get inviteFallbackInviter => 'Tu equipo';

  @override
  String get inviteInvalidTitle => 'Invitación no disponible';

  @override
  String get inviteInvalidRevoked =>
      'La invitación ya no es válida — puede que la hayan revocado o que ya la hayas aceptado.';

  @override
  String get inviteInvalidLoadFailed =>
      'No se pudo cargar la invitación. Vuelve a hacer clic en el enlace del correo o pide una invitación nueva.';

  @override
  String get inviteGoToNormalRegister => 'Crear cuenta normal';

  @override
  String get inviteGoToLogin => 'Ya tengo cuenta · Iniciar sesión';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Comenzar';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a PactStream';

  @override
  String get onboardingWelcomeBody =>
      'La plataforma que genera confianza en cada proyecto de construcción.';

  @override
  String get onboardingWorksTitle => 'Gestiona tus obras';

  @override
  String get onboardingWorksBody =>
      'Crea contratos, invita participantes y controla los hitos de cada proyecto.';

  @override
  String get onboardingPaymentsTitle => 'Pagos seguros';

  @override
  String get onboardingPaymentsBody =>
      'Custodia protegida por póliza de fianza con aseguradora líder. Los fondos se liberan al validar el trabajo.';

  @override
  String get onboardingReputationTitle => 'Tu reputación importa';

  @override
  String get onboardingReputationBody =>
      'Construye tu Trust Score con cada proyecto exitoso. Tu historial es tu mejor credencial.';

  @override
  String get kycIntroTitle => 'Verifica tu identidad';

  @override
  String get kycIntroBody =>
      'Para firmar pactos y mover dinero, necesitamos confirmar quién eres. Toma 2 minutos.';

  @override
  String get kycBulletEscrowTitle => 'Custodia regulada';

  @override
  String get kycBulletEscrowBody =>
      'Tu dinero queda en custodia bajo licencia europea (Mangopay).';

  @override
  String get kycBulletSignatureTitle => 'Firma legal eIDAS';

  @override
  String get kycBulletSignatureBody =>
      'Tu pacto tiene validez ante un juez (Signaturit).';

  @override
  String get kycBulletTrustTitle => 'Confianza para las 3 partes';

  @override
  String get kycBulletTrustBody => 'Promotor, ingeniero y constructora.';

  @override
  String get kycStartCta => 'Comenzar verificación';

  @override
  String get kycLaterCta => 'Hacerlo más tarde';

  @override
  String get kycProviderNote =>
      'Verificación gestionada por Veriff, proveedor europeo certificado.';

  @override
  String get kycCaptureAppBarTitle => 'Verificación de identidad';

  @override
  String get kycCaptureTitle => 'Verifica tu identidad con Veriff';

  @override
  String get kycCaptureBody =>
      'Necesitas un documento de identidad oficial o tu pasaporte, y la cámara del dispositivo. Toma 2-3 minutos.';

  @override
  String get kycStep1Title => 'Foto del documento';

  @override
  String get kycStep1Body =>
      'Documento de identidad o pasaporte. Veriff valida la autenticidad.';

  @override
  String get kycStep2Title => 'Selfie con prueba de vida';

  @override
  String get kycStep2Body => 'Mira a la cámara y sigue las instrucciones.';

  @override
  String get kycStep3Title => 'Resultado en 30-60 segundos';

  @override
  String get kycStep3Body => 'Si todo va bien, ingresas a la app de inmediato.';

  @override
  String get kycStartSessionCta => 'Iniciar verificación';

  @override
  String get kycCreatingSession => 'Creando sesión…';

  @override
  String get kycWaitingTitle => 'Esperando confirmación de Veriff…';

  @override
  String get kycWaitingBody =>
      'Completa la verificación en la pestaña que se abrió. Cuando termines, vuelve aquí — detectaremos el resultado automáticamente.';

  @override
  String get kycReopenVeriff => 'Reabrir verificación de Veriff';

  @override
  String get kycCheckStatusNow => 'Verificar estado ahora';

  @override
  String get kycCancelAndBack => 'Cancelar y volver';

  @override
  String get kycStillProcessing =>
      'La verificación sigue en proceso. Espera unos segundos.';

  @override
  String get kycTimeoutTitle => 'Esto está tardando más de lo normal';

  @override
  String get kycTimeoutBody =>
      'Veriff todavía no nos confirmó el resultado. Puedes seguir usando la app y volver más tarde — te avisaremos cuando la verificación termine — o verificar de nuevo ahora.';

  @override
  String get kycContinueLater => 'Seguir más tarde';

  @override
  String get kycErrorNoSessionUrl => 'Veriff no devolvió una URL de sesión.';

  @override
  String get kycErrorCannotOpenUrl =>
      'No se pudo abrir la ventana de verificación de Veriff.';

  @override
  String get kycVerifiedTitle => 'Identidad verificada';

  @override
  String get kycVerifiedBody =>
      'Ya puedes firmar pactos y mover dinero en custodia.';

  @override
  String get kycVerifiedAtLabel => 'Verificada el';

  @override
  String get kycValidatedByLabel => 'Validada por';

  @override
  String get kycOperationsLabel => 'Operaciones';

  @override
  String get kycOperationsAvailable => 'Disponibles ✓';

  @override
  String get kycContinueHome => 'Continuar al inicio';

  @override
  String get kycPendingTitle => 'Revisión en curso';

  @override
  String get kycPendingBody =>
      'Recibimos tu documentación. Un agente revisará tu identidad en menos de 24 horas.';

  @override
  String get kycReceivedLabel => 'Recibido';

  @override
  String get kycMaxDeadlineLabel => 'Plazo máximo';

  @override
  String get kycMaxDeadlineValue => '24 horas hábiles';

  @override
  String get kycOperationsLimited => 'Limitadas hasta la aprobación';

  @override
  String get kycPendingNotice =>
      'Te avisaremos por correo y notificación cuando esté lista.';

  @override
  String get kycBackHome => 'Volver al inicio';

  @override
  String get kycRejectedTitle => 'Verificación rechazada';

  @override
  String get kycRejectedBody =>
      'No pudimos validar tu identidad con la documentación que enviaste.';

  @override
  String get kycRejectedReasonLabel => 'Motivo';

  @override
  String get kycRejectedReasonDefault =>
      'Documento ilegible o vencido. Intenta de nuevo con un documento en buen estado.';

  @override
  String get kycRetryCta => 'Intentar de nuevo';

  @override
  String regionTaxIdLabel(String document) {
    return 'Identificación fiscal ($document)';
  }

  @override
  String regionCompanyTaxIdLabel(String document) {
    return 'Identificación fiscal de la empresa ($document)';
  }

  @override
  String get regionLicenseBoard => 'Colegio o registro profesional';

  @override
  String get regionLicenseNumber => 'Número de colegiado o licencia';

  @override
  String get adminAreaProvince => 'Provincia';

  @override
  String get adminAreaState => 'Estado';

  @override
  String get adminAreaDepartment => 'Departamento';

  @override
  String get adminAreaRegion => 'Región';

  @override
  String get adminAreaDistrict => 'Distrito';

  @override
  String get regionCountryLabel => 'País';

  @override
  String get regionCountryHelper =>
      'Determina tu moneda, tu identificación fiscal y el formato de los montos.';

  @override
  String get countryES => 'España';

  @override
  String get countryVE => 'Venezuela';

  @override
  String get countrySV => 'El Salvador';

  @override
  String get countryMX => 'México';

  @override
  String get countryCO => 'Colombia';

  @override
  String get countryPE => 'Perú';

  @override
  String get countryCL => 'Chile';

  @override
  String get countryAR => 'Argentina';

  @override
  String get countryPA => 'Panamá';

  @override
  String get countryUS => 'Estados Unidos';

  @override
  String get countryPT => 'Portugal';

  @override
  String get pdfRoleOwner => 'Desarrollador';

  @override
  String get pdfRoleArchitect => 'Ingeniero/Arquitecto';

  @override
  String pdfReportDocTitle(String displayId) {
    return 'Libro de la Obra · $displayId';
  }

  @override
  String get pdfReportAmountPaid => 'Monto ejecutado y pagado';

  @override
  String get pdfReportHeaderAmount => 'Monto';

  @override
  String get pdfReportHeaderExtraAmount => 'Monto extra';
}
