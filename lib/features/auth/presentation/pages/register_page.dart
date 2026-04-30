import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/registration_data.dart';

/// Wizard de registro en 3 pasos.
///
/// Step 1: datos personales (nombre, email, teléfono, contraseña).
/// Step 2: rol + datos profesionales/empresa (campos adaptados).
/// Step 3: consentimientos legales + crear cuenta.
///
/// Tras éxito → /verify-email donde se detecta verificación automáticamente.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final PageController _pageController = PageController();
  final RegistrationData _data = RegistrationData();
  int _currentStep = 0;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
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
      // Sign up con Supabase Auth pasando TODA la metadata. El trigger
      // on_auth_user_created en la BD lee esta metadata y crea
      // automáticamente public.users + legal_consents.
      final response = await SupabaseConfig.client.auth.signUp(
        email: _data.email.trim(),
        password: _data.password,
        data: <String, dynamic>{
          'full_name': _data.fullName.trim(),
          'phone_e164': _data.phoneE164,
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
          'terms_version': RegistrationData.termsVersion,
          'privacy_version': RegistrationData.privacyVersion,
        },
      );

      if (response.user == null) {
        throw Exception('No se pudo crear la cuenta');
      }

      if (!mounted) return;
      context.go(AppRoutes.verifyEmail);
    } catch (e) {
      // Mostrar el error real para facilitar debugging en desarrollo.
      // En producción, sustituir por _humanizeError(e.toString()).
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canContinue => switch (_currentStep) {
        0 => _data.step1Valid,
        1 => _data.step2Valid,
        2 => _data.step3Valid,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
        title: Text('Paso ${_currentStep + 1} de 3'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar de 3 segmentos
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active ? AppColors.psCyan : AppColors.ink200,
                        borderRadius: BorderRadius.circular(2),
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
                children: [
                  _Step1PersonalInfo(data: _data, onChanged: () => setState(() {})),
                  _Step2RoleAndProfessional(data: _data, onChanged: () => setState(() {})),
                  _Step3LegalConsents(data: _data, onChanged: () => setState(() {})),
                ],
              ),
            ),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                    : Text(_currentStep == 2 ? 'Crear mi cuenta' : 'Siguiente →'),
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
  const _Step1PersonalInfo({required this.data, required this.onChanged});

  final RegistrationData data;
  final VoidCallback onChanged;

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
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
            initialValue: data.email,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'tu@email.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (v) {
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
                  border: Border.all(color: AppColors.ink200, width: 1.5),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Text(
                  'ES +34',
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.ink700),
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
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(
              color: selected ? AppColors.psBlue : AppColors.ink200,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Icon(option.icon, color: AppColors.psBlue),
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
                            .copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.psBlue),
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
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Resumen
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: AppColors.ink200),
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
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
          Icon(icon, size: 18, color: AppColors.psBlue),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.ink500)),
                Text(value, style: AppTypography.body),
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
                borderRadius: BorderRadius.circular(4),
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
                          color: AppColors.psBlue,
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
