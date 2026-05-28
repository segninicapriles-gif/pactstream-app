import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/registration_data.dart';

/// Wizard de registro en 3 pasos (o 2 en modo invitación).
///
/// Step 1: datos personales (nombre, email, teléfono, contraseña).
/// Step 2: rol + datos profesionales/empresa (campos adaptados).
///         OMITIDO si se entra con [inviteToken] (modo invitación).
/// Step 3: consentimientos legales + crear cuenta.
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
  String? _previewError;

  /// True si la página se abrió con `?invite_token=xxx` válido.
  bool get _inviteMode => _invitePreview != null;

  /// Número total de pasos del wizard (3 normal, 2 en modo invitación).
  int get _totalSteps => _inviteMode ? 2 : 3;

  @override
  void initState() {
    super.initState();
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
          _previewError = 'La invitación ya no es válida (puede que la '
              'hayan revocado o ya la hayas aceptado).';
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
        _previewError = 'No se pudo cargar la invitación. Vuelve a hacer '
            'clic en el link del email o pide una nueva invitación.';
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
      final metadata = <String, dynamic>{
        'full_name': _data.fullName.trim(),
        'phone_e164': _data.phoneE164,
        'terms_version': RegistrationData.termsVersion,
        'privacy_version': RegistrationData.privacyVersion,
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
        throw Exception('No se pudo crear la cuenta');
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
      // Mostrar el error real para facilitar debugging en desarrollo.
      // En producción, sustituir por _humanizeError(e.toString()).
      setState(() => _errorMessage = e.toString());
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
        message: _previewError!,
        onGoToNormalRegister: () => context.go(AppRoutes.register),
        onGoToLogin: () => context.go(AppRoutes.login),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
        title: Text('Paso ${_currentStep + 1} de $_totalSteps',
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
                          emailLocked: true,
                        ),
                        _Step3LegalConsents(
                            data: _data, onChanged: () => setState(() {})),
                      ]
                    : [
                        _Step1PersonalInfo(
                            data: _data,
                            onChanged: () => setState(() {})),
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
                    : Text(_currentStep == _totalSteps - 1 ? 'Crear mi cuenta' : 'Siguiente →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Step 1 · Datos personales
// =====================================================================

class _Step1PersonalInfo extends StatelessWidget {
  const _Step1PersonalInfo({
    required this.data,
    required this.onChanged,
    this.emailLocked = false,
  });

  final RegistrationData data;
  final VoidCallback onChanged;

  /// En modo invitación el email viene fijado por la fila de
  /// organization_members y no debe editarse para que no rompa la
  /// validación de `sf_accept_org_invite`.
  final bool emailLocked;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Crea tu cuenta', style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Datos personales',
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            initialValue: data.fullName,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              hintText: 'Ej: Juan Pérez',
              prefixIcon: Icon(Icons.person_outline),
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
              labelText: 'Email',
              hintText: 'tu@email.com',
              prefixIcon: const Icon(Icons.mail_outline),
              suffixIcon: emailLocked
                  ? const Icon(Icons.lock_outline, size: 18)
                  : null,
              helperText: emailLocked
                  ? 'Tu equipo te invitó con este email; no se puede cambiar.'
                  : null,
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
                  'ES +34',
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700, color: context.colors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  initialValue: data.phoneE164.replaceFirst('+34', ''),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '600 000 000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                  ],
                  onChanged: (v) {
                    final cleaned = v.replaceAll(' ', '');
                    data.phoneE164 = '+34$cleaned';
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            initialValue: data.password,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Mínimo 8 caracteres',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (v) {
              data.password = v;
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Al continuar verás los términos legales en el último paso. No creamos la cuenta hasta que los aceptes.',
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
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

  static const _roles = <_RoleOption>[
    _RoleOption(
      value: 'promotor',
      icon: Icons.home_outlined,
      title: 'Promotor',
      subtitle: 'Quiero financiar una obra con seguridad',
    ),
    _RoleOption(
      value: 'constructor',
      icon: Icons.construction_outlined,
      title: 'Constructor',
      subtitle: 'Ejecuto obras y quiero cobrar garantizado',
    ),
    _RoleOption(
      value: 'tecnico',
      icon: Icons.architecture_outlined,
      title: 'Técnico',
      subtitle: 'Dirijo obras y valido hitos',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Configura tu perfil', style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Selecciona tu rol en PactStream',
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          ..._roles.map((role) => _RoleCard(
                option: role,
                selected: data.role == role.value,
                onTap: () {
                  data.role = role.value;
                  onChanged();
                },
              )),
          const SizedBox(height: AppSpacing.xl),
          if (data.role != null) _buildRoleSpecificFields(context),
        ],
      ),
    );
  }

  Widget _buildRoleSpecificFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Datos profesionales',
            style: AppTypography.h3.copyWith(fontSize: 16)),
        const SizedBox(height: AppSpacing.md),
        if (data.role == 'constructor') ...[
          TextFormField(
            initialValue: data.organizationName,
            decoration: const InputDecoration(
              labelText: 'Nombre de empresa',
              hintText: 'Ej: Construcciones Gómez S.L.',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            onChanged: (v) {
              data.organizationName = v;
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            initialValue: data.cifOrNif,
            decoration: const InputDecoration(
              labelText: 'CIF de la empresa',
              hintText: 'B12345678',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onChanged: (v) {
              data.cifOrNif = v.toUpperCase();
              onChanged();
            },
          ),
        ] else if (data.role == 'tecnico') ...[
          TextFormField(
            initialValue: data.cifOrNif,
            decoration: const InputDecoration(
              labelText: 'NIF',
              hintText: '12345678X',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onChanged: (v) {
              data.cifOrNif = v.toUpperCase();
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            initialValue: data.colegio,
            decoration: const InputDecoration(
              labelText: 'Colegio profesional',
              hintText: 'Ej: COAM Madrid',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            onChanged: (v) {
              data.colegio = v;
              onChanged();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            initialValue: data.numColegiacion,
            decoration: const InputDecoration(
              labelText: 'Número de colegiación',
              hintText: '14582',
              prefixIcon: Icon(Icons.numbers_outlined),
            ),
            onChanged: (v) {
              data.numColegiacion = v;
              onChanged();
            },
          ),
        ] else if (data.role == 'promotor') ...[
          TextFormField(
            initialValue: data.cifOrNif,
            decoration: const InputDecoration(
              labelText: 'NIF',
              hintText: '12345678X',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onChanged: (v) {
              data.cifOrNif = v.toUpperCase();
              onChanged();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          initialValue: data.province,
          decoration: const InputDecoration(
            labelText: 'Provincia',
            hintText: 'Madrid',
            prefixIcon: Icon(Icons.location_on_outlined),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Verifica tus datos', style: AppTypography.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Revisa la información antes de crear tu cuenta',
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Resumen
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen de perfil',
                    style: AppTypography.h3.copyWith(fontSize: 16)),
                const Divider(height: 24),
                _SummaryRow(
                    icon: Icons.person_outline,
                    label: 'Nombre',
                    value: data.fullName),
                _SummaryRow(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: data.email),
                _SummaryRow(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: data.phoneE164),
                _SummaryRow(
                    icon: Icons.work_outline,
                    label: 'Rol',
                    value: data.role?.toUpperCase() ?? '—'),
                if (data.organizationName.isNotEmpty)
                  _SummaryRow(
                      icon: Icons.business_outlined,
                      label: 'Empresa',
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
            label: 'Acepto los',
            linkLabel: 'Términos y Condiciones',
            linkUrl: AppConstants.termsUrl,
          ),
          const SizedBox(height: AppSpacing.md),
          _ConsentRow(
            checked: data.acceptedPrivacy,
            onChanged: (v) {
              data.acceptedPrivacy = v ?? false;
              onChanged();
            },
            label: 'Acepto la',
            linkLabel: 'Política de Privacidad',
            linkUrl: AppConstants.privacyUrl,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tu identidad se verificará en el siguiente paso conforme a la normativa de prevención de blanqueo (KYC).',
            style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
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

class _ConsentRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: onChanged,
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
                    text: '$label ',
                    style: AppTypography.body,
                    children: [
                      TextSpan(
                        text: linkLabel,
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
    final orgName = (preview['org_name'] as String?) ?? 'una organización';
    final inviter = (preview['inviter_name'] as String?) ?? 'tu equipo';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.borderSubtle,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: context.colors.border,
          width: 1,
        ),
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
                Text('Te uniste como miembro de equipo',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '$inviter te invitó al equipo de $orgName. '
                  'Sólo necesitas tus datos personales — la empresa y el rol '
                  'ya están definidos por tu equipo.',
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
                Text('Invitación no disponible',
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
                  child: const Text('Crear cuenta normal'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onGoToLogin,
                  child: const Text('Ya tengo cuenta · Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
