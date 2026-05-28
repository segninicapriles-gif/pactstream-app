import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pactstream_logo.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showResetPasswordDialog() async {
    final emailCtrl =
        TextEditingController(text: _emailController.text.trim());
    bool sending = false;
    String? sent;
    String? err;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Te enviaremos un enlace para restablecer tu contraseña.',
                style: AppTypography.bodyS
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'tu@email.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled: !sending,
              ),
              if (err != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(err!,
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.error)),
              ],
              if (sent != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(sent!,
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.success)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: sending || sent != null
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (!email.contains('@')) {
                        setS(() => err = 'Introduce un email válido');
                        return;
                      }
                      setS(() {
                        sending = true;
                        err = null;
                      });
                      try {
                        await SupabaseConfig.client.auth
                            .resetPasswordForEmail(email);
                        setS(() {
                          sending = false;
                          sent = 'Revisa tu correo — te hemos enviado '
                              'el enlace de recuperación.';
                        });
                      } catch (e) {
                        setS(() {
                          sending = false;
                          err = 'No se pudo enviar el correo. '
                              'Inténtalo de nuevo.';
                        });
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white))
                  : const Text('Enviar enlace'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Brand hero header ──────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + AppSpacing.xxl,
                bottom: AppSpacing.xxl,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.psGradientDeep,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.xl),
                ),
              ),
              child: Column(
                children: [
                  const PactStreamLogo(
                    height: 44,
                    variant: PactStreamLogoVariant.light,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppConstants.appTagline,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.psCyan,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // ── Form section ──────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: AppSpacing.lg),
                Text('Iniciar sesión', style: AppTypography.h2.copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Accede a tu cuenta para gestionar tus obras',
                  style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'tu@email.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Introduce tu email';
                    if (!value.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Mínimo 8 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _signIn(),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Introduce tu contraseña';
                    if (value.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showResetPasswordDialog,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.errorBg,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Text(
                        'o',
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textTertiary),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.register),
                  child: const Text('Crear cuenta nueva'),
                ),
                const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
