import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../../notifications/data/notifications_providers.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../pact/presentation/pages/pacts_list_page.dart';
import '../../../profile/data/profile_providers.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../../core/widgets/shimmer_box.dart';
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

  static const List<({IconData icon, IconData activeIcon, String label})> _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Obras'),
    (icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Avisos'),
    (icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Perfil'),
  ];

  Future<void> _signOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  // Helpers to extract from the reactive profile data.
  static String _kycStatusFrom(Map<String, dynamic>? p) =>
      p?['kyc_status'] as String? ?? 'not_started';
  static String _userNameFrom(Map<String, dynamic>? p) =>
      p?['full_name'] as String? ?? 'usuario';
  static String _userRoleFrom(Map<String, dynamic>? p) =>
      p?['primary_role'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final unread =
        ref.watch(unreadNotificationsProvider).maybeWhen(
              data: (n) => n,
              orElse: () => 0,
            );

    final isLoading = profileAsync.isLoading;
    final profile = profileAsync.valueOrNull;
    final userName = _userNameFrom(profile);
    // Títulos del AppBar por tab
    const tabTitles = ['Inicio', 'Mis obras', 'Avisos', 'Mi perfil'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail =
            AppBreakpoints.shouldShowRail(constraints.maxWidth);

        return Scaffold(
          appBar: AppBar(
            title: _selectedIndex == 0 && !isLoading
                ? Text(
                    '${_timeGreeting()}, ${userName.split(' ').first}',
                    style: AppTypography.h2.copyWith(color: AppColors.white),
                  )
                : Text(
                    isLoading
                        ? 'PactStream'
                        : tabTitles[_selectedIndex],
                    style: AppTypography.h3.copyWith(color: AppColors.white),
                  ),
            centerTitle: _selectedIndex != 0,
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: context.colors.headerGradient,
              ),
            ),
            actions: [
              if (_selectedIndex == 0 || _selectedIndex == 2)
                IconButton(
                  icon: _BadgedIcon(
                    icon: Icons.notifications_outlined,
                    count: unread,
                  ),
                  onPressed: () => setState(() => _selectedIndex = 2),
                  tooltip: unread > 0 ? '$unread sin leer' : 'Avisos',
                ),
            ],
          ),
          body: isLoading
              ? const DetailSkeleton()
              : useRail
                  ? Row(
                      children: [
                        _AdaptiveNavigationRail(
                          selectedIndex: _selectedIndex,
                          unread: unread,
                          onDestinationSelected: _onTabSelected,
                        ),
                        VerticalDivider(
                          thickness: 1,
                          width: 1,
                          color: context.colors.border,
                        ),
                        Expanded(child: _buildTabContent(profile)),
                      ],
                    )
                  : _buildTabContent(profile),
          bottomNavigationBar:
              useRail ? null : _buildBottomNav(unread),
        );
      },
    );
  }

  void _onTabSelected(int index) {
    AppHaptics.selection();
    setState(() => _selectedIndex = index);
    if (index == 2) {
      ref.invalidate(unreadNotificationsProvider);
      ref.invalidate(notificationsListProvider);
    }
  }

  Widget _buildBottomNav(int unread) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(
            top: BorderSide(color: c.navBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: c.shadowBase.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        items: _tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final showBadge = i == 2 && unread > 0;
          return BottomNavigationBarItem(
            icon: showBadge
                ? _BadgedIcon(icon: tab.icon, count: unread)
                : Icon(tab.icon),
            activeIcon: showBadge
                ? _BadgedIcon(icon: tab.activeIcon, count: unread)
                : _ActiveNavIcon(icon: tab.activeIcon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(Map<String, dynamic>? profile) {
    final kycStatus = _kycStatusFrom(profile);
    final userRole = _userRoleFrom(profile);

    // Si el KYC no está verificado, mostrar el badge en la parte superior
    // de cualquier tab para recordar al usuario que debe completarlo.
    final kycBadge = kycStatus != 'verified'
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: _KycStatusBadge(status: kycStatus),
          )
        : null;

    // Solo promotor y técnico pueden crear obras (P0 spec).
    // Los 3 roles principales pueden crear obras:
    //   - Constructor: crea el proyecto, sube documentación y contrato
    //   - Promotor: puede crear obras que encarga a un constructor
    //   - Técnico: puede crear obras que supervisa
    final canCreate =
        userRole == 'constructor' || userRole == 'promotor' || userRole == 'tecnico';

    final dashboard = switch (_selectedIndex) {
      0 => _buildDashboardForRole(profile),
      1 => PactsListPage(canCreate: canCreate),
      2 => const NotificationsPage(),
      3 => const ProfilePage(),
      _ => const SizedBox.shrink(),
    };

    // Crossfade animation between tabs
    final animatedDashboard = AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedIndex),
        child: dashboard,
      ),
    );

    if (kycBadge != null) {
      return Column(
        children: [
          kycBadge,
          Expanded(child: animatedDashboard),
        ],
      );
    }
    return animatedDashboard;
  }

  /// Saludo contextual según la hora del día.
  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Buenas noches';
    if (hour < 13) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Callback para "Ver todas" en los dashboards — cambia al tab Obras.
  void _goToObrasTab() {
    AppHaptics.selection();
    setState(() => _selectedIndex = 1);
  }

  Widget _buildDashboardForRole(Map<String, dynamic>? profile) {
    final userRole = _userRoleFrom(profile);
    final userName = _userNameFrom(profile);
    final orgName = profile?['organization_name'] as String?;

    return switch (userRole) {
      'promotor' => DashboardPromotor(
          userName: userName,
          onViewAllPacts: _goToObrasTab,
        ),
      'tecnico' => DashboardTecnico(
          userName: userName,
          onViewAllPacts: _goToObrasTab,
        ),
      'constructor' => DashboardConstructor(
          userName: userName,
          organizationName: orgName,
          onViewAllPacts: _goToObrasTab,
        ),
      _ => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Rol desconocido. Contacta con soporte.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: context.colors.textSecondary),
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
            Icon(icon, size: 64, color: context.colors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                style: AppTypography.h2.copyWith(color: context.colors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
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
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AppMotion.normal,
              curve: AppMotion.spring,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: AppRadius.smAll,
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
          ),
        ),
      ],
    );
  }
}

/// Active state icon for bottom navigation — filled icon inside a subtle
/// colored pill background, giving a clear selection indicator.
class _ActiveNavIcon extends StatelessWidget {
  const _ActiveNavIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.pillBg,
        borderRadius: AppRadius.pillAll,
      ),
      child: Icon(icon),
    );
  }
}

// =====================================================================
// NAVIGATION RAIL · tablet / desktop adaptive navigation
// =====================================================================

class _AdaptiveNavigationRail extends StatelessWidget {
  const _AdaptiveNavigationRail({
    required this.selectedIndex,
    required this.unread,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final int unread;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      backgroundColor: c.navBg,
      indicatorColor: c.pillBg,
      selectedIconTheme: const IconThemeData(color: AppColors.psBlue),
      unselectedIconTheme: IconThemeData(color: c.textTertiary),
      selectedLabelTextStyle: AppTypography.caption.copyWith(
        color: AppColors.psBlue,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      unselectedLabelTextStyle: AppTypography.caption.copyWith(
        color: c.textTertiary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      destinations: _HomePageState._tabs.asMap().entries.map((entry) {
        final i = entry.key;
        final tab = entry.value;
        final showBadge = i == 2 && unread > 0;
        return NavigationRailDestination(
          icon: showBadge
              ? _BadgedIcon(icon: tab.icon, count: unread)
              : Icon(tab.icon),
          selectedIcon: showBadge
              ? _BadgedIcon(icon: tab.activeIcon, count: unread)
              : Icon(tab.activeIcon),
          label: Text(tab.label),
        );
      }).toList(),
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
    return Semantics(
      liveRegion: true,
      label: spec.label,
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: AppRadius.smAll,
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
    ),  // close Semantics
    );
  }
}
