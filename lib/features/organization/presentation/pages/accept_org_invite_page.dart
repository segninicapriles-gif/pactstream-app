import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/organization_actions.dart';
import '../../data/organization_providers.dart';

/// Landing al hacer clic en el link del email de invitación.
///
/// Flujo:
///   1. Si NO está logueado → redirige a /login con redirect param
///   2. Si está logueado → llama a sf_accept_org_invite(token) y muestra
///      éxito o error
///   3. En éxito: redirige a /profile/team tras 2 segundos
class AcceptOrgInvitePage extends ConsumerStatefulWidget {
  const AcceptOrgInvitePage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AcceptOrgInvitePage> createState() =>
      _AcceptOrgInvitePageState();
}

class _AcceptOrgInvitePageState extends ConsumerState<AcceptOrgInvitePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processInvite());
  }

  Future<void> _processInvite() async {
    final user = SupabaseConfig.currentUser;
    if (user == null) {
      // No logueado: redirige a login conservando el token
      if (!mounted) return;
      context.go(
        '${AppRoutes.login}?redirect=${Uri.encodeComponent('${AppRoutes.acceptOrgInvite}?token=${widget.token}')}',
      );
      return;
    }

    try {
      final r = await OrganizationActions.acceptInvite(widget.token);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = r;
      });

      // Refrescar providers para que el user vea la nueva org
      ref.invalidate(myOrgsProvider);

      // Redirige a "Mi equipo" tras 2.5 s
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      context.go(AppRoutes.myTeam);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _loading
                ? _LoadingView()
                : (_error != null
                    ? _ErrorView(
                        message: _error!,
                        onRetry: _processInvite,
                      )
                    : _SuccessView(success: _success!)),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.lg),
        Text('Procesando invitación…',
            style: AppTypography.body.copyWith(color: AppColors.ink600)),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.success});
  final Map<String, dynamic> success;

  @override
  Widget build(BuildContext context) {
    final org = success['organization'] as Map<String, dynamic>?;
    final orgName = (org?['legal_name'] as String?) ?? 'la organización';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.successBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: AppColors.success, size: 56),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('¡Bienvenido al equipo!',
            style: AppTypography.h1, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ya formas parte del equipo de $orgName. En unos segundos te llevamos a tu panel.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.ink600),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.myTeam),
          child: const Text('Ir a Mi equipo'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.errorBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline,
              color: AppColors.error, size: 56),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('No se pudo procesar la invitación',
            style: AppTypography.h2, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyS.copyWith(color: AppColors.error),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go(AppRoutes.home),
              child: const Text('Volver'),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ],
    );
  }
}
