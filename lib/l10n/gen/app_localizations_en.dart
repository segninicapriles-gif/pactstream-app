// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PactStream';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonNext => 'Next →';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOr => 'or';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonNotAvailable => '—';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSelectorTitle => 'Choose your language';

  @override
  String get languageSelectorSubtitle =>
      'You can change this any time from your profile.';

  @override
  String get languageChanged => 'Language updated';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Sign in to manage your projects';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'you@email.com';

  @override
  String get loginEmailEmpty => 'Enter your email';

  @override
  String get loginEmailInvalid => 'That email doesn’t look right';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'At least 8 characters';

  @override
  String get loginPasswordEmpty => 'Enter your password';

  @override
  String get loginPasswordTooShort => 'At least 8 characters';

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get loginCreateAccount => 'Create an account';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get resetTitle => 'Reset password';

  @override
  String get resetBody => 'We’ll email you a link to reset your password.';

  @override
  String get resetSend => 'Send link';

  @override
  String get resetSent => 'Check your inbox — we sent you a reset link.';

  @override
  String get resetFailed => 'We couldn’t send the email. Try again.';

  @override
  String registerStepIndicator(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get registerCreateAccountCta => 'Create my account';

  @override
  String get registerStep1Title => 'Create your account';

  @override
  String get registerStep1Subtitle => 'Personal details';

  @override
  String get registerFullNameLabel => 'Full name';

  @override
  String get registerFullNameHint => 'e.g. Jordan Miller';

  @override
  String get registerEmailLockedHelper =>
      'Your team invited you at this email, so it can’t be changed.';

  @override
  String get registerPhoneLabel => 'Phone';

  @override
  String get registerLegalPreview =>
      'You’ll review the legal terms on the last step. We don’t create your account until you accept them.';

  @override
  String get registerStep2Title => 'Set up your profile';

  @override
  String get registerStep2Subtitle => 'Choose your role on PactStream';

  @override
  String get registerProfessionalDataTitle => 'Professional details';

  @override
  String get roleOwnerTitle => 'Owner';

  @override
  String get roleOwnerSubtitle =>
      'I’m funding a project and want my money protected';

  @override
  String get roleContractorTitle => 'General contractor';

  @override
  String get roleContractorSubtitle =>
      'I build projects and want payment guaranteed';

  @override
  String get roleArchitectTitle => 'Architect / Engineer';

  @override
  String get roleArchitectSubtitle =>
      'I administer projects and certify progress';

  @override
  String get registerCompanyNameLabel => 'Company name';

  @override
  String get registerCompanyNameHint => 'e.g. Miller Construction LLC';

  @override
  String get registerStep3Title => 'Review your details';

  @override
  String get registerStep3Subtitle =>
      'Check everything before we create your account';

  @override
  String get registerSummaryTitle => 'Profile summary';

  @override
  String get registerSummaryName => 'Name';

  @override
  String get registerSummaryEmail => 'Email';

  @override
  String get registerSummaryPhone => 'Phone';

  @override
  String get registerSummaryRole => 'Role';

  @override
  String get registerSummaryCompany => 'Company';

  @override
  String get registerSummaryLanguage => 'Language';

  @override
  String get registerAcceptThe => 'I accept the';

  @override
  String get registerTermsLink => 'Terms and Conditions';

  @override
  String get registerAcceptThePrivacy => 'I accept the';

  @override
  String get registerPrivacyLink => 'Privacy Policy';

  @override
  String registerLinkOpensBrowser(String linkLabel) {
    return '$linkLabel (opens in your browser)';
  }

  @override
  String get registerKycNotice =>
      'We’ll verify your identity on the next step, as required by anti-money-laundering regulations (KYC).';

  @override
  String get registerCouldNotCreate => 'We couldn’t create your account';

  @override
  String registerLinkOpenFailed(String url) {
    return 'We couldn’t open that document. You can read it at $url';
  }

  @override
  String get inviteBannerTitle => 'You’re joining as a team member';

  @override
  String inviteBannerBody(String inviter, String org) {
    return '$inviter invited you to the $org team. We only need your personal details — your team already set the company and role.';
  }

  @override
  String get inviteFallbackOrg => 'an organization';

  @override
  String get inviteFallbackInviter => 'Your team';

  @override
  String get inviteInvalidTitle => 'Invitation unavailable';

  @override
  String get inviteInvalidRevoked =>
      'This invitation is no longer valid — it may have been revoked, or you may have already accepted it.';

  @override
  String get inviteInvalidLoadFailed =>
      'We couldn’t load this invitation. Click the link in your email again, or ask your team for a new invite.';

  @override
  String get inviteGoToNormalRegister => 'Create a regular account';

  @override
  String get inviteGoToLogin => 'I already have an account · Sign in';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingWelcomeTitle => 'Welcome to PactStream';

  @override
  String get onboardingWelcomeBody =>
      'The platform that builds trust into every construction project.';

  @override
  String get onboardingWorksTitle => 'Run your projects';

  @override
  String get onboardingWorksBody =>
      'Create contracts, invite the other parties, and track every milestone.';

  @override
  String get onboardingPaymentsTitle => 'Secure payments';

  @override
  String get onboardingPaymentsBody =>
      'Funds held in escrow, backed by a surety bond from a leading insurer. Money is released once the work is approved.';

  @override
  String get onboardingReputationTitle => 'Your track record counts';

  @override
  String get onboardingReputationBody =>
      'Build your Trust Score with every project you deliver. Your history is your best credential.';

  @override
  String get kycIntroTitle => 'Verify your identity';

  @override
  String get kycIntroBody =>
      'To sign agreements and move money, we need to confirm who you are. It takes 2 minutes.';

  @override
  String get kycBulletEscrowTitle => 'Regulated escrow';

  @override
  String get kycBulletEscrowBody =>
      'Your funds are held in escrow under a European payment license (Mangopay).';

  @override
  String get kycBulletSignatureTitle => 'Legally binding eIDAS signature';

  @override
  String get kycBulletSignatureBody =>
      'Your agreement holds up in court (Signaturit).';

  @override
  String get kycBulletTrustTitle => 'Trust for all three parties';

  @override
  String get kycBulletTrustBody => 'Owner, architect, and general contractor.';

  @override
  String get kycStartCta => 'Start verification';

  @override
  String get kycLaterCta => 'I’ll do this later';

  @override
  String get kycProviderNote =>
      'Identity verification handled by Veriff, a certified European provider.';

  @override
  String get kycCaptureAppBarTitle => 'Identity verification';

  @override
  String get kycCaptureTitle => 'Verify your identity with Veriff';

  @override
  String get kycCaptureBody =>
      'You’ll need a government-issued photo ID or passport, plus your device camera. Takes 2–3 minutes.';

  @override
  String get kycStep1Title => 'Photo of your ID';

  @override
  String get kycStep1Body =>
      'Government-issued ID or passport. Veriff checks that it’s genuine.';

  @override
  String get kycStep2Title => 'Selfie with liveness check';

  @override
  String get kycStep2Body => 'Look at the camera and follow the prompts.';

  @override
  String get kycStep3Title => 'Result in 30–60 seconds';

  @override
  String get kycStep3Body =>
      'If everything checks out, you get into the app right away.';

  @override
  String get kycStartSessionCta => 'Start verification';

  @override
  String get kycCreatingSession => 'Creating session…';

  @override
  String get kycWaitingTitle => 'Waiting on Veriff…';

  @override
  String get kycWaitingBody =>
      'Finish the verification in the tab that opened. Come back here when you’re done — we’ll pick up the result automatically.';

  @override
  String get kycReopenVeriff => 'Reopen Veriff verification';

  @override
  String get kycCheckStatusNow => 'Check status now';

  @override
  String get kycCancelAndBack => 'Cancel and go back';

  @override
  String get kycStillProcessing => 'Still processing. Give it a few seconds.';

  @override
  String get kycTimeoutTitle => 'This is taking longer than usual';

  @override
  String get kycTimeoutBody =>
      'Veriff hasn’t confirmed the result yet. You can keep using the app and come back later — we’ll let you know when verification finishes — or check again now.';

  @override
  String get kycContinueLater => 'Continue later';

  @override
  String get kycErrorNoSessionUrl => 'Veriff didn’t return a session URL.';

  @override
  String get kycErrorCannotOpenUrl =>
      'We couldn’t open the Veriff verification window.';

  @override
  String get kycVerifiedTitle => 'Identity verified';

  @override
  String get kycVerifiedBody =>
      'You can now sign agreements and move money in escrow.';

  @override
  String get kycVerifiedAtLabel => 'Verified on';

  @override
  String get kycValidatedByLabel => 'Verified by';

  @override
  String get kycOperationsLabel => 'Transactions';

  @override
  String get kycOperationsAvailable => 'Enabled ✓';

  @override
  String get kycContinueHome => 'Continue to home';

  @override
  String get kycPendingTitle => 'Review in progress';

  @override
  String get kycPendingBody =>
      'We got your documents. An agent will review your identity within 24 hours.';

  @override
  String get kycReceivedLabel => 'Received';

  @override
  String get kycMaxDeadlineLabel => 'Turnaround';

  @override
  String get kycMaxDeadlineValue => '24 business hours';

  @override
  String get kycOperationsLimited => 'Limited until approved';

  @override
  String get kycPendingNotice =>
      'We’ll email you and send a notification when it’s ready.';

  @override
  String get kycBackHome => 'Back to home';

  @override
  String get kycRejectedTitle => 'Verification declined';

  @override
  String get kycRejectedBody =>
      'We couldn’t verify your identity with the documents you provided.';

  @override
  String get kycRejectedReasonLabel => 'Reason';

  @override
  String get kycRejectedReasonDefault =>
      'The document was unreadable or expired. Try again with a valid, clearly legible document.';

  @override
  String get kycRetryCta => 'Try again';

  @override
  String regionTaxIdLabel(String document) {
    return 'Taxpayer ID ($document)';
  }

  @override
  String regionCompanyTaxIdLabel(String document) {
    return 'Company tax ID ($document)';
  }

  @override
  String get regionLicenseBoard => 'Licensing board';

  @override
  String get regionLicenseNumber => 'License number';

  @override
  String get adminAreaProvince => 'Province';

  @override
  String get adminAreaState => 'State';

  @override
  String get adminAreaDepartment => 'Department';

  @override
  String get adminAreaRegion => 'Region';

  @override
  String get adminAreaDistrict => 'District';

  @override
  String get regionCountryLabel => 'Country';

  @override
  String get regionCountryHelper =>
      'Sets your currency, your tax ID format, and how amounts are displayed.';

  @override
  String get countryES => 'Spain';

  @override
  String get countryVE => 'Venezuela';

  @override
  String get countrySV => 'El Salvador';

  @override
  String get countryMX => 'Mexico';

  @override
  String get countryCO => 'Colombia';

  @override
  String get countryPE => 'Peru';

  @override
  String get countryCL => 'Chile';

  @override
  String get countryAR => 'Argentina';

  @override
  String get countryPA => 'Panama';

  @override
  String get countryUS => 'United States';

  @override
  String get countryPT => 'Portugal';
}
