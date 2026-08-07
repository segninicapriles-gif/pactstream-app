import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('es', '419')
  ];

  /// Nombre de la app en el gestor de tareas del sistema. No se traduce: es marca.
  ///
  /// In es, this message translates to:
  /// **'PactStream'**
  String get appTitle;

  /// No description provided for @commonContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @commonNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente →'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonSaveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get commonSaveChanges;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @commonAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get commonAccept;

  /// No description provided for @commonConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get commonLoading;

  /// No description provided for @commonOr.
  ///
  /// In es, this message translates to:
  /// **'o'**
  String get commonOr;

  /// No description provided for @commonRequired.
  ///
  /// In es, this message translates to:
  /// **'Obligatorio'**
  String get commonRequired;

  /// No description provided for @commonOptional.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get commonOptional;

  /// Marcador de dato ausente en tablas y resúmenes. Guion largo, no 'N/A'.
  ///
  /// In es, this message translates to:
  /// **'—'**
  String get commonNotAvailable;

  /// No description provided for @languageLabel.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get languageLabel;

  /// No description provided for @languageSelectorTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige tu idioma'**
  String get languageSelectorTitle;

  /// No description provided for @languageSelectorSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes cambiarlo cuando quieras desde tu perfil.'**
  String get languageSelectorSubtitle;

  /// Confirmación tras cambiar idioma en ajustes.
  ///
  /// In es, this message translates to:
  /// **'Idioma actualizado'**
  String get languageChanged;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Accede a tu cuenta para gestionar tus obras'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In es, this message translates to:
  /// **'tu@email.com'**
  String get loginEmailHint;

  /// No description provided for @loginEmailEmpty.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu email'**
  String get loginEmailEmpty;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ese email no parece válido'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get loginPasswordHint;

  /// No description provided for @loginPasswordEmpty.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu contraseña'**
  String get loginPasswordEmpty;

  /// No description provided for @loginPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get loginPasswordTooShort;

  /// No description provided for @loginForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get loginForgotPassword;

  /// No description provided for @loginCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta nueva'**
  String get loginCreateAccount;

  /// No description provided for @loginContinueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get loginContinueWithGoogle;

  /// No description provided for @loginShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get loginHidePassword;

  /// No description provided for @resetTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar contraseña'**
  String get resetTitle;

  /// No description provided for @resetBody.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un enlace para restablecer tu contraseña.'**
  String get resetBody;

  /// No description provided for @resetSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get resetSend;

  /// No description provided for @resetSent.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo — te hemos enviado el enlace de recuperación.'**
  String get resetSent;

  /// No description provided for @resetFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el correo. Inténtalo de nuevo.'**
  String get resetFailed;

  /// No description provided for @registerStepIndicator.
  ///
  /// In es, this message translates to:
  /// **'Paso {current} de {total}'**
  String registerStepIndicator(int current, int total);

  /// No description provided for @registerCreateAccountCta.
  ///
  /// In es, this message translates to:
  /// **'Crear mi cuenta'**
  String get registerCreateAccountCta;

  /// No description provided for @registerStep1Title.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta'**
  String get registerStep1Title;

  /// No description provided for @registerStep1Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Datos personales'**
  String get registerStep1Subtitle;

  /// No description provided for @registerFullNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get registerFullNameLabel;

  /// No description provided for @registerFullNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Juan Pérez'**
  String get registerFullNameHint;

  /// No description provided for @registerEmailLockedHelper.
  ///
  /// In es, this message translates to:
  /// **'Tu equipo te invitó con este email; no se puede cambiar.'**
  String get registerEmailLockedHelper;

  /// No description provided for @registerPhoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get registerPhoneLabel;

  /// No description provided for @registerLegalPreview.
  ///
  /// In es, this message translates to:
  /// **'Al continuar verás los términos legales en el último paso. No creamos la cuenta hasta que los aceptes.'**
  String get registerLegalPreview;

  /// No description provided for @registerStep2Title.
  ///
  /// In es, this message translates to:
  /// **'Configura tu perfil'**
  String get registerStep2Title;

  /// No description provided for @registerStep2Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona tu rol en PactStream'**
  String get registerStep2Subtitle;

  /// No description provided for @registerProfessionalDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos profesionales'**
  String get registerProfessionalDataTitle;

  /// No description provided for @roleOwnerTitle.
  ///
  /// In es, this message translates to:
  /// **'Promotor'**
  String get roleOwnerTitle;

  /// No description provided for @roleOwnerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Quiero financiar una obra con seguridad'**
  String get roleOwnerSubtitle;

  /// No description provided for @roleContractorTitle.
  ///
  /// In es, this message translates to:
  /// **'Constructor'**
  String get roleContractorTitle;

  /// No description provided for @roleContractorSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ejecuto obras y quiero cobrar garantizado'**
  String get roleContractorSubtitle;

  /// No description provided for @roleArchitectTitle.
  ///
  /// In es, this message translates to:
  /// **'Técnico'**
  String get roleArchitectTitle;

  /// No description provided for @roleArchitectSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Dirijo obras y valido hitos'**
  String get roleArchitectSubtitle;

  /// No description provided for @registerCompanyNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de empresa'**
  String get registerCompanyNameLabel;

  /// No description provided for @registerCompanyNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Construcciones Gómez S.L.'**
  String get registerCompanyNameHint;

  /// No description provided for @registerStep3Title.
  ///
  /// In es, this message translates to:
  /// **'Verifica tus datos'**
  String get registerStep3Title;

  /// No description provided for @registerStep3Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa la información antes de crear tu cuenta'**
  String get registerStep3Subtitle;

  /// No description provided for @registerSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen de perfil'**
  String get registerSummaryTitle;

  /// No description provided for @registerSummaryName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get registerSummaryName;

  /// No description provided for @registerSummaryEmail.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get registerSummaryEmail;

  /// No description provided for @registerSummaryPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get registerSummaryPhone;

  /// No description provided for @registerSummaryRole.
  ///
  /// In es, this message translates to:
  /// **'Rol'**
  String get registerSummaryRole;

  /// No description provided for @registerSummaryCompany.
  ///
  /// In es, this message translates to:
  /// **'Empresa'**
  String get registerSummaryCompany;

  /// No description provided for @registerSummaryLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get registerSummaryLanguage;

  /// No description provided for @registerAcceptThe.
  ///
  /// In es, this message translates to:
  /// **'Acepto los'**
  String get registerAcceptThe;

  /// No description provided for @registerTermsLink.
  ///
  /// In es, this message translates to:
  /// **'Términos y Condiciones'**
  String get registerTermsLink;

  /// No description provided for @registerAcceptThePrivacy.
  ///
  /// In es, this message translates to:
  /// **'Acepto la'**
  String get registerAcceptThePrivacy;

  /// No description provided for @registerPrivacyLink.
  ///
  /// In es, this message translates to:
  /// **'Política de Privacidad'**
  String get registerPrivacyLink;

  /// Etiqueta de accesibilidad para enlaces legales.
  ///
  /// In es, this message translates to:
  /// **'{linkLabel} (abre en el navegador)'**
  String registerLinkOpensBrowser(String linkLabel);

  /// No description provided for @registerKycNotice.
  ///
  /// In es, this message translates to:
  /// **'Tu identidad se verificará en el siguiente paso conforme a la normativa de prevención de blanqueo (KYC).'**
  String get registerKycNotice;

  /// No description provided for @registerCouldNotCreate.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la cuenta'**
  String get registerCouldNotCreate;

  /// No description provided for @registerLinkOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el documento. Visítalo en {url}'**
  String registerLinkOpenFailed(String url);

  /// No description provided for @inviteBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Te uniste como miembro de equipo'**
  String get inviteBannerTitle;

  /// No description provided for @inviteBannerBody.
  ///
  /// In es, this message translates to:
  /// **'{inviter} te invitó al equipo de {org}. Sólo necesitas tus datos personales — la empresa y el rol ya están definidos por tu equipo.'**
  String inviteBannerBody(String inviter, String org);

  /// No description provided for @inviteFallbackOrg.
  ///
  /// In es, this message translates to:
  /// **'una organización'**
  String get inviteFallbackOrg;

  /// No description provided for @inviteFallbackInviter.
  ///
  /// In es, this message translates to:
  /// **'tu equipo'**
  String get inviteFallbackInviter;

  /// No description provided for @inviteInvalidTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitación no disponible'**
  String get inviteInvalidTitle;

  /// No description provided for @inviteInvalidRevoked.
  ///
  /// In es, this message translates to:
  /// **'La invitación ya no es válida (puede que la hayan revocado o ya la hayas aceptado).'**
  String get inviteInvalidRevoked;

  /// No description provided for @inviteInvalidLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la invitación. Vuelve a hacer clic en el link del email o pide una nueva invitación.'**
  String get inviteInvalidLoadFailed;

  /// No description provided for @inviteGoToNormalRegister.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta normal'**
  String get inviteGoToNormalRegister;

  /// No description provided for @inviteGoToLogin.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo cuenta · Iniciar sesión'**
  String get inviteGoToLogin;

  /// No description provided for @onboardingSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get onboardingStart;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a PactStream'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In es, this message translates to:
  /// **'La plataforma que genera confianza en cada proyecto de construcción.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingWorksTitle.
  ///
  /// In es, this message translates to:
  /// **'Gestiona tus obras'**
  String get onboardingWorksTitle;

  /// No description provided for @onboardingWorksBody.
  ///
  /// In es, this message translates to:
  /// **'Crea contratos, invita participantes y controla los hitos de cada proyecto.'**
  String get onboardingWorksBody;

  /// No description provided for @onboardingPaymentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos seguros'**
  String get onboardingPaymentsTitle;

  /// ⚠️ AFIRMACIÓN COMERCIAL SIN CONTRATO FIRMADO. No hay póliza contratada con ninguna aseguradora; la fórmula acordada en REFERENCIA_RAPIDA es 'aseguradora líder del mercado (en negociación)'. Esta cadena la promete en presente a un usuario final. Revisar antes de lanzar.
  ///
  /// In es, this message translates to:
  /// **'Custodia protegida por póliza de caución con aseguradora líder. Los fondos se liberan al validar el trabajo.'**
  String get onboardingPaymentsBody;

  /// No description provided for @onboardingReputationTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu reputación importa'**
  String get onboardingReputationTitle;

  /// No description provided for @onboardingReputationBody.
  ///
  /// In es, this message translates to:
  /// **'Construye tu Trust Score con cada proyecto exitoso. Tu historial es tu mejor credencial.'**
  String get onboardingReputationBody;

  /// No description provided for @kycIntroTitle.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu identidad'**
  String get kycIntroTitle;

  /// No description provided for @kycIntroBody.
  ///
  /// In es, this message translates to:
  /// **'Para firmar pactos y mover dinero, necesitamos confirmar quién eres. Tarda 2 minutos.'**
  String get kycIntroBody;

  /// No description provided for @kycBulletEscrowTitle.
  ///
  /// In es, this message translates to:
  /// **'Escrow regulado'**
  String get kycBulletEscrowTitle;

  /// ⚠️ AFIRMACIÓN REGULATORIA. La licencia de Mangopay es europea; para los mercados de EE. UU. y LATAM esta frase necesita revisión legal, no solo traducción. Ver handoff.
  ///
  /// In es, this message translates to:
  /// **'Tu dinero queda en custodia bajo licencia europea (Mangopay).'**
  String get kycBulletEscrowBody;

  /// No description provided for @kycBulletSignatureTitle.
  ///
  /// In es, this message translates to:
  /// **'Firma legal eIDAS'**
  String get kycBulletSignatureTitle;

  /// ⚠️ AFIRMACIÓN REGULATORIA. eIDAS es el reglamento europeo de firma electrónica; en EE. UU. el marco equivalente es ESIGN Act / UETA. Revisión legal pendiente.
  ///
  /// In es, this message translates to:
  /// **'Tu pacto tiene validez ante un juez (Signaturit).'**
  String get kycBulletSignatureBody;

  /// No description provided for @kycBulletTrustTitle.
  ///
  /// In es, this message translates to:
  /// **'Confianza para las 3 partes'**
  String get kycBulletTrustTitle;

  /// No description provided for @kycBulletTrustBody.
  ///
  /// In es, this message translates to:
  /// **'Promotor, técnico y constructora.'**
  String get kycBulletTrustBody;

  /// No description provided for @kycStartCta.
  ///
  /// In es, this message translates to:
  /// **'Empezar verificación'**
  String get kycStartCta;

  /// No description provided for @kycLaterCta.
  ///
  /// In es, this message translates to:
  /// **'Hacerlo más tarde'**
  String get kycLaterCta;

  /// No description provided for @kycProviderNote.
  ///
  /// In es, this message translates to:
  /// **'Verificación gestionada por Veriff, proveedor europeo certificado.'**
  String get kycProviderNote;

  /// No description provided for @kycCaptureAppBarTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificación de identidad'**
  String get kycCaptureAppBarTitle;

  /// No description provided for @kycCaptureTitle.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu identidad con Veriff'**
  String get kycCaptureTitle;

  /// Antes decía 'tu DNI o pasaporte'. Se generalizó a propósito: el DNI es español y esta pantalla la ven usuarios de EE. UU., Venezuela y El Salvador. Veriff acepta documentos de decenas de países y decide él la validez, así que enumerarlos aquí solo sirve para excluir al que tiene otro.
  ///
  /// In es, this message translates to:
  /// **'Necesitas un documento de identidad oficial o tu pasaporte, y la cámara del dispositivo. Tarda 2-3 minutos.'**
  String get kycCaptureBody;

  /// No description provided for @kycStep1Title.
  ///
  /// In es, this message translates to:
  /// **'Foto del documento'**
  String get kycStep1Title;

  /// No description provided for @kycStep1Body.
  ///
  /// In es, this message translates to:
  /// **'Documento de identidad o pasaporte. Veriff valida la autenticidad.'**
  String get kycStep1Body;

  /// No description provided for @kycStep2Title.
  ///
  /// In es, this message translates to:
  /// **'Selfie con prueba de vida'**
  String get kycStep2Title;

  /// No description provided for @kycStep2Body.
  ///
  /// In es, this message translates to:
  /// **'Mira a la cámara y sigue las instrucciones.'**
  String get kycStep2Body;

  /// No description provided for @kycStep3Title.
  ///
  /// In es, this message translates to:
  /// **'Resultado en 30-60 segundos'**
  String get kycStep3Title;

  /// No description provided for @kycStep3Body.
  ///
  /// In es, this message translates to:
  /// **'Si todo va bien, accedes a la app inmediatamente.'**
  String get kycStep3Body;

  /// No description provided for @kycStartSessionCta.
  ///
  /// In es, this message translates to:
  /// **'Iniciar verificación'**
  String get kycStartSessionCta;

  /// No description provided for @kycCreatingSession.
  ///
  /// In es, this message translates to:
  /// **'Creando sesión…'**
  String get kycCreatingSession;

  /// No description provided for @kycWaitingTitle.
  ///
  /// In es, this message translates to:
  /// **'Esperando confirmación de Veriff…'**
  String get kycWaitingTitle;

  /// No description provided for @kycWaitingBody.
  ///
  /// In es, this message translates to:
  /// **'Completa la verificación en la pestaña que se abrió. Cuando termines, vuelve aquí — detectaremos el resultado automáticamente.'**
  String get kycWaitingBody;

  /// No description provided for @kycReopenVeriff.
  ///
  /// In es, this message translates to:
  /// **'Reabrir verificación de Veriff'**
  String get kycReopenVeriff;

  /// No description provided for @kycCheckStatusNow.
  ///
  /// In es, this message translates to:
  /// **'Comprobar estado ahora'**
  String get kycCheckStatusNow;

  /// No description provided for @kycCancelAndBack.
  ///
  /// In es, this message translates to:
  /// **'Cancelar y volver'**
  String get kycCancelAndBack;

  /// No description provided for @kycStillProcessing.
  ///
  /// In es, this message translates to:
  /// **'Verificación aún en proceso. Espera unos segundos.'**
  String get kycStillProcessing;

  /// No description provided for @kycTimeoutTitle.
  ///
  /// In es, this message translates to:
  /// **'Esto está tardando más de lo normal'**
  String get kycTimeoutTitle;

  /// No description provided for @kycTimeoutBody.
  ///
  /// In es, this message translates to:
  /// **'Veriff aún no nos ha confirmado el resultado. Puedes seguir usando la app y volver más tarde — te avisaremos cuando la verificación termine — o reintentar la comprobación ahora.'**
  String get kycTimeoutBody;

  /// No description provided for @kycContinueLater.
  ///
  /// In es, this message translates to:
  /// **'Seguir más tarde'**
  String get kycContinueLater;

  /// No description provided for @kycErrorNoSessionUrl.
  ///
  /// In es, this message translates to:
  /// **'Veriff no devolvió una URL de sesión.'**
  String get kycErrorNoSessionUrl;

  /// No description provided for @kycErrorCannotOpenUrl.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la ventana de verificación de Veriff.'**
  String get kycErrorCannotOpenUrl;

  /// No description provided for @kycVerifiedTitle.
  ///
  /// In es, this message translates to:
  /// **'Identidad verificada'**
  String get kycVerifiedTitle;

  /// No description provided for @kycVerifiedBody.
  ///
  /// In es, this message translates to:
  /// **'Ya puedes firmar pactos y mover dinero en custodia.'**
  String get kycVerifiedBody;

  /// No description provided for @kycVerifiedAtLabel.
  ///
  /// In es, this message translates to:
  /// **'Verificada el'**
  String get kycVerifiedAtLabel;

  /// No description provided for @kycValidatedByLabel.
  ///
  /// In es, this message translates to:
  /// **'Validada por'**
  String get kycValidatedByLabel;

  /// No description provided for @kycOperationsLabel.
  ///
  /// In es, this message translates to:
  /// **'Operaciones'**
  String get kycOperationsLabel;

  /// No description provided for @kycOperationsAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponibles ✓'**
  String get kycOperationsAvailable;

  /// No description provided for @kycContinueHome.
  ///
  /// In es, this message translates to:
  /// **'Continuar al inicio'**
  String get kycContinueHome;

  /// No description provided for @kycPendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisión en curso'**
  String get kycPendingTitle;

  /// No description provided for @kycPendingBody.
  ///
  /// In es, this message translates to:
  /// **'Hemos recibido tu documentación. Un agente revisará tu identidad en menos de 24 horas.'**
  String get kycPendingBody;

  /// No description provided for @kycReceivedLabel.
  ///
  /// In es, this message translates to:
  /// **'Recibido'**
  String get kycReceivedLabel;

  /// No description provided for @kycMaxDeadlineLabel.
  ///
  /// In es, this message translates to:
  /// **'Plazo máximo'**
  String get kycMaxDeadlineLabel;

  /// No description provided for @kycMaxDeadlineValue.
  ///
  /// In es, this message translates to:
  /// **'24 horas hábiles'**
  String get kycMaxDeadlineValue;

  /// No description provided for @kycOperationsLimited.
  ///
  /// In es, this message translates to:
  /// **'Limitadas hasta aprobación'**
  String get kycOperationsLimited;

  /// No description provided for @kycPendingNotice.
  ///
  /// In es, this message translates to:
  /// **'Te avisaremos por email y notificación cuando esté lista.'**
  String get kycPendingNotice;

  /// No description provided for @kycBackHome.
  ///
  /// In es, this message translates to:
  /// **'Volver a inicio'**
  String get kycBackHome;

  /// No description provided for @kycRejectedTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificación rechazada'**
  String get kycRejectedTitle;

  /// No description provided for @kycRejectedBody.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido validar tu identidad con la documentación aportada.'**
  String get kycRejectedBody;

  /// No description provided for @kycRejectedReasonLabel.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get kycRejectedReasonLabel;

  /// Motivo GENÉRICO. Hoy se muestra siempre este texto, venga el rechazo de Veriff por lo que venga. Cuando el RPC devuelva el motivo real habrá que mapearlo; mientras tanto no se le puede decir al usuario algo más concreto sin arriesgarse a mentirle.
  ///
  /// In es, this message translates to:
  /// **'Documento ilegible o caducado. Por favor, vuelve a intentarlo con un documento en buen estado.'**
  String get kycRejectedReasonDefault;

  /// No description provided for @kycRetryCta.
  ///
  /// In es, this message translates to:
  /// **'Volver a intentar'**
  String get kycRetryCta;

  /// El nombre del documento (NIF, RIF, RFC, RUT…) es un nombre propio y NO se traduce: llega como dato desde RegionProfile. Solo se traduce el envoltorio.
  ///
  /// In es, this message translates to:
  /// **'Identificación fiscal ({document})'**
  String regionTaxIdLabel(String document);

  /// No description provided for @regionCompanyTaxIdLabel.
  ///
  /// In es, this message translates to:
  /// **'Identificación fiscal de la empresa ({document})'**
  String regionCompanyTaxIdLabel(String document);

  /// No description provided for @regionLicenseBoard.
  ///
  /// In es, this message translates to:
  /// **'Colegio o registro profesional'**
  String get regionLicenseBoard;

  /// No description provided for @regionLicenseNumber.
  ///
  /// In es, this message translates to:
  /// **'Número de colegiación o licencia'**
  String get regionLicenseNumber;

  /// No description provided for @adminAreaProvince.
  ///
  /// In es, this message translates to:
  /// **'Provincia'**
  String get adminAreaProvince;

  /// No description provided for @adminAreaState.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get adminAreaState;

  /// No description provided for @adminAreaDepartment.
  ///
  /// In es, this message translates to:
  /// **'Departamento'**
  String get adminAreaDepartment;

  /// No description provided for @adminAreaRegion.
  ///
  /// In es, this message translates to:
  /// **'Región'**
  String get adminAreaRegion;

  /// División administrativa de primer nivel. Es lo único del perfil de país que se traduce de verdad; los documentos fiscales no.
  ///
  /// In es, this message translates to:
  /// **'Distrito'**
  String get adminAreaDistrict;

  /// No description provided for @regionCountryLabel.
  ///
  /// In es, this message translates to:
  /// **'País'**
  String get regionCountryLabel;

  /// No description provided for @regionCountryHelper.
  ///
  /// In es, this message translates to:
  /// **'Determina tu moneda, tu identificación fiscal y el formato de los importes.'**
  String get regionCountryHelper;

  /// No description provided for @countryES.
  ///
  /// In es, this message translates to:
  /// **'España'**
  String get countryES;

  /// No description provided for @countryVE.
  ///
  /// In es, this message translates to:
  /// **'Venezuela'**
  String get countryVE;

  /// No description provided for @countrySV.
  ///
  /// In es, this message translates to:
  /// **'El Salvador'**
  String get countrySV;

  /// No description provided for @countryMX.
  ///
  /// In es, this message translates to:
  /// **'México'**
  String get countryMX;

  /// No description provided for @countryCO.
  ///
  /// In es, this message translates to:
  /// **'Colombia'**
  String get countryCO;

  /// No description provided for @countryPE.
  ///
  /// In es, this message translates to:
  /// **'Perú'**
  String get countryPE;

  /// No description provided for @countryCL.
  ///
  /// In es, this message translates to:
  /// **'Chile'**
  String get countryCL;

  /// No description provided for @countryAR.
  ///
  /// In es, this message translates to:
  /// **'Argentina'**
  String get countryAR;

  /// No description provided for @countryPA.
  ///
  /// In es, this message translates to:
  /// **'Panamá'**
  String get countryPA;

  /// No description provided for @countryUS.
  ///
  /// In es, this message translates to:
  /// **'Estados Unidos'**
  String get countryUS;

  /// No description provided for @countryPT.
  ///
  /// In es, this message translates to:
  /// **'Portugal'**
  String get countryPT;

  /// No description provided for @pdfRoleOwner.
  ///
  /// In es, this message translates to:
  /// **'Promotor'**
  String get pdfRoleOwner;

  /// No description provided for @pdfRoleContractor.
  ///
  /// In es, this message translates to:
  /// **'Constructor'**
  String get pdfRoleContractor;

  /// Rol PDF: dirección facultativa. En EN = Architect / Engineer (AIA).
  ///
  /// In es, this message translates to:
  /// **'Arquitecto técnico'**
  String get pdfRoleArchitect;

  /// No description provided for @pdfPactStateDraft.
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get pdfPactStateDraft;

  /// No description provided for @pdfPactStateSigning.
  ///
  /// In es, this message translates to:
  /// **'En firma'**
  String get pdfPactStateSigning;

  /// No description provided for @pdfPactStateActive.
  ///
  /// In es, this message translates to:
  /// **'En ejecución'**
  String get pdfPactStateActive;

  /// No description provided for @pdfPactStateCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get pdfPactStateCompleted;

  /// No description provided for @pdfPactStateCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get pdfPactStateCancelled;

  /// No description provided for @pdfPactStateDisputed.
  ///
  /// In es, this message translates to:
  /// **'En disputa'**
  String get pdfPactStateDisputed;

  /// No description provided for @pdfMilestoneStatePending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get pdfMilestoneStatePending;

  /// No description provided for @pdfMilestoneStateInExecution.
  ///
  /// In es, this message translates to:
  /// **'En ejecución'**
  String get pdfMilestoneStateInExecution;

  /// No description provided for @pdfMilestoneStateInReview.
  ///
  /// In es, this message translates to:
  /// **'En revisión'**
  String get pdfMilestoneStateInReview;

  /// No description provided for @pdfMilestoneStateValidated.
  ///
  /// In es, this message translates to:
  /// **'Validado'**
  String get pdfMilestoneStateValidated;

  /// No description provided for @pdfMilestoneStateApproved.
  ///
  /// In es, this message translates to:
  /// **'Aprobado'**
  String get pdfMilestoneStateApproved;

  /// No description provided for @pdfMilestoneStatePaid.
  ///
  /// In es, this message translates to:
  /// **'Pagado'**
  String get pdfMilestoneStatePaid;

  /// No description provided for @pdfMilestoneStateDisputed.
  ///
  /// In es, this message translates to:
  /// **'En disputa'**
  String get pdfMilestoneStateDisputed;

  /// No description provided for @pdfAddendumStateActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get pdfAddendumStateActive;

  /// No description provided for @pdfAddendumStateCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get pdfAddendumStateCancelled;

  /// No description provided for @pdfAddendumStatePending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get pdfAddendumStatePending;

  /// No description provided for @pdfSigned.
  ///
  /// In es, this message translates to:
  /// **'✓  FIRMADO'**
  String get pdfSigned;

  /// No description provided for @pdfUnsigned.
  ///
  /// In es, this message translates to:
  /// **'PENDIENTE'**
  String get pdfUnsigned;

  /// No description provided for @pdfPageNumber.
  ///
  /// In es, this message translates to:
  /// **'Pág. {page} de {total}'**
  String pdfPageNumber(int page, int total);

  /// ⚠️ AFIRMACIÓN REGULATORIA. eIDAS y Ley 6/2020 son europeas. Necesita revisión legal antes de lanzar fuera de la UE.
  ///
  /// In es, this message translates to:
  /// **'Las firmas a continuación fueron realizadas mediante firma electrónica avanzada conforme al Reglamento eIDAS (UE) 910/2014 y la Ley 6/2020 española. Cada firma quedó registrada con fecha, hora, dispositivo y hash verificable en PactStream.'**
  String get pdfSignatureDisclaimer;

  /// No description provided for @pdfReportDocTitle.
  ///
  /// In es, this message translates to:
  /// **'Libro de la Obra · {displayId}'**
  String pdfReportDocTitle(String displayId);

  /// No description provided for @pdfReportDocSubject.
  ///
  /// In es, this message translates to:
  /// **'Expediente completo de obra con custodia por hitos'**
  String get pdfReportDocSubject;

  /// No description provided for @pdfReportTitle.
  ///
  /// In es, this message translates to:
  /// **'LIBRO DE LA OBRA'**
  String get pdfReportTitle;

  /// No description provided for @pdfReportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Expediente completo · PactStream'**
  String get pdfReportSubtitle;

  /// No description provided for @pdfReportHeaderBrand.
  ///
  /// In es, this message translates to:
  /// **'PactStream · Libro de la Obra'**
  String get pdfReportHeaderBrand;

  /// No description provided for @pdfReportLabelReference.
  ///
  /// In es, this message translates to:
  /// **'Referencia'**
  String get pdfReportLabelReference;

  /// No description provided for @pdfReportLabelProject.
  ///
  /// In es, this message translates to:
  /// **'Obra'**
  String get pdfReportLabelProject;

  /// No description provided for @pdfReportLabelLocation.
  ///
  /// In es, this message translates to:
  /// **'Localización'**
  String get pdfReportLabelLocation;

  /// No description provided for @pdfReportLabelType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get pdfReportLabelType;

  /// No description provided for @pdfReportMinorWork.
  ///
  /// In es, this message translates to:
  /// **'Obra menor (sin licencia)'**
  String get pdfReportMinorWork;

  /// No description provided for @pdfReportMajorWork.
  ///
  /// In es, this message translates to:
  /// **'Obra mayor'**
  String get pdfReportMajorWork;

  /// No description provided for @pdfReportLabelStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get pdfReportLabelStatus;

  /// No description provided for @pdfReportLabelGenerated.
  ///
  /// In es, this message translates to:
  /// **'Generado'**
  String get pdfReportLabelGenerated;

  /// No description provided for @pdfReportPartiesTitle.
  ///
  /// In es, this message translates to:
  /// **'Partes intervinientes'**
  String get pdfReportPartiesTitle;

  /// No description provided for @pdfReportHeaderRole.
  ///
  /// In es, this message translates to:
  /// **'Rol'**
  String get pdfReportHeaderRole;

  /// No description provided for @pdfReportHeaderName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get pdfReportHeaderName;

  /// No description provided for @pdfReportHeaderEmail.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get pdfReportHeaderEmail;

  /// No description provided for @pdfReportFinancialTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen financiero'**
  String get pdfReportFinancialTitle;

  /// No description provided for @pdfReportOriginalEstimate.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto original'**
  String get pdfReportOriginalEstimate;

  /// No description provided for @pdfReportChangeOrders.
  ///
  /// In es, this message translates to:
  /// **'Modificados (anexos activos)'**
  String get pdfReportChangeOrders;

  /// No description provided for @pdfReportEffectiveEstimate.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto efectivo'**
  String get pdfReportEffectiveEstimate;

  /// No description provided for @pdfReportAmountPaid.
  ///
  /// In es, this message translates to:
  /// **'Importe ejecutado y pagado'**
  String get pdfReportAmountPaid;

  /// No description provided for @pdfReportPendingPayment.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de pago'**
  String get pdfReportPendingPayment;

  /// No description provided for @pdfReportPercentComplete.
  ///
  /// In es, this message translates to:
  /// **'% Ejecutado'**
  String get pdfReportPercentComplete;

  /// No description provided for @pdfReportIvaIncluded.
  ///
  /// In es, this message translates to:
  /// **'incluido'**
  String get pdfReportIvaIncluded;

  /// No description provided for @pdfReportIvaExcluded.
  ///
  /// In es, this message translates to:
  /// **'no incluido'**
  String get pdfReportIvaExcluded;

  /// No description provided for @pdfReportIvaNote.
  ///
  /// In es, this message translates to:
  /// **'IVA {status} · tipo {rate}%'**
  String pdfReportIvaNote(String status, String rate);

  /// No description provided for @pdfReportTimelineTitle.
  ///
  /// In es, this message translates to:
  /// **'Cronología de la obra'**
  String get pdfReportTimelineTitle;

  /// No description provided for @pdfReportPactCreated.
  ///
  /// In es, this message translates to:
  /// **'Pacto creado'**
  String get pdfReportPactCreated;

  /// No description provided for @pdfReportEstimatedStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio estimado'**
  String get pdfReportEstimatedStart;

  /// No description provided for @pdfReportMilestonePaid.
  ///
  /// In es, this message translates to:
  /// **'Hito {ordinal} pagado · {amount}'**
  String pdfReportMilestonePaid(int ordinal, String amount);

  /// No description provided for @pdfReportAddendumActiveEvent.
  ///
  /// In es, this message translates to:
  /// **'Anexo #{ordinal} activo · {amount}'**
  String pdfReportAddendumActiveEvent(int ordinal, String amount);

  /// No description provided for @pdfReportEstimatedEnd.
  ///
  /// In es, this message translates to:
  /// **'Fin estimado'**
  String get pdfReportEstimatedEnd;

  /// No description provided for @pdfReportEstimatedSuffix.
  ///
  /// In es, this message translates to:
  /// **'(estimado)'**
  String get pdfReportEstimatedSuffix;

  /// No description provided for @pdfReportMilestonesTitle.
  ///
  /// In es, this message translates to:
  /// **'Hitos y certificaciones ({count})'**
  String pdfReportMilestonesTitle(int count);

  /// No description provided for @pdfReportHeaderDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get pdfReportHeaderDescription;

  /// No description provided for @pdfReportHeaderAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe'**
  String get pdfReportHeaderAmount;

  /// No description provided for @pdfReportHeaderPaid.
  ///
  /// In es, this message translates to:
  /// **'Pagado'**
  String get pdfReportHeaderPaid;

  /// No description provided for @pdfReportAddendumTitle.
  ///
  /// In es, this message translates to:
  /// **'Modificados y anexos ({count})'**
  String pdfReportAddendumTitle(int count);

  /// No description provided for @pdfReportHeaderTitleJustification.
  ///
  /// In es, this message translates to:
  /// **'Título / Justificación'**
  String get pdfReportHeaderTitleJustification;

  /// No description provided for @pdfReportHeaderExtraAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe extra'**
  String get pdfReportHeaderExtraAmount;

  /// No description provided for @pdfReportHeaderExtraDays.
  ///
  /// In es, this message translates to:
  /// **'Días extra'**
  String get pdfReportHeaderExtraDays;

  /// No description provided for @pdfReportSignaturesTitle.
  ///
  /// In es, this message translates to:
  /// **'Firmas verificadas'**
  String get pdfReportSignaturesTitle;

  /// No description provided for @pdfReportFooterDate.
  ///
  /// In es, this message translates to:
  /// **'Documento generado el {date} · uso confidencial'**
  String pdfReportFooterDate(String date);

  /// No description provided for @pdfReportFooterReference.
  ///
  /// In es, this message translates to:
  /// **'Expediente generado por PactStream · pactstream.es · Referencia: {displayId}'**
  String pdfReportFooterReference(String displayId);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case '419':
            return AppLocalizationsEs419();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
