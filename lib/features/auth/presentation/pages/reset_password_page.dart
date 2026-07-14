import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/error_humanizer.dart';
import '../../../../core/widgets/pactstream_logo.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Pantalla para establecer una contraseña nueva.
///
/// Se llega aquí desde el enlace de recuperación del email
/// (AuthChangeEvent.passwordRecovery → redirect global en el router).
/// Requiere la sesión temporal de recovery que crea Supabase al abrir
/// el enlace; si no existe, se informa al usuario y se le devuelve al
/// login para pedir un enlace nuevo.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  bool _done = false;
  String? _errorMessage;

  bool get _hasRecoverySession => SupabaseConfig.currentUser != null;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _done = true;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = humanizeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _done ? _buildSuccess(context) : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: PactStreamLogo(height: 40)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Nueva contraseña',
            textAlign: TextAlign.center,
            style: AppTypography.h1
                .copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _hasRecoverySession
                ? 'Elige una contraseña nueva para tu cuenta.'
                : 'Este enlace ha caducado o ya se ha usado. '
                    'Pide uno nuevo desde "¿Olvidaste tu contraseña?" '
                    'en la pantalla de acceso.',
            textAlign: TextAlign.center,
            style: AppTypography.body
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_hasRecoverySession) ...[
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                helperText: 'Mínimo 8 caracteres',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'La contraseña debe tener al menos 8 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Repite la contraseña',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  tooltip: _obscureConfirm
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
              onFieldSubmitted: (_) => _saving ? null : _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style:
                    AppTypography.bodyS.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : const Text('Guardar contraseña'),
            ),
          ] else
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Ir a iniciar sesión'),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 64, color: AppColors.success),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Contraseña actualizada',
          textAlign: TextAlign.center,
          style: AppTypography.h1.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ya puedes usar tu contraseña nueva. Te llevamos a la app.',
          textAlign: TextAlign.center,
          style: AppTypography.body
              .copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          // Pasamos por splash para que corran los checks de KYC/onboarding.
          onPressed: () => context.go(AppRoutes.splash),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
