import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/supabase/supabase_client.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/kyc_intro_page.dart';

/// Rutas de la app. Una constante por ruta para evitar typos.
abstract final class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';

  // Onboarding (KYC)
  static const kycIntro = '/onboarding/identity';
  static const kycPostOnfido = '/onboarding/identity/result';

  // Main shell (con bottom nav)
  static const home = '/home';
  static const myPacts = '/pacts';
  static const messages = '/messages';
  static const profile = '/profile';

  // Pact
  static const pactNew = '/pacts/new';
  static const pactDetail = '/pacts/:id';
  static const pactSign = '/pacts/:id/sign';
  static const pactDeposit = '/pacts/:id/deposit';

  // Milestone
  static const milestoneDetail = '/pacts/:pactId/milestones/:id';
  static const milestoneEvidences = '/pacts/:pactId/milestones/:id/evidences';
  static const milestoneValidation = '/pacts/:pactId/milestones/:id/validate';
  static const milestoneDecision = '/pacts/:pactId/milestones/:id/decide';

  // Dispute
  static const disputeDetail = '/disputes/:id';

  // Notifications
  static const notifications = '/notifications';
}

/// GoRouter de la app con redirección por estado de auth + KYC.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final user = SupabaseConfig.currentUser;
      final isAuthRoute = state.matchedLocation == AppRoutes.splash ||
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.verifyEmail;

      if (user == null && !isAuthRoute) {
        return AppRoutes.login;
      }
      // Redirección a KYC si está logueado pero no verificado se gestiona
      // dentro de cada page con providers de Riverpod.
      return null;
    },
    routes: [
      // === AUTH ===
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailPage(),
      ),

      // === ONBOARDING ===
      GoRoute(
        path: AppRoutes.kycIntro,
        builder: (context, state) => const KycIntroPage(),
      ),

      // === MAIN ===
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),

      // TODO(sprint-2): rutas de pacto, hitos, disputa, perfil, notificaciones.
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'No encontramos esta página',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.matchedLocation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Volver a inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
