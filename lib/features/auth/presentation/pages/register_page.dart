import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_language.dart';
import '../../../../core/i18n/l10n_extension.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/i18n/region_profile.dart';
import '../../../../core/i18n/widgets/language_picker.dart';
import '../../../../core/utils/error_humanizer.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/registration_data.dart';

/// Wizard de registro en 3 pasos (o 2 en modo invitación).
///
/// Step 1: idioma + país + datos personales (nombre, email, teléfono, pass).
/// Step 2: rol + datos profesionales/empresa (campos adaptados al país).
///         OMITIDO si se entra con [inviteToken] (modo invitación).
/// Step 3: consentimientos legales + crear cuenta.
///
/// El idioma se elige en el PASO 1, antes que nada: si alguien abre la app en
/// español sin entenderlo, lo primero que necesita es poder cambiarlo, no
/// llegar al final del wizard para descubrir que existe la opción.
///
/// Tras éxito → /verify-email donde se detecta verificación automáticamente.
/// En modo invitación, /verify-email recibe ?invite_token=xxx y al verificar
/// redirige a /org-invite?token=xxx para aceptar la invitación.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.inviteToken});

  /// Token de invitación de organización. Si está presente, el wizard
  /// arranca en "modo invitación": email pre-rellenado y bloqueado, sin
  /// paso de rol/empresa.
  final String? inviteToken;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final PageController _pageController = PageController();
  final RegistrationData _data = RegistrationData();
  int _currentStep = 0;
  bool _loading = false;
  String? _errorMessage;

  // Sprint 6 polish · Modo invitación.
  bool _previewLoading = false;
  Map<String, dynamic>? _invitePreview;

  /// Clave del error de invitación, no el texto. Guardar la cadena ya
  /// traducida la congelaría en el idioma que estuviera activo al cargar la
  /// preview, y el usuario puede cambiar de idioma justo después.
  _InviteError? _previewError;

  /// True si la página se abrió con `?invite_token=xxx` válido.
  bool get _inviteMode => _invitePreview != null;

  /// Número total de pasos del wizard (3 normal, 2 en modo invitación).
  int get _totalSteps => _inviteMode ? 2 : 3;

  @override
  void initState() {
    super.initState();
    // Semilla: el idioma con el que arrancó la app decide el país por defecto.
    _data.language = ref.read(appLanguageProvider);
    _data.region = RegionProfile.seedFor(_data.language);

    if (widget.inviteToken != null && widget.inviteToken!.isNotEmpty) {
      _loadInvitePreview();
    }
  }

  Future<void> _loadInvitePreview() async {
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final res = await SupabaseConfig.client.rpc(
        'sf_get_invite_preview',
        params: {'p_token': widget.inviteToken},
      );
      final data = (res is Map)
          ? Map<String, dynamic>.from(res as Map)
          : <String, dynamic>{};
      if (!mounted) return;

      final valid = (data['valid'] as bool?) ?? false;
      if (!valid) {
        setState(() {
          _previewLoading = false;
          _previewError = _InviteError.revoked;
        });
        return;
      }

      // Pre-rellenar datos del invitado.
      _data.email = (data['invited_email'] as String?) ?? '';
      final fullName = (data['full_name'] as String?) ?? '';
      if (fullName.isNotEmpty) {
        _data.fullName = fullName;
      }
      // En modo invitación no recoge rol/empresa: forzamos valores
      // mínimos para que las validaciones step2 ya no apliquen.
      // step1Valid sólo exige email+phone+pass; el rol queda null.
      setState(() {
        _previewLoading = false;
        _invitePreview = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewError = _InviteError.loadFailed;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // En modo invitación sólo hay 2 pasos visibles (step1 y step3); el
    // PageView sigue teniendo 2 hijos, así que el índice se mueve
    // linealmente. En modo normal son 3.
    final lastIndex = _totalSteps - 1;
    if (_currentStep < lastIndex) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // En modo invitación los datos profesionales no aplican; sólo
      // mandamos lo esencial. La propia metadata incluye el token para
      // que verify-email pueda redirigir a /org-invite tras verificar.
      //
      // `locale` y `country_iso` van SIEMPRE, en los dos modos: la fila de
      // `public.users` la crea el trigger `handle_new_auth_user` a partir de
      // esta metadata, y es la única oportunidad de fijar el idioma antes de
      // que existan sesión y perfil.
      final metadata = <String, dynamic>{
        'full_name': _data.fullName.trim(),
        'phone_e164': _data.phoneE164,
        'terms_version': RegistrationData.termsVersion,
        'privacy_version': RegistrationData.privacyVersion,
        'locale': _data.language.code,
        'country_iso': _data.region.countryIso,
      };

      if (_inviteMode) {
        metadata['invitation_token'] = widget.inviteToken;
        metadata['signup_origin'] = 'org_invite';
      } else {
        metadata.addAll(<String, dynamic>{
          'primary_role': _data.role,
          'organization_name': _data.organizationName.trim().isEmpty
              ? null
              : _data.organizationName.trim(),
          'cif_or_nif':
              _data.cifOrNif.trim().isEmpty ? null : _data.cifOrNif.trim(),
          'province':
              _data.province.trim().isEmpty ? null : _data.province.trim(),
          'profession':
              _data.profession.trim().isEmpty ? null : _data.profession.trim(),
          'colegio':
              _data.colegio.trim().isEmpty ? null : _data.colegio.trim(),
          'num_colegiacion': _data.numColegiacion.trim().isEmpty
              ? null
              : _data.numColegiacion.trim(),
        });
      }

      final response = await SupabaseConfig.client.auth.signUp(
        email: _data.email.trim(),
        password: _data.password,
        data: metadata,
      );

      if (response.user == null) {
        throw Exception(context.l10n.registerCouldNotCreate);
      }

      if (!mounted) return;
      // En modo invitación pasamos el token a verify-email para que tras
      // confirmar el correo se vaya directo a /org-invite.
      if (_inviteMode) {
        context.go(
          '${AppRoutes.verifyEmail}?invite_token=${widget.inviteToken}',
        );
      } else {
        context.go(AppRoutes.verifyEmail);
      }
    } catch (e) {
      setState(() => _errorMessage = humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canContinue {
    if (_inviteMode) {
      // En modo invitación: step1 (datos personales) + step3 (consents).
      // El índice del PageView en modo invitación va 0 → 1.
      return switch (_currentStep) {
        0 => _data.step1Valid,
        1 => _data.step3Valid,
        _ => false,
      };
    }
    return switch (_currentStep) {
      0 => _data.step1Valid,
      1 => _data.step2Valid,
      2 => _data.step3Valid,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Cambiar el idioma re-siembra el país mientras el usuario no lo haya
    // tocado a mano. Quien pasa la app a inglés espera ver "+1" y "State", no
    // seguir con "+34" y "Provincia".
    ref.listen<AppLanguage>(appLanguageProvider, (previous, next) {
      setState(() {
        _data.language = next;
        if (!_countryTouched) {
          _data.region = RegionProfile.seedFor(next);
        }
      });
    });

    // Si todavía cargamos la preview de la invitación, mostramos loader.
    if (_previewLoading) {
      return Scaffold(
        backgroundColor: context.colors.scaffold,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Si la preview falló o la invitación no es válida, mostramos error
    // con CTA a registro normal.
    if (widget.inviteToken != null && _previewError != null) {
      return _InvalidInviteScreen(
        message: _previewError!.message(l10n),
        onGoToNormalRegister: () => context.go(AppRoutes.register),
        onGoToLogin: () => context.go(AppRoutes.login),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
          onPressed: _previousStep,
        ),
        title: Text(
            l10n.registerStepIndicator(_currentStep + 1, _totalSteps),
            style: AppTypography.h3.copyWith(color: AppColors.white)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner contextual en modo invitación
            if (_inviteMode) _InviteContextBanner(preview: _invitePreview!),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: List.generate(_totalSteps, (i) {
                  final active = i <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                          right: i < _totalSteps - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active ? AppColors.psCyan : context.colors.border,
                        borderRadius: AppRadius.xxsAll,
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _inviteMode
                    ? [
                        _Step1PersonalInfo(
                          data: _data,
                          onChanged: () => setState(() {}),
                          onCountryChanged: _onCountryChanged,
                          emailLocked: true,
                        ),
                        _Step3LegalConsents(
                            data: _data, onChanged: () => setState(() {})),
                      ]
                    : [
                        _Step1PersonalInfo(
                            data: _data,
                            onChanged: () => setState(() {}),
                            onCountryChanged: _onCountryChanged),
                        _Step2RoleAndProfessional(
                            data: _data,
                            onChanged: () => setState(() {})),
                        _Step3LegalConsents(
                            data: _data, onChanged: () => setState(() {})),
                      ],
              ),
            ),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.errorBg,
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTypography.bodyS.copyWith(color: AppColors.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ElevatedButton(
                onPressed: (_canContinue && !_loading) ? _nextStep : null,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(_currentStep == _totalSteps - 1
                        ? l10n.registerCreateAccountCta
                        : l10n.commonNext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Una vez el usuario elige país a mano, cambiar de idioma ya no lo pisa.
  bool _countryTouched = false;

  void _onCountryChanged(RegionProfile region) {
    setState(() {
      _countryTouched = true;
      _data.region = region;
    });
  }
}

/// Motivos por los que una invitación no se puede usar. Se guarda el motivo y
/// no el texto para que el mensaje se renderice en el idioma ACTUAL.
enum _InviteError {
  revoked,
  loadFailed;

  String message(AppLocalizations l10n) => switch (this) {
        _InviteError.revoked => l10n.inviteInvalidRevoked,
        _InviteError.loadFailed => l10n.inviteInvalidLoadFailed,
      };
}

// =====================================================================
// Step 1 · Idioma, país y datos personales
// =====================================================================

class _Step1PersonalInfo extends StatelessWidget {
  const _Step1PersonalInfo({
    required this.data,
    required this.onChanged,
    required this.onCountryChanged,
    this.emailLocked = false,
  });

  final RegistrationData data;
  final VoidCallback onChanged;
  final ValueChanged<RegionProfile> onCountryChanged;

  /// En modo invitación el email viene fijado por la fila de
  /// organization_members y no debe editarse para que no rompa la
  /// validación de `sf_accept_org_invite`.
  final bool emailLocked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.registerStep1Title, style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.registerStep1Subtitle,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Idioma primero: es lo único que el usuario puede necesitar cambiar
          // ANTES de poder leer el resto del formulario.
          const LanguagePicker(),
          const SizedBox(height: AppSpacing.xl),

          TextFormField(
            initialValue: data.fullName,
            decoration: InputDecoration(
              labelText: l10n.registerFullNameLabel,
              hintText: l10n.registerFullNameHint,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (v) {
              data.fullName = v;
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: ValueKey('email-${data.email}-$emailLocked'),
            initialValue: data.email,
            readOnly: emailLocked,
            enabled: !emailLocked,
            decoration: InputDecoration(
              labelText: l10n.loginEmailLabel,
              hintText: l10n.loginEmailHint,
              prefixIcon: const Icon(Icons.mail_outline),
              suffixIcon: emailLocked
                  ? const Icon(Icons.lock_outline, size: 18)
                  : null,
              helperText:
                  emailLocked ? l10n.registerEmailLockedHelper : null,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: emailLocked
                ? null
                : (v) {
                    data.email = v.trim();
                    onChanged();
                  },
          ),
          const SizedBox(height: AppSpacing.lg),

          // País: gobierna moneda, identificación fiscal y prefijo telefónico.
          _CountryField(
            selected: data.region,
            onChanged: onCountryChanged,
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border, width: 1.5),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  // Prefijo derivado del país seleccionado, no "+34" fijo.
                  // +58 Venezuela, +503 El Salvador, +507 Panamá…
                  '${data.region.flagEmoji} ${data.region.dialCode}',
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700, color: context.colors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  key: ValueKey('phone-${data.region.countryIso}'),
                  initialValue: data.phoneNational,
                  decoration: InputDecoration(
                    labelText: l10n.registerPhoneLabel,
                    hintText: data.region.phoneHint,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    // Se admiten los separadores que la gente teclea de forma
                    // natural en cada país — "600 000 000" y "(555) 010-0199" —
                    // y se limpian al componer el E.164.
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()\-]')),
                  ],
                  onChanged: (v) {
                    data.phoneNational = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _PasswordField(data: data, onChanged: onChanged),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.registerLegalPreview,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Selector de país. Determina moneda, identificación fiscal y prefijo.
class _CountryField extends StatelessWidget {
  const _CountryField({required this.selected, required this.onChanged});

  final RegionProfile selected;
  final ValueChanged<RegionProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DropdownButtonFormField<RegionProfile>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: l10n.regionCountryLabel,
        helperText: l10n.regionCountryHelper,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.public_outlined),
      ),
      // `pickerOrder`, no `values`: primero los mercados que CostPact tiene
      // realmente sembrados en `pais_config` (ES, VE, SV). Un país que solo
      // funciona en una de las dos apps no debe encabezar la lista.
      items: RegionProfile.pickerOrder
          .map((region) => DropdownMenuItem(
                value: region,
                child: Text(
                    '${region.flagEmoji}  ${region.countryName(l10n)}'),
              ))
          .toList(),
      onChanged: (region) {
        if (region != null) onChanged(region);
      },
    );
  }
}

/// Campo de contraseña con toggle de visibilidad (mismo patrón que login).
class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.data, required this.onChanged});

  final RegistrationData data;
  final VoidCallback onChanged;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextFormField(
      initialValue: widget.data.password,
      decoration: InputDecoration(
        labelText: l10n.loginPasswordLabel,
        hintText: l10n.loginPasswordHint,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          tooltip:
              _obscure ? l10n.loginShowPassword : l10n.loginHidePassword,
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onChanged: (v) {
        widget.data.password = v;
        widget.onChanged();
      },
    );
  }
}

// =====================================================================
// Step 2 · Rol y datos profesionales
// =====================================================================

class _Step2RoleAndProfessional extends StatelessWidget {
  const _Step2RoleAndProfessional({required this.data, required this.onChanged});

  final RegistrationData data;
  final VoidCallback onChanged;

  /// Los VALORES (`promotor`, `constructor`, `tecnico`) son claves de dominio
  /// que viajan a la base de datos y NO se traducen nunca. Solo cambia su
  /// etiqueta: en inglés norteamericano un `promotor` es el "Owner" y un
  /// `tecnico` es el "Architect / Engineer" que certifica la obra.
  static List<_RoleOption> _roles(AppLocalizations l10n) => [
        _RoleOption(
          value: 'promotor',
          icon: Icons.home_outlined,
          title: l10n.roleOwnerTitle,
          subtitle: l10n.roleOwnerSubtitle,
        ),
        _RoleOption(
          value: 'constructor',
          icon: Icons.construction_outlined,
          title: l10n.roleContractorTitle,
          subtitle: l10n.roleContractorSubtitle,
        ),
        _RoleOption(
          value: 'tecnico',
          icon: Icons.architecture_outlined,
          title: l10n.roleArchitectTitle,
          subtitle: l10n.roleArchitectSubtitle,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.registerStep2Title, style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.registerStep2Subtitle,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          ..._roles(l10n).map((role) => _RoleCard(
                option: role,
                selected: data.role == role.value,
                onTap: () {
                  data.role = role.value;
                  onChanged();
                },
              )),
          const SizedBox(height: AppSpacing.xl),
          if (data.role != null) _buildRoleSpecificFields(context, l10n),
        ],
      ),
    );
  }

  Widget _buildRoleSpecificFields(
      BuildContext context, AppLocalizations l10n) {
    final region = data.region;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.registerProfessionalDataTitle,
            style: AppTypography.h3.copyWith(fontSize: 16)),
        const SizedBox(height: AppSpacing.md),
        if (data.role == 'constructor') ...[
          TextFormField(
            initialValue: data.organizationName,
            decoration: InputDecoration(
              labelText: l10n.registerCompanyNameLabel,
              hintText: l10n.registerCompanyNameHint,
              prefixIcon: const Icon(Icons.business_outlined),
            ),
            onChanged: (v) {
              data.organizationName = v;
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: ValueKey('company-tax-${region.countryIso}'),
            initialValue: data.cifOrNif,
            decoration: InputDecoration(
              // CIF en España, RIF en Venezuela, NIT en El Salvador, EIN en
              // EE. UU. — el documento cambia con el país, no con el idioma.
              labelText: region.companyTaxIdLabel(l10n),
              hintText: region.companyTaxIdHint,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            onChanged: (v) {
              data.cifOrNif = v.toUpperCase();
              onChanged();
            },
          ),
        ] else if (data.role == 'tecnico') ...[
          TextFormField(
            key: ValueKey('tax-${region.countryIso}'),
            initialValue: data.cifOrNif,
            decoration: InputDecoration(
              labelText: region.taxIdLabel(l10n),
              hintText: region.personalTaxIdHint,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            onChanged: (v) {
              data.cifOrNif = v.toUpperCase();
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: ValueKey('board-${region.countryIso}'),
            initialValue: data.colegio,
            decoration: InputDecoration(
              labelText: region.licenseBoardLabel(l10n),
              hintText: region.licenseBoardHint,
              prefixIcon: const Icon(Icons.school_outlined),
            ),
            onChanged: (v) {
              data.colegio = v;
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: ValueKey('license-${region.countryIso}'),
            initialValue: data.numColegiacion,
            decoration: InputDecoration(
              labelText: region.licenseNumberLabel(l10n),
              hintText: region.licenseNumberHint,
              prefixIcon: const Icon(Icons.numbers_outlined),
            ),
            onChanged: (v) {
              data.numColegiacion = v;
              onChanged();
            },
          ),
        ] else if (data.role == 'promotor') ...[
          TextFormField(
            key: ValueKey('tax-owner-${region.countryIso}'),
            initialValue: data.cifOrNif,
            decoration: InputDecoration(
              labelText: region.taxIdLabel(l10n),
              hintText: region.personalTaxIdHint,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            onChanged: (v) {
              data.cifOrNif = v.toUpperCase();
              onChanged();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          key: ValueKey('area-${region.countryIso}'),
          initialValue: data.province,
          decoration: InputDecoration(
            // "Provincia" en España, "State" en EE. UU.
            labelText: region.adminAreaLabel(l10n),
            hintText: region.adminAreaHint,
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          onChanged: (v) {
            data.province = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: selected ? context.colors.brandAccent : context.colors.border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.infoBg,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(option.icon, color: context.colors.brandAccent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title.toUpperCase(),
                        style: AppTypography.h3.copyWith(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(option.subtitle,
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textTertiary)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: context.colors.brandAccent),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Step 3 · Consentimientos legales
// =====================================================================

class _Step3LegalConsents extends StatelessWidget {
  const _Step3LegalConsents({required this.data, required this.onChanged});

  final RegistrationData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.registerStep3Title, style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.registerStep3Subtitle,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Resumen
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: AppRadius.lgAll,
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.registerSummaryTitle,
                    style: AppTypography.h3.copyWith(fontSize: 16)),
                const Divider(height: 24),
                _SummaryRow(
                    icon: Icons.person_outline,
                    label: l10n.registerSummaryName,
                    value: data.fullName),
                _SummaryRow(
                    icon: Icons.mail_outline,
                    label: l10n.registerSummaryEmail,
                    value: data.email),
                _SummaryRow(
                    icon: Icons.phone_outlined,
                    label: l10n.registerSummaryPhone,
                    value: data.phoneE164),
                _SummaryRow(
                    icon: Icons.work_outline,
                    label: l10n.registerSummaryRole,
                    value: _roleLabel(l10n) ?? l10n.commonNotAvailable),
                // El idioma entra en el resumen a propósito: es una elección
                // que el usuario hizo hace tres pantallas y que determina en
                // qué idioma recibirá los emails de la plataforma.
                _SummaryRow(
                    icon: Icons.language_outlined,
                    label: l10n.registerSummaryLanguage,
                    value: data.language.nativeName),
                if (data.organizationName.isNotEmpty)
                  _SummaryRow(
                      icon: Icons.business_outlined,
                      label: l10n.registerSummaryCompany,
                      value: data.organizationName),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Consentimientos
          _ConsentRow(
            checked: data.acceptedTerms,
            onChanged: (v) {
              data.acceptedTerms = v ?? false;
              onChanged();
            },
            label: l10n.registerAcceptThe,
            linkLabel: l10n.registerTermsLink,
            linkUrl: AppConstants.termsUrl,
          ),
          const SizedBox(height: AppSpacing.md),
          _ConsentRow(
            checked: data.acceptedPrivacy,
            onChanged: (v) {
              data.acceptedPrivacy = v ?? false;
              onChanged();
            },
            label: l10n.registerAcceptThePrivacy,
            linkLabel: l10n.registerPrivacyLink,
            linkUrl: AppConstants.privacyUrl,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.registerKycNotice,
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }

  /// Etiqueta traducida del rol. El valor crudo (`promotor`) nunca se muestra:
  /// antes se pintaba `data.role!.toUpperCase()`, que en inglés dejaba un
  /// "PROMOTOR" sin sentido en mitad del resumen.
  String? _roleLabel(AppLocalizations l10n) => switch (data.role) {
        'promotor' => l10n.roleOwnerTitle,
        'constructor' => l10n.roleContractorTitle,
        'tecnico' => l10n.roleArchitectTitle,
        _ => null,
      };
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.colors.brandAccent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: context.colors.textTertiary)),
                Text(value, style: AppTypography.body.copyWith(color: context.colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatefulWidget {
  const _ConsentRow({
    required this.checked,
    required this.onChanged,
    required this.label,
    required this.linkLabel,
    required this.linkUrl,
  });

  final bool checked;
  final ValueChanged<bool?> onChanged;
  final String label;
  final String linkLabel;
  final String linkUrl;

  @override
  State<_ConsentRow> createState() => _ConsentRowState();
}

class _ConsentRowState extends State<_ConsentRow> {
  late final TapGestureRecognizer _linkRecognizer;

  @override
  void initState() {
    super.initState();
    _linkRecognizer = TapGestureRecognizer()..onTap = _openLink;
  }

  @override
  void dispose() {
    _linkRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    final ok = await launchUrl(
      Uri.parse(widget.linkUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content:
              Text(context.l10n.registerLinkOpenFailed(widget.linkUrl)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => widget.onChanged(!widget.checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: widget.checked,
              onChanged: widget.onChanged,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.microAll,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    text: '${widget.label} ',
                    style: AppTypography.body,
                    children: [
                      TextSpan(
                        text: widget.linkLabel,
                        recognizer: _linkRecognizer,
                        semanticsLabel: context.l10n
                            .registerLinkOpensBrowser(widget.linkLabel),
                        style: AppTypography.body.copyWith(
                          color: context.colors.brandAccent,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Sprint 6 polish · Widgets de modo invitación
// =====================================================================

/// Banner contextual que aparece en la parte superior del wizard cuando
/// el usuario llegó por un link de invitación válido.
class _InviteContextBanner extends StatelessWidget {
  const _InviteContextBanner({required this.preview});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orgName = (preview['org_name'] as String?) ?? l10n.inviteFallbackOrg;
    final inviter =
        (preview['inviter_name'] as String?) ?? l10n.inviteFallbackInviter;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.borderSubtle,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.psNavy,
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(Icons.groups_2_outlined,
                color: AppColors.psCyan, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.inviteBannerTitle,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  l10n.inviteBannerBody(inviter, orgName),
                  style: AppTypography.bodyS
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla a mostrar cuando llegamos con un invite_token pero la preview
/// dice que ya no es válido.
class _InvalidInviteScreen extends StatelessWidget {
  const _InvalidInviteScreen({
    required this.message,
    required this.onGoToNormalRegister,
    required this.onGoToLogin,
  });

  final String message;
  final VoidCallback onGoToNormalRegister;
  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: context.colors.errorBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_off,
                      color: AppColors.error, size: 48),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.inviteInvalidTitle,
                    style: AppTypography.h2, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: onGoToNormalRegister,
                  child: Text(l10n.inviteGoToNormalRegister),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onGoToLogin,
                  child: Text(l10n.inviteGoToLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
