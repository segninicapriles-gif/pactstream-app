import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pactstream_logo.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Splash inicial. Decide a dónde mandar al usuario:
///   - Sin sesión → /login
///   - Con sesión + KYC pendiente → /onboarding/identity
///   - Con sesión + KYC ok → /home
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
    // Pausa mínima para que el logo no parpadee; antes era 1s artificial.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final user = SupabaseConfig.currentUser;
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

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
        await SupabaseConfig.client.auth.signOut();
        context.go(AppRoutes.login);
        return;
      }
    } catch (_) {
      // Error de red u otro: ir al home y dejar que el usuario actúe.
    }
    if (!mounted) return;

    // Show guided onboarding on first launch
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('pactstream_onboarding_complete') ?? false;
    if (!mounted) return;
    if (!onboardingDone) {
      context.go(AppRoutes.welcomeOnboarding);
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo oficial de PactStream — adapta variante al tema
              PactStreamLogo(
                height: 52,
                variant: Theme.of(context).brightness == Brightness.dark
                    ? PactStreamLogoVariant.light
                    : PactStreamLogoVariant.dark,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.psBlue),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Cargando...',
                style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
