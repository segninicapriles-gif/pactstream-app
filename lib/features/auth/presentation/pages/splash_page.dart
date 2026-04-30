import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Splash inicial. Decide a dónde mandar al usuario:
///   - Sin sesión → /login
///   - Con sesión → /home
///   - (V2) Con sesión pero sin KYC → /onboarding/identity
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    // Pequeña espera para que el splash se vea
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final user = SupabaseConfig.currentUser;
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // Consultar kyc_status del perfil. Si KYC no verificado/en revisión,
    // redirigir al onboarding.
    try {
      final rows = await SupabaseConfig.client
          .rpc('sf_get_my_profile')
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;

      if (rows is List && rows.isNotEmpty) {
        final profile = rows.first as Map<String, dynamic>;
        final kyc = profile['kyc_status'] as String? ?? 'not_started';
        if (kyc == 'not_started' || kyc == 'rejected') {
          context.go(AppRoutes.kycIntro);
          return;
        }
      } else {
        // Sin perfil → algo raro, mejor ir al login para empezar de cero.
        await SupabaseConfig.client.auth.signOut();
        context.go(AppRoutes.login);
        return;
      }
    } catch (_) {
      // Error de red u otro: ir al home y dejar que el usuario actúe.
    }
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.psNavy, Color(0xFF14193D)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TODO(sprint-1): reemplazar por logo SVG real
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: AppColors.psGradient,
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: AppColors.psNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppConstants.appName,
                style: AppTypography.h1.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppConstants.appTagline,
                style: AppTypography.bodyS.copyWith(color: AppColors.psCyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
