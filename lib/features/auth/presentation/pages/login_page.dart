import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/l10n_extension.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/i18n/widgets/language_picker.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/error_humanizer.dart';
import '../../../../core/widgets/pactstream_logo.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.redirectTo});

  /// Ruta interna (`/...`) a la que navegar tras autenticar. La usa el
  /// flujo de invitación de organización para no perder el destino
  /// (`/login?redirect=/org-invite%3Ftoken%3D...`).
  final String? redirectTo;

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
          title: Text(ctx.l10n.resetTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.l10n.resetBody,
                style: AppTypography.bodyS
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: ctx.l10n.loginEmailLabel,
                  hintText: ctx.l10n.loginEmailHint,
                  prefixIcon: const Icon(Icons.mail_outline),
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
              child: Text(ctx.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: sending || sent != null
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (!email.contains('@')) {
                        setS(() => err = ctx.l10n.loginEmailInvalid);
                        return;
                      }
                      setS(() {
                        sending = true;
                        err = null;
                      });
                      try {
                        // redirectTo debe estar en la allowlist de Supabase
                        // (Auth → URL Configuration → Redirect URLs).
                        await SupabaseConfig.client.auth
                            .resetPasswordForEmail(
                          email,
                          redirectTo: kIsWeb
                              ? '${Uri.base.origin}'
                                  '${AppRoutes.resetPassword}'
                              : AppConstants.resetPasswordDeepLink,
                        );
                        setS(() {
                          sending = false;
                          sent = ctx.l10n.resetSent;
                        });
                      } catch (e) {
                        setS(() {
                          sending = false;
                          err = ctx.l10n.resetFailed;
                        });
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white))
                  : Text(ctx.l10n.resetSend),
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
      // Si venimos con ?redirect= (p.ej. invitación de organización),
      // honramos el destino. Solo aceptamos rutas internas ('/...').
      final redirect = widget.redirectTo;
      if (redirect != null &&
          redirect.startsWith('/') &&
          !redirect.startsWith('//')) {
        context.go(redirect);
        return;
      }
      // Route through splash so KYC/onboarding checks run properly
      context.go(AppRoutes.splash);
    } on Exception catch (e) {
      setState(() => _errorMessage = humanizeError(e));
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
                Text(context.l10n.loginTitle, style: AppTypography.h2.copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.loginSubtitle,
                  style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: context.l10n.loginEmailLabel,
                    hintText: context.l10n.loginEmailHint,
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.loginEmailEmpty;
                    }
                    if (!value.contains('@')) {
                      return context.l10n.loginEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: context.l10n.loginPasswordLabel,
                    hintText: context.l10n.loginPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscurePassword
                          ? context.l10n.loginShowPassword
                          : context.l10n.loginHidePassword,
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _signIn(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.loginPasswordEmpty;
                    }
                    if (value.length < 8) {
                      return context.l10n.loginPasswordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showResetPasswordDialog,
                    child: Text(context.l10n.loginForgotPassword),
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
                      : Text(context.l10n.loginTitle),
                ),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Text(
                        context.l10n.commonOr,
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
                  child: Text(context.l10n.loginCreateAccount),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Cambio de idioma ANTES de autenticarse. Sin esto, un usuario
                // angloparlante que ya tiene cuenta no tiene forma de leer la
                // pantalla de login: el selector del wizard de alta solo lo ve
                // quien está creando una cuenta nueva.
                Center(
                  child: TextButton.icon(
                    onPressed: () => showLanguageSheet(context),
                    icon: const Icon(Icons.language_outlined, size: 18),
                    label: Text(
                      ref.watch(appLanguageProvider).nativeName,
                      style: AppTypography.bodyS,
                    ),
                  ),
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
