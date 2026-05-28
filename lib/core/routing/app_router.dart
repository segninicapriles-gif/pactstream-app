import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/supabase/supabase_client.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/kyc_capture_page.dart';
import '../../features/onboarding/presentation/pages/kyc_intro_page.dart';
import '../../features/onboarding/presentation/pages/kyc_result_page.dart';
import '../../features/onboarding/presentation/pages/welcome_onboarding_page.dart';
import '../../features/ai/presentation/pages/ai_assistant_page.dart';
import '../../features/scoring/presentation/pages/trust_score_page.dart';
import '../../features/organization/presentation/pages/accept_org_invite_page.dart';
import '../../features/organization/presentation/pages/my_team_page.dart';
import '../../features/pact/presentation/pages/contract_pdf_preview_page.dart';
import '../../features/pact/presentation/pages/contract_signing_page.dart';
import '../../features/pact/presentation/pages/milestone_detail_page.dart';
import '../../features/pact/presentation/pages/new_pact_page.dart';
import '../../features/pact/presentation/pages/pact_detail_page.dart';
import '../../features/pact/presentation/pages/upload_evidence_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Rutas de la app. Una constante por ruta para evitar typos.
abstract final class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';

  // Onboarding
  static const welcomeOnboarding = '/onboarding/welcome';
  static const kycIntro = '/onboarding/identity';
  static const kycCapture = '/onboarding/identity/capture';
  static const kycResult = '/onboarding/identity/result';

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

  // Organization (Sprint 6)
  static const myTeam = '/profile/team';
  static const acceptOrgInvite = '/org-invite';

  // AI (Sprint 7)
  static const pactAssistant = '/pacts/:id/assistant';

  // Scoring (Sprint 8)
  static const pactTrustScore = '/pacts/:id/trust-score';
}

/// GoRouter de la app con redirección por estado de auth + KYC.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final user = SupabaseConfig.currentUser;
      // Rutas accesibles sin sesión: auth + landing de invitación de
      // organización (que internamente redirige a login conservando el
      // token cuando hace falta).
      final isPublicRoute = state.matchedLocation == AppRoutes.splash ||
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.verifyEmail ||
          state.matchedLocation == AppRoutes.acceptOrgInvite ||
          state.matchedLocation == AppRoutes.welcomeOnboarding;

      if (user == null && !isPublicRoute) {
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
        pageBuilder: (context, state) =>
            AppMotion.fadePage(child: const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['invite_token'];
          return AppMotion.slideRightPage(
            child: RegisterPage(inviteToken: token),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['invite_token'];
          return AppMotion.fadePage(
            child: VerifyEmailPage(inviteToken: token),
          );
        },
      ),

      // === ONBOARDING ===
      GoRoute(
        path: AppRoutes.welcomeOnboarding,
        pageBuilder: (context, state) =>
            AppMotion.fadePage(child: const WelcomeOnboardingPage()),
      ),
      GoRoute(
        path: AppRoutes.kycIntro,
        pageBuilder: (context, state) =>
            AppMotion.slideRightPage(child: const KycIntroPage()),
      ),
      GoRoute(
        path: AppRoutes.kycCapture,
        pageBuilder: (context, state) =>
            AppMotion.slideRightPage(child: const KycCapturePage()),
      ),
      GoRoute(
        path: AppRoutes.kycResult,
        pageBuilder: (context, state) {
          final status = state.uri.queryParameters['status'] ?? 'verified';
          return AppMotion.fadePage(child: KycResultPage(status: status));
        },
      ),

      // === MAIN ===
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) =>
            AppMotion.fadePage(child: const HomePage()),
      ),

      // === PACT ===
      GoRoute(
        path: AppRoutes.pactNew,
        pageBuilder: (context, state) =>
            AppMotion.slideUpPage(child: const NewPactPage()),
      ),
      GoRoute(
        path: AppRoutes.pactDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppMotion.slideUpPage(child: PactDetailPage(pactId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.pactSign,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppMotion.slideUpPage(
            child: ContractSigningPage(pactId: id),
          );
        },
      ),
      GoRoute(
        path: '/pacts/:id/contract-pdf',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppMotion.slideUpPage(
            child: ContractPdfPreviewPage(pactId: id),
          );
        },
      ),

      // === MILESTONE ===
      GoRoute(
        path: AppRoutes.milestoneDetail,
        pageBuilder: (context, state) {
          final pactId = state.pathParameters['pactId']!;
          final id = state.pathParameters['id']!;
          return AppMotion.slideUpPage(
            child: MilestoneDetailPage(pactId: pactId, milestoneId: id),
          );
        },
      ),
      GoRoute(
        path: '/pacts/:pactId/milestones/:id/evidences/upload',
        pageBuilder: (context, state) {
          final pactId = state.pathParameters['pactId']!;
          final id = state.pathParameters['id']!;
          return AppMotion.slideUpPage(
            child: UploadEvidencePage(pactId: pactId, milestoneId: id),
          );
        },
      ),

      // === AI ASSISTANT (Sprint 7) ===
      GoRoute(
        path: AppRoutes.pactAssistant,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? '';
          return AppMotion.slideUpPage(
            child: AiAssistantPage(pactId: id, pactTitle: title),
          );
        },
      ),

      // === TRUST SCORE (Sprint 8) ===
      GoRoute(
        path: AppRoutes.pactTrustScore,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'] ?? '';
          return AppMotion.slideUpPage(
            child: TrustScorePage(pactId: id, pactTitle: title),
          );
        },
      ),

      // === ORGANIZATION (Sprint 6) ===
      GoRoute(
        path: AppRoutes.myTeam,
        pageBuilder: (context, state) =>
            AppMotion.slideRightPage(child: const MyTeamPage()),
      ),
      GoRoute(
        path: AppRoutes.acceptOrgInvite,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return AppMotion.fadePage(
            child: AcceptOrgInvitePage(token: token),
          );
        },
      ),

      // TODO(sprint-2): rutas de depósito, validación, decisión, disputa.
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.ink50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text('Página no encontrada',
            style: AppTypography.h3.copyWith(color: AppColors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No encontramos esta página',
                style: AppTypography.h2,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.matchedLocation,
                style: AppTypography.mono
                    .copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.xl),
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
