import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../../notifications/data/notifications_providers.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../pact/presentation/pages/pacts_list_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../widgets/dashboard_constructor.dart';
import '../widgets/dashboard_promotor.dart';
import '../widgets/dashboard_tecnico.dart';

/// Home shell con bottom navigation a 4 tabs (P0-11 del Design Handoff).
///
/// El contenido del tab Inicio cambia según el rol del usuario:
///   - Promotor → DashboardPromotor (en custodia, tareas urgentes, obras)
///   - Técnico → DashboardTecnico (cola de validación, KPIs)
///   - Constructor → DashboardConstructor (pendiente cobro, hitos por subir)
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
    (icon: Icons.notifications_outlined, label: 'Avisos'),
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
      // Silenciar
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
  String get _userName => _profile?['full_name'] as String? ?? 'usuario';
  String get _userRole => _profile?['primary_role'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final unread =
        ref.watch(unreadNotificationsProvider).maybeWhen(
              data: (n) => n,
              orElse: () => 0,
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text('PactStream'),
        actions: [
          IconButton(
            icon: _BadgedIcon(
              icon: Icons.notifications_outlined,
              count: unread,
            ),
            onPressed: () => setState(() => _selectedIndex = 2),
            tooltip: unread > 0 ? '$unread sin leer' : 'Avisos',
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
          : _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Refrescar contador al entrar al tab Avisos
          if (index == 2) {
            ref.invalidate(unreadNotificationsProvider);
            ref.invalidate(notificationsListProvider);
          }
        },
        items: _tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final showBadge = i == 2 && unread > 0;
          return BottomNavigationBarItem(
            icon: showBadge
                ? _BadgedIcon(icon: tab.icon, count: unread)
                : Icon(tab.icon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    // Si el KYC no está verificado, mostrar el badge en la parte superior
    // de cualquier tab para recordar al usuario que debe completarlo.
    final kycBadge = _kycStatus != 'verified'
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: _KycStatusBadge(status: _kycStatus),
          )
        : null;

    // Solo promotor y técnico pueden crear obras (P0 spec).
    final canCreate = _userRole == 'promotor' || _userRole == 'tecnico';

    final dashboard = switch (_selectedIndex) {
      0 => _buildDashboardForRole(),
      1 => PactsListPage(canCreate: canCreate),
      2 => const NotificationsPage(),
      3 => const ProfilePage(),
      _ => const SizedBox.shrink(),
    };

    if (kycBadge != null) {
      return Column(
        children: [
          kycBadge,
          Expanded(child: dashboard),
        ],
      );
    }
    return dashboard;
  }

  Widget _buildDashboardForRole() {
    final orgName = _profile?['organization_id'] != null
        ? null // TODO(sprint-1): cargar nombre de org real desde JOIN
        : null;

    return switch (_userRole) {
      'promotor' => DashboardPromotor(userName: _userName),
      'tecnico' => DashboardTecnico(userName: _userName),
      'constructor' =>
        DashboardConstructor(userName: _userName, organizationName: orgName),
      _ => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Rol desconocido. Contacta con soporte.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.ink600),
            ),
          ),
        ),
    };
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.ink400),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icono con badge numérico superpuesto. Usado en AppBar y en bottom nav
/// para indicar notificaciones sin leer.
class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KycStatusBadge extends StatelessWidget {
  const _KycStatusBadge({required this.status});

  final String status;

  ({Color bg, Color fg, IconData icon, String label, String? cta})
      get _spec => switch (status) {
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: spec.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(spec.icon, color: spec.fg, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              spec.label,
              style: AppTypography.bodyS.copyWith(
                fontWeight: FontWeight.w700,
                color: spec.fg,
              ),
            ),
          ),
          if (spec.cta != null)
            TextButton(
              onPressed: () => context.go(AppRoutes.kycIntro),
              style: TextButton.styleFrom(
                foregroundColor: spec.fg,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(spec.cta!,
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
