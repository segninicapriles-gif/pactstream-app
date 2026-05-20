import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Tab "Perfil" de PactStream.
///
/// Muestra datos del usuario, estado KYC, secciones específicas por rol
/// (P1-50/51/52 del Design Handoff), preferencias de notificación,
/// cambio de contraseña y eliminación de cuenta (RGPD · P1-54).
///
/// El historial de obras y rating real se construyen en Sprint 2.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  // Preferencias de notificación (UI only por ahora — backend en V2)
  bool _notifyMilestones = true;
  bool _notifyPayments = true;
  bool _notifyMessages = true;
  bool _notifyDeadlines = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows =
          await SupabaseConfig.client.rpc('sf_get_my_profile_extended');
      if (!mounted) return;
      if (rows is List && rows.isNotEmpty) {
        setState(() => _profile = rows.first as Map<String, dynamic>);
      }
    } catch (_) {
      // silenciar
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _role => _profile?['primary_role'] as String? ?? '';
  String get _kycStatus =>
      _profile?['kyc_status'] as String? ?? 'not_started';

  String get _roleLabel => switch (_role) {
        'promotor' => 'Promotor',
        'constructor' => 'Constructor',
        'tecnico' => 'Técnico',
        _ => 'Usuario',
      };

  Color get _roleAccentColor => switch (_role) {
        'tecnico' => AppColors.tecnicoAccent,
        _ => AppColors.psBlue,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No se pudo cargar el perfil. Intenta cerrar sesión y volver a entrar.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _ProfileHeader(
          fullName: _profile!['full_name'] as String? ?? '',
          email: _profile!['email'] as String? ?? '',
          roleLabel: _roleLabel,
          roleColor: _roleAccentColor,
          organizationName: _profile!['organization_name'] as String?,
        ),
        const SizedBox(height: AppSpacing.xl),

        // KYC status
        _SectionTitle(title: 'Verificación de identidad'),
        const SizedBox(height: AppSpacing.sm),
        _KycSection(status: _kycStatus, profile: _profile!),
        const SizedBox(height: AppSpacing.xl),

        // Datos por rol (aplicando P1-51/P1-52 del Design Handoff)
        _SectionTitle(title: 'Información ${_roleSpecificSection()}'),
        const SizedBox(height: AppSpacing.sm),
        _RoleDataCard(role: _role, profile: _profile!),
        const SizedBox(height: AppSpacing.xl),

        // Reputación PactStream (placeholder, real en Sprint 2)
        _SectionTitle(title: 'Reputación PactStream'),
        const SizedBox(height: AppSpacing.sm),
        const _ReputationCard(),
        const SizedBox(height: AppSpacing.xl),

        // Ajustes de notificación
        _SectionTitle(title: 'Notificaciones'),
        const SizedBox(height: AppSpacing.sm),
        _NotificationsCard(
          milestones: _notifyMilestones,
          payments: _notifyPayments,
          messages: _notifyMessages,
          deadlines: _notifyDeadlines,
          onMilestonesChanged: (v) => setState(() => _notifyMilestones = v),
          onPaymentsChanged: (v) => setState(() => _notifyPayments = v),
          onMessagesChanged: (v) => setState(() => _notifyMessages = v),
          onDeadlinesChanged: (v) => setState(() => _notifyDeadlines = v),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Acciones de cuenta
        _SectionTitle(title: 'Cuenta'),
        const SizedBox(height: AppSpacing.sm),
        _AccountActionsCard(),

        const SizedBox(height: AppSpacing.xxl),

        // Footer con info legal
        Center(
          child: Column(
            children: [
              Text(
                'PactStream ${AppConstants.appVersion}',
                style:
                    AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: 4),
              Text(
                '© 2026 PactStream Technologies, S.L.',
                style:
                    AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Confidence to build',
                style:
                    AppTypography.caption.copyWith(color: AppColors.psCyan),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  String _roleSpecificSection() => switch (_role) {
        'constructor' => 'profesional de empresa',
        'tecnico' => 'profesional',
        _ => 'personal',
      };
}

// =====================================================================
// HEADER · avatar + nombre + rol + KPIs
// =====================================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.email,
    required this.roleLabel,
    required this.roleColor,
    this.organizationName,
  });

  final String fullName;
  final String email;
  final String roleLabel;
  final Color roleColor;
  final String? organizationName;

  @override
  Widget build(BuildContext context) {
    final initials = fullName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.psNavy,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.psNavy, AppColors.ink800],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: roleColor,
              shape: BoxShape.circle,
              boxShadow: AppShadows.medium,
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: AppTypography.h1.copyWith(
                  color: AppColors.white,
                  fontSize: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(fullName,
              style: AppTypography.h2.copyWith(color: AppColors.white)),
          const SizedBox(height: 4),
          Text(email,
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.white.withValues(alpha: 0.7))),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppSpacing.xl),
              border: Border.all(color: roleColor),
            ),
            child: Text(
              roleLabel.toUpperCase() +
                  (organizationName != null ? ' · $organizationName' : ''),
              style: AppTypography.caption
                  .copyWith(color: AppColors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SECCIÓN TITLE
// =====================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.caption.copyWith(color: AppColors.ink500),
    );
  }
}

// =====================================================================
// KYC SECTION
// =====================================================================

class _KycSection extends StatelessWidget {
  const _KycSection({required this.status, required this.profile});

  final String status;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final spec = switch (status) {
      'verified' => (
        bg: AppColors.successBg,
        fg: AppColors.success,
        icon: Icons.verified_user,
        label: 'Identidad verificada',
        cta: null,
        date: profile['kyc_verified_at'] as String?,
      ),
      'pending_review' => (
        bg: AppColors.warningBg,
        fg: AppColors.warning,
        icon: Icons.access_time,
        label: 'En revisión manual',
        cta: null,
        date: null,
      ),
      'rejected' => (
        bg: AppColors.errorBg,
        fg: AppColors.error,
        icon: Icons.error_outline,
        label: 'Verificación rechazada',
        cta: 'Reintentar',
        date: null,
      ),
      _ => (
        bg: AppColors.warningBg,
        fg: AppColors.warning,
        icon: Icons.warning_amber_outlined,
        label: 'Identidad sin verificar',
        cta: 'Verificar ahora',
        date: null,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: spec.fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: spec.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(spec.icon, color: spec.fg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.label,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700)),
                if (spec.date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Verificada ${AppFormatters.dateTimeDetail(DateTime.parse(spec.date!).toLocal())}',
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink500),
                  ),
                ] else if (status == 'pending_review') ...[
                  const SizedBox(height: 2),
                  Text('Plazo máximo: 24h',
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
                ],
              ],
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

// =====================================================================
// ROLE DATA CARD · datos específicos del rol
// =====================================================================

class _RoleDataCard extends StatelessWidget {
  const _RoleDataCard({required this.role, required this.profile});

  final String role;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final rows = <_DataRow>[];

    rows.add(_DataRow(
      icon: Icons.person_outline,
      label: 'Nombre completo',
      value: profile['full_name'] as String? ?? '—',
    ));
    rows.add(_DataRow(
      icon: Icons.mail_outline,
      label: 'Email',
      value: profile['email'] as String? ?? '—',
    ));
    rows.add(_DataRow(
      icon: Icons.phone_outlined,
      label: 'Teléfono',
      value: profile['phone_e164'] as String? ?? '—',
    ));

    if (role == 'tecnico') {
      rows.add(_DataRow(
        icon: Icons.badge_outlined,
        label: 'NIF',
        value: profile['national_id'] as String? ?? '—',
      ));
      rows.add(_DataRow(
        icon: Icons.school_outlined,
        label: 'Colegio profesional',
        value: profile['colegio'] as String? ?? '—',
      ));
      rows.add(_DataRow(
        icon: Icons.numbers_outlined,
        label: 'Nº de colegiación',
        value: profile['num_colegiacion'] as String? ?? '—',
      ));
    } else if (role == 'constructor') {
      rows.add(_DataRow(
        icon: Icons.business_outlined,
        label: 'Razón social',
        value: profile['organization_name'] as String? ?? '—',
      ));
      rows.add(_DataRow(
        icon: Icons.badge_outlined,
        label: 'CIF',
        value: profile['organization_cif'] as String? ?? '—',
      ));
    } else if (role == 'promotor') {
      // P1-51 aplicado: el promotor NO muestra empresa.
      rows.add(_DataRow(
        icon: Icons.badge_outlined,
        label: 'NIF',
        value: profile['national_id'] as String? ?? '—',
      ));
    }

    final province = profile['province'] as String?;
    if (province != null && province.isNotEmpty) {
      rows.add(_DataRow(
        icon: Icons.location_on_outlined,
        label: 'Provincia',
        value: province,
      ));
    }

    // P1-52: Constructor y Promotor también pueden subir documentación
    final showDocsButton = role == 'tecnico' || role == 'constructor';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Column(
        children: [
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1 && !showDocsButton;
            return Column(
              children: [
                e.value,
                if (!isLast)
                  const Divider(height: 1, indent: 56),
              ],
            );
          }),
          if (showDocsButton) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined,
                  color: AppColors.psBlue),
              title: Text(
                role == 'tecnico'
                    ? 'Subir certificado profesional (PDF)'
                    : 'Subir documentación de empresa',
                style: AppTypography.body.copyWith(color: AppColors.psBlue),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.psBlue),
              onTap: () {
                // TODO(sprint-2): subida de documentos
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.ink500),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.ink500)),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// REPUTATION CARD · placeholder para Sprint 2
// =====================================================================

class _ReputationCard extends StatelessWidget {
  const _ReputationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.ink100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('—',
                      style: AppTypography.h1
                          .copyWith(color: AppColors.ink500, fontSize: 28)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin actividad todavía',
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Tu reputación se construye con cada pacto cerrado, hito validado en plazo y ausencia de disputas.',
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _ReputationStat(label: 'Pactos completados', value: '0'),
              const SizedBox(width: AppSpacing.md),
              _ReputationStat(label: 'En curso', value: '0'),
              const SizedBox(width: AppSpacing.md),
              _ReputationStat(label: 'Disputas', value: '0'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReputationStat extends StatelessWidget {
  const _ReputationStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTypography.h2
                    .copyWith(color: AppColors.ink900, fontSize: 20)),
            Text(label,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: AppColors.ink500)),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// NOTIFICATIONS CARD
// =====================================================================

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.milestones,
    required this.payments,
    required this.messages,
    required this.deadlines,
    required this.onMilestonesChanged,
    required this.onPaymentsChanged,
    required this.onMessagesChanged,
    required this.onDeadlinesChanged,
  });

  final bool milestones;
  final bool payments;
  final bool messages;
  final bool deadlines;
  final ValueChanged<bool> onMilestonesChanged;
  final ValueChanged<bool> onPaymentsChanged;
  final ValueChanged<bool> onMessagesChanged;
  final ValueChanged<bool> onDeadlinesChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Column(
        children: [
          _NotifToggle(
            title: 'Hitos y validaciones',
            subtitle: 'Cuando un hito necesita tu atención',
            value: milestones,
            onChanged: onMilestonesChanged,
          ),
          const Divider(height: 1, indent: 16),
          _NotifToggle(
            title: 'Pagos liberados',
            subtitle: 'Cuando se mueve dinero en tu cuenta de custodia',
            value: payments,
            onChanged: onPaymentsChanged,
          ),
          const Divider(height: 1, indent: 16),
          _NotifToggle(
            title: 'Mensajes',
            subtitle: 'Conversaciones con otras partes',
            value: messages,
            onChanged: onMessagesChanged,
          ),
          const Divider(height: 1, indent: 16),
          _NotifToggle(
            title: 'Plazos próximos',
            subtitle: 'Recordatorios 48h antes de vencimientos',
            value: deadlines,
            onChanged: onDeadlinesChanged,
          ),
        ],
      ),
    );
  }
}

class _NotifToggle extends StatelessWidget {
  const _NotifToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: AppTypography.bodyS.copyWith(color: AppColors.ink500)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.psBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    );
  }
}

// =====================================================================
// ACCOUNT ACTIONS
// =====================================================================

class _AccountActionsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AccountActionsCard> createState() =>
      _AccountActionsCardState();
}

class _AccountActionsCardState extends ConsumerState<_AccountActionsCard> {
  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nueva contraseña',
            hintText: 'Mínimo 8 caracteres',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );

    if (newPassword == null || newPassword.length < 8) return;

    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres cerrar tu sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await SupabaseConfig.client.auth.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _deleteAccount() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción es irreversible. Los datos relacionados con tus pactos se conservan 10 años por obligación legal (LOE) pero tu cuenta queda eliminada y no podrás iniciar sesión.',
            ),
            const SizedBox(height: 12),
            const Text('Si tienes pactos activos, primero debes cerrarlos.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar cuenta'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseConfig.client.rpc(
        'sf_delete_my_account',
        params: {'p_reason': reasonController.text},
      );
      await SupabaseConfig.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta eliminada')),
      );
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.group_outlined, color: AppColors.psBlue),
            title: const Text('Mi equipo'),
            subtitle: Text(
              'Invita jefes de obra o técnicos a tu organización',
              style: AppTypography.caption.copyWith(color: AppColors.ink500),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.myTeam),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePassword,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _signOut,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: AppColors.error),
            title: Text(
              'Borrar cuenta',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
            subtitle: Text(
              'RGPD · derecho de supresión',
              style: AppTypography.caption.copyWith(color: AppColors.ink500),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.error),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

