import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Home shell con bottom navigation a 4 tabs (P0-11 del Design Handoff).
///
/// Carga el perfil del usuario actual y muestra el estado KYC como badge.
/// El contenido real de los dashboards por rol se construye en chunk 3.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.home_outlined, label: 'Inicio'),
    (icon: Icons.folder_outlined, label: 'Obras'),
    (icon: Icons.chat_outlined, label: 'Mensajes'),
    (icon: Icons.person_outline, label: 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final rows = await SupabaseConfig.client.rpc('sf_get_my_profile');
      if (!mounted) return;
      if (rows is List && rows.isNotEmpty) {
        setState(() => _profile = rows.first as Map<String, dynamic>);
      }
    } catch (_) {
      // Silenciar — el badge KYC simplemente no se muestra
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  String get _kycStatus =>
      _profile?['kyc_status'] as String? ?? 'not_started';

  String get _userName =>
      _profile?['full_name'] as String? ?? 'usuario';

  String get _userRole {
    final r = _profile?['primary_role'] as String? ?? '';
    return switch (r) {
      'promotor' => 'Promotor',
      'constructor' => 'Constructor',
      'tecnico' => 'Técnico',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PactStream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO(sprint-2): navegar a /notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Saludo
                  Text(
                    'Hola, ${_userName.split(' ').first}',
                    style: AppTypography.h1,
                  ),
                  if (_userRole.isNotEmpty)
                    Text(
                      'Sesión activa como $_userRole',
                      style:
                          AppTypography.bodyS.copyWith(color: AppColors.ink500),
                    ),
                  const SizedBox(height: AppSpacing.lg),

                  // Badge KYC
                  _KycStatusBadge(status: _kycStatus),

                  const SizedBox(height: AppSpacing.xxl),

                  // Placeholder dashboard
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: Border.all(color: AppColors.ink200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.construction,
                            size: 64, color: AppColors.psBlue),
                        const SizedBox(height: AppSpacing.md),
                        Text('Dashboard por rol',
                            style: AppTypography.h3,
                            textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tab actual: ${_tabs[_selectedIndex].label}',
                          style: AppTypography.bodyS
                              .copyWith(color: AppColors.ink500),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Contenido específico por rol en construcción (Sprint 1 chunk 3).',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyS
                              .copyWith(color: AppColors.ink600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: _tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}

class _KycStatusBadge extends StatelessWidget {
  const _KycStatusBadge({required this.status});

  final String status;

  ({Color bg, Color fg, IconData icon, String label, String? cta})
      get _spec => switch (status) {
            'verified' => (
              bg: AppColors.successBg,
              fg: AppColors.success,
              icon: Icons.verified_user,
              label: 'Identidad verificada',
              cta: null,
            ),
            'pending_review' => (
              bg: AppColors.warningBg,
              fg: AppColors.warning,
              icon: Icons.access_time,
              label: 'Verificación en revisión (24h)',
              cta: null,
            ),
            'rejected' => (
              bg: AppColors.errorBg,
              fg: AppColors.error,
              icon: Icons.error_outline,
              label: 'Verificación rechazada',
              cta: 'Reintentar',
            ),
            _ => (
              bg: AppColors.warningBg,
              fg: AppColors.warning,
              icon: Icons.warning_amber_outlined,
              label: 'Verifica tu identidad para operar',
              cta: 'Verificar ahora',
            ),
          };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: spec.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(spec.icon, color: spec.fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              spec.label,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
                color: spec.fg,
              ),
            ),
          ),
          if (spec.cta != null)
            TextButton(
              onPressed: () => context.go(AppRoutes.kycIntro),
              child: Text(spec.cta!),
            ),
        ],
      ),
    );
  }
}
