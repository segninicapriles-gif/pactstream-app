import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Pantalla post-registro esperando verificación de email.
///
/// Detecta automáticamente la verificación vía onAuthStateChange.
/// NO incluye botón "Ya lo verifiqué" (corrección P0-21 del Design Handoff).
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, this.inviteToken});

  /// Sprint 6 polish · Token de invitación a organización. Si está
  /// presente, al verificar el email se redirige a /org-invite en lugar
  /// del flujo normal de KYC.
  final String? inviteToken;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  StreamSubscription<AuthState>? _authSub;
  Timer? _pollingTimer;
  bool _resending = false;
  String? _resendMessage;

  String get _email => SupabaseConfig.currentUser?.email ?? 'tu correo';

  @override
  void initState() {
    super.initState();
    _listenForVerification();
  }

  void _listenForVerification() {
    // Listener al stream de cambios de auth — emite cuando el usuario
    // pulsa el link de verificación (si la app está abierta cuando lo hace).
    _authSub = SupabaseConfig.authStream.listen((data) {
      final user = data.session?.user;
      if (user != null && user.emailConfirmedAt != null) {
        _onVerified();
      }
    });

    // Polling cada 5s como fallback. Algunos navegadores no propagan el
    // evento si el usuario verifica desde otra ventana/dispositivo.
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkUser());
  }

  Future<void> _checkUser() async {
    try {
      final response = await SupabaseConfig.client.auth.getUser();
      if (response.user?.emailConfirmedAt != null) {
        _onVerified();
      }
    } on Exception {
      // Ignorar errores transitorios de red
    }
  }

  void _onVerified() {
    _authSub?.cancel();
    _pollingTimer?.cancel();
    if (!mounted) return;
    // Sprint 6 polish · Si venimos del flow de invitación, vamos a
    // aceptar la invitación en lugar del onboarding/KYC normal.
    if (widget.inviteToken != null && widget.inviteToken!.isNotEmpty) {
      context.go(
        '${AppRoutes.acceptOrgInvite}?token=${widget.inviteToken}',
      );
      return;
    }
    context.go(AppRoutes.kycIntro);
  }

  Future<void> _resendVerification() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _resendMessage = null;
    });
    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: SupabaseConfig.currentUser?.email ?? '',
      );
      setState(() => _resendMessage = 'Email reenviado. Revisa tu bandeja.');
    } on Exception catch (e) {
      setState(() => _resendMessage = 'No se pudo reenviar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.infoBg,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: context.colors.brandAccent,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Verifica tu email',
                textAlign: TextAlign.center,
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Hemos enviado un enlace de confirmación a:',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _email,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Pulsa el enlace del email para activar tu cuenta. La detectaremos automáticamente.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  children: [
                    Text(
                      '¿Ya pulsaste el link del email?',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'El link te redirige a una nueva pestaña. Cuando confirmes ahí, vuelve aquí y continúa al login.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyS
                          .copyWith(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      onPressed: () async {
                        await SupabaseConfig.client.auth.signOut();
                        if (!context.mounted) return;
                        // Si traemos token de invitación, preservamos el
                        // destino para que el login redirija a /org-invite
                        // tras autenticar.
                        final token = widget.inviteToken;
                        if (token != null && token.isNotEmpty) {
                          final redirect =
                              '${AppRoutes.acceptOrgInvite}?token=$token';
                          context.go(
                            '${AppRoutes.login}?redirect=${Uri.encodeComponent(redirect)}',
                          );
                        } else {
                          context.go(AppRoutes.login);
                        }
                      },
                      label: const Text('Continuar al login'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_resendMessage != null) ...[
                Text(
                  _resendMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyS.copyWith(color: context.colors.brandAccent),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              OutlinedButton.icon(
                onPressed: _resending ? null : _resendVerification,
                icon: _resending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Reenviar email de verificación'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () async {
                  await SupabaseConfig.client.auth.signOut();
                  if (!context.mounted) return;
                  context.go(AppRoutes.login);
                },
                child: const Text('Cancelar y volver al login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
