import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/organization.dart';
import '../../data/organization_providers.dart';
import '../sheets/org_action_sheets.dart';

/// Pantalla "Mi equipo" del Sprint 6.
///
/// Disponible para constructores y técnicos. Permite:
///   - Crear su organización (si aún no tiene)
///   - Invitar miembros por email
///   - Ver miembros activos + invitaciones pendientes
///   - Revocar miembros / cancelar invitaciones
///   - Cambiar `can_view_economics` de cada miembro
class MyTeamPage extends ConsumerWidget {
  const MyTeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(myOwnedOrgProvider);

    return Scaffold(
      backgroundColor: AppColors.ink50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        title: Text('Mi equipo', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(myOrgsProvider),
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myOrgsProvider),
        ),
        data: (org) {
          if (org == null) return _EmptyOrgView(ref: ref);
          return _OrgTeamView(org: org);
        },
      ),
    );
  }
}

// =====================================================================
// Empty state · cuando el user todavía no tiene organización
// =====================================================================

class _EmptyOrgView extends StatelessWidget {
  const _EmptyOrgView({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.infoBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business_center_outlined,
                  color: AppColors.psBlue, size: 48),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Crea tu organización',
                style: AppTypography.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Para invitar a jefes de obra o técnicos del estudio, primero crea tu organización. Solo tarda un minuto.',
              style: AppTypography.body.copyWith(color: AppColors.ink600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_business_outlined),
              onPressed: () async {
                final ok = await showCreateOrgSheet(context);
                if (ok) ref.invalidate(myOrgsProvider);
              },
              label: const Text('Crear mi organización'),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Vista del equipo · cabecera de org + lista de miembros
// =====================================================================

class _OrgTeamView extends ConsumerWidget {
  const _OrgTeamView({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(orgMembersProvider(org.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myOrgsProvider);
        ref.invalidate(orgMembersProvider(org.id));
        await ref.read(orgMembersProvider(org.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Cabecera de la organización
          _OrgHeaderCard(org: org),
          const SizedBox(height: AppSpacing.lg),

          // CTA invitar (solo owner)
          if (org.isOwner)
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () async {
                final ok = await showInviteMemberSheet(context, orgId: org.id);
                if (ok) {
                  ref.invalidate(orgMembersProvider(org.id));
                  ref.invalidate(myOrgsProvider);
                }
              },
              label: const Text('Invitar miembro'),
            ),
          if (org.isOwner) const SizedBox(height: AppSpacing.lg),

          // Lista de miembros
          membersAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(orgMembersProvider(org.id)),
            ),
            data: (result) => _MembersList(
              org: org,
              result: result,
              onChanged: () {
                ref.invalidate(orgMembersProvider(org.id));
                ref.invalidate(myOrgsProvider);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgHeaderCard extends StatelessWidget {
  const _OrgHeaderCard({required this.org});
  final Organization org;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: const Icon(Icons.business_center_outlined,
                    color: AppColors.psBlue, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.displayName,
                        style: AppTypography.h2.copyWith(fontSize: 20)),
                    if (org.cif != null)
                      Text('CIF · ${org.cif}',
                          style: AppTypography.bodyS
                              .copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
              if (org.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.psBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('OWNER',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.psBlue,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatChip(
                icon: Icons.group_outlined,
                label: '${org.membersCount} miembro${org.membersCount == 1 ? '' : 's'}',
              ),
              if (org.pendingInvitesCount > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                _StatChip(
                  icon: Icons.mail_outline,
                  label:
                      '${org.pendingInvitesCount} pendiente${org.pendingInvitesCount == 1 ? '' : 's'}',
                  color: AppColors.warning,
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              _StatChip(
                icon: Icons.category_outlined,
                label: _orgTypeLabel(org.orgType),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _orgTypeLabel(String type) {
    switch (type) {
      case 'constructor':
        return 'Constructora';
      case 'tecnico':
        return 'Estudio técnico';
      case 'mixed':
        return 'Mixta';
      case 'promotor':
        return 'Promotora';
      default:
        return type;
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink600;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({
    required this.org,
    required this.result,
    required this.onChanged,
  });

  final Organization org;
  final OrgMembersResult result;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.active.isNotEmpty) ...[
          Text('Miembros activos', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          for (final m in result.active)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MemberTile(
                org: org,
                member: m,
                onChanged: onChanged,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (result.pending.isNotEmpty) ...[
          Text('Invitaciones pendientes', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          for (final m in result.pending)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MemberTile(
                org: org,
                member: m,
                onChanged: onChanged,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (org.isOwner && result.revoked.isNotEmpty) ...[
          Text('Revocados', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          for (final m in result.revoked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MemberTile(
                org: org,
                member: m,
                onChanged: onChanged,
              ),
            ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.org,
    required this.member,
    required this.onChanged,
  });

  final Organization org;
  final OrganizationMember member;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final stateConfig = _stateConfig(member.state);
    final canIManage = org.isOwner && !member.isOwner;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.ink200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: member.isOwner
                ? AppColors.psBlue
                : AppColors.ink200,
            child: Text(
              _initials(member.displayName),
              style: AppTypography.bodyS.copyWith(
                color: member.isOwner ? AppColors.white : AppColors.ink600,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(member.displayName,
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (member.isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('TÚ',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 10)),
                      ),
                  ],
                ),
                Text(member.email,
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink500)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _MiniPill(
                      label: member.isOwner ? 'Owner' : 'Miembro',
                      color: member.isOwner
                          ? AppColors.psBlue
                          : AppColors.ink600,
                    ),
                    _MiniPill(
                      label: stateConfig.label,
                      color: stateConfig.color,
                    ),
                    if (member.canViewEconomics)
                      const _MiniPill(
                        label: 'Ve € €',
                        color: AppColors.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canIManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.ink500),
              onSelected: (action) async {
                bool changed = false;
                if (action == 'permissions') {
                  changed = await showUpdatePermissionsSheet(context,
                      member: member);
                } else if (action == 'revoke') {
                  changed =
                      await showRevokeMemberSheet(context, member: member);
                }
                if (changed) onChanged();
              },
              itemBuilder: (_) => [
                if (member.isActive)
                  const PopupMenuItem(
                    value: 'permissions',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.shield_outlined, size: 18),
                      title: Text('Cambiar permisos'),
                    ),
                  ),
                if (!member.isRevoked)
                  PopupMenuItem(
                    value: 'revoke',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_remove_outlined,
                          size: 18, color: AppColors.error),
                      title: Text(
                          member.isPending ? 'Cancelar invitación' : 'Revocar',
                          style: const TextStyle(color: AppColors.error)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static ({String label, Color color}) _stateConfig(String state) {
    switch (state) {
      case 'active':
        return (label: 'Activo', color: AppColors.success);
      case 'invited':
        return (label: 'Pendiente', color: AppColors.warning);
      case 'revoked':
        return (label: 'Revocado', color: AppColors.ink500);
      default:
        return (label: state, color: AppColors.ink500);
    }
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(
              color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('No se pudo cargar tu equipo',
                style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
