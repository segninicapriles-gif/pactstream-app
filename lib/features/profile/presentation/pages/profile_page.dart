import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, UserAttributes;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/profile_providers.dart';
import '../../../dashboard/data/dashboard_providers.dart';
import '../../../scoring/data/scoring_providers.dart';
import '../../../scoring/presentation/widgets/user_reputation_card.dart';

/// Tab "Perfil" de PactStream.
///
/// Edición inline de nombre y teléfono, subida de foto de perfil vía
/// image_picker + Supabase Storage (bucket `avatars`).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _uploadingAvatar = false;

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

  // ── Edit profile (nombre + teléfono) ──────────────────────────────────

  Future<void> _showEditSheet() async {
    final nameCtrl =
        TextEditingController(text: _profile?['full_name'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: _profile?['phone_e164'] as String? ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditProfileSheet(
        nameController: nameCtrl,
        phoneController: phoneCtrl,
        onSave: (name, phone) async {
          Navigator.of(ctx).pop();
          await _saveProfile(name, phone);
        },
      ),
    );
  }

  Future<void> _saveProfile(String name, String phone) async {
    try {
      await SupabaseConfig.client.rpc('sf_update_my_profile', params: {
        'p_full_name': name.trim().isEmpty ? null : name.trim(),
        'p_phone_e164': phone.trim().isEmpty ? null : phone.trim(),
      });
      await _load();
      // Invalidar el provider compartido para que el saludo del HomePage
      // se actualice con el nuevo nombre.
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

  // ── Foto de perfil ─────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final authUid = SupabaseConfig.currentUser!.id;
      final bytes = await picked.readAsBytes(); // XFile.readAsBytes() — cross-platform
      final ext = picked.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path = '$authUid/$authUid.$ext';

      await SupabaseConfig.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );

      final url =
          SupabaseConfig.client.storage.from('avatars').getPublicUrl(path);

      // Añadir cache-buster para forzar recarga en CachedNetworkImage
      final cacheBustedUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';

      await SupabaseConfig.client.rpc('sf_update_my_profile', params: {
        'p_avatar_url': cacheBustedUrl,
      });

      setState(() {
        _profile = {...?_profile, 'avatar_url': cacheBustedUrl};
      });
      ref.invalidate(myProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ProfileSkeleton();
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
      padding: EdgeInsets.zero,
      children: [
        // ── Header edge-to-edge (sin padding del ListView) ──────────
        _ProfileHeader(
          fullName: _profile!['full_name'] as String? ?? '',
          email: _profile!['email'] as String? ?? '',
          roleLabel: _roleLabel,
          roleColor: _roleAccentColor,
          organizationName: _profile!['organization_name'] as String?,
          avatarUrl: _profile!['avatar_url'] as String?,
          uploadingAvatar: _uploadingAvatar,
          onEditTap: _showEditSheet,
          onAvatarTap: _pickAndUploadAvatar,
        ),

        // ── Stats summary row ───────────────────────────────────────
        _ProfileStatsRow(ref: ref),

        // ── Resto del contenido con padding horizontal ──────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── KYC ──────────────────────────────────────────────────
              _SectionTitle(title: 'Verificación de identidad'),
              const SizedBox(height: AppSpacing.sm),
              _KycSection(status: _kycStatus, profile: _profile!),
              const SizedBox(height: AppSpacing.xl),

              // ── Datos de rol ─────────────────────────────────────────
              _SectionTitle(title: 'Información ${_roleSpecificSection()}'),
              const SizedBox(height: AppSpacing.sm),
              _RoleDataCard(role: _role, profile: _profile!),
              const SizedBox(height: AppSpacing.xl),

              // ── Reputación ───────────────────────────────────────────
              _SectionTitle(title: 'Reputación PactStream'),
              const SizedBox(height: AppSpacing.sm),
              UserReputationCard(
                userId: _profile!['id'] as String? ?? '',
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Notificaciones ───────────────────────────────────────
              _SectionTitle(title: 'Notificaciones'),
              const SizedBox(height: AppSpacing.sm),
              _NotificationsCard(
                milestones: _notifyMilestones,
                payments: _notifyPayments,
                messages: _notifyMessages,
                deadlines: _notifyDeadlines,
                onMilestonesChanged: (v) =>
                    setState(() => _notifyMilestones = v),
                onPaymentsChanged: (v) =>
                    setState(() => _notifyPayments = v),
                onMessagesChanged: (v) =>
                    setState(() => _notifyMessages = v),
                onDeadlinesChanged: (v) =>
                    setState(() => _notifyDeadlines = v),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Cuenta ───────────────────────────────────────────────
              _SectionTitle(title: 'Cuenta'),
              const SizedBox(height: AppSpacing.sm),
              _AccountActionsCard(),

              const SizedBox(height: AppSpacing.xxl),

              // ── Footer ───────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'PactStream ${AppConstants.appVersion}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2026 PactStream Technologies, S.L.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink500),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Confidence to build',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.psCyan),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
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
// HEADER · avatar editable + nombre + rol
// =====================================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.email,
    required this.roleLabel,
    required this.roleColor,
    required this.onEditTap,
    required this.onAvatarTap,
    required this.uploadingAvatar,
    this.organizationName,
    this.avatarUrl,
  });

  final String fullName;
  final String email;
  final String roleLabel;
  final Color roleColor;
  final String? organizationName;
  final String? avatarUrl;
  final bool uploadingAvatar;
  final VoidCallback onEditTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final initials = fullName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    // Sin margen — el ListView no tiene padding, así que este Container
    // se extiende edge-to-edge y conecta visualmente con el AppBar
    // (mismo gradiente psGradientDeep).
    // Uses the same gradient as the outer AppBar so the profile header
    // looks like a natural extension of it — no rounded bottom corners
    // to keep the unified header pattern across all pages.
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.psGradientDeep,
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar con overlay de cámara
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: roleColor,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.medium,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: uploadingAvatar
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : avatarUrl != null && avatarUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: Text(
                                      initials.isEmpty ? '?' : initials,
                                      style: AppTypography.h1.copyWith(
                                        color: AppColors.white,
                                        fontSize: 32,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(
                                      initials.isEmpty ? '?' : initials,
                                      style: AppTypography.h1.copyWith(
                                        color: AppColors.white,
                                        fontSize: 32,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initials.isEmpty ? '?' : initials,
                                    style: AppTypography.h1.copyWith(
                                      color: AppColors.white,
                                      fontSize: 32,
                                    ),
                                  ),
                                ),
                    ),
                    // Overlay cámara
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.psBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 13,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.25),
                  borderRadius: AppRadius.xlAll,
                  border: Border.all(color: roleColor),
                ),
                child: Text(
                  roleLabel.toUpperCase() +
                      (organizationName != null
                          ? ' · $organizationName'
                          : ''),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.white, fontSize: 10),
                ),
              ),
            ],
          ),

          // Botón editar (esquina superior derecha)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// BOTTOM SHEET · edición de nombre y teléfono
// =====================================================================

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.nameController,
    required this.phoneController,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final Future<void> Function(String name, String phone) onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Editar perfil',
                  style: AppTypography.h3.copyWith(fontSize: 18)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: widget.nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: widget.phoneController,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              hintText: '+34 612 345 678',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(
                      widget.nameController.text,
                      widget.phoneController.text,
                    );
                    if (mounted) setState(() => _saving = false);
                  },
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SECTION TITLE
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
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: spec.fg.withValues(alpha: 0.3)),
        boxShadow: AppShadows.soft,
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
                    style:
                        AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
// ROLE DATA CARD
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

    final showDocsButton = role == 'tecnico' || role == 'constructor';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.ink200),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1 && !showDocsButton;
            return Column(
              children: [
                e.value,
                if (!isLast) const Divider(height: 1, indent: 56),
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
              trailing: const Icon(Icons.chevron_right, color: AppColors.psBlue),
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
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.ink200),
        boxShadow: AppShadows.soft,
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    );
  }
}

// =====================================================================
// PROFILE STATS ROW · 3 mini KPIs entre header y contenido
// =====================================================================

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    // Datos del dashboard (obras activas)
    final dashAsync = ref.watch(dashboardDataProvider);
    final activeWorks = dashAsync.whenOrNull(data: (d) => d.activeWorks);

    // Datos de reputación (trust score + éxito %)
    final repAsync = ref.watch(myReputationProvider);
    final trustScore = repAsync.whenOrNull(data: (r) => r.score);
    final successPct = repAsync.whenOrNull(data: (r) {
      final total = r.pactsTotal;
      if (total == 0) return null;
      return ((r.pactsCompleted / total) * 100).round();
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              value: activeWorks != null ? '$activeWorks' : '—',
              label: 'Obras',
              icon: Icons.construction_outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatBox(
              value: trustScore != null ? '$trustScore' : '—',
              label: 'Trust Score',
              icon: Icons.shield_outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatBox(
              value: successPct != null ? '$successPct %' : '—',
              label: 'Éxito',
              icon: Icons.trending_up_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.ink200),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.psBlue),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.h3.copyWith(color: AppColors.psBlue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.ink200),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(Icons.group_outlined, color: AppColors.psBlue),
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
            trailing: const Icon(Icons.chevron_right, color: AppColors.error),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
