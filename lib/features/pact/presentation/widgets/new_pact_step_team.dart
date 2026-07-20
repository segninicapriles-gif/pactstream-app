import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/pact_creation_data.dart';

/// Paso 2 del wizard: invitar a las partes faltantes.
///
/// Roles posibles: promotor, constructor, tecnico (solo obra mayor).
/// El usuario que crea ya es uno de los participantes; aquí
/// recogemos solo los que faltan.
class NewPactStepTeam extends StatefulWidget {
  const NewPactStepTeam({
    super.key,
    required this.data,
    required this.onChange,
  });

  final PactCreationData data;
  final VoidCallback onChange;

  @override
  State<NewPactStepTeam> createState() => _NewPactStepTeamState();
}

class _NewPactStepTeamState extends State<NewPactStepTeam> {
  String? _myRole; // se carga del perfil para saber qué partes pedir
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyRole();
  }

  Future<void> _loadMyRole() async {
    try {
      final rows = await SupabaseConfig.client.rpc('sf_get_my_profile');
      if (rows is List && rows.isNotEmpty) {
        final profile = rows.first as Map<String, dynamic>;
        setState(() {
          _myRole = profile['primary_role'] as String?;
          _loading = false;
        });
        _ensureInvitesForRole();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Garantiza que existe una invitación vacía para cada rol que falta,
  /// según pact_type y rol del usuario actual.
  void _ensureInvitesForRole() {
    final roleMe = _myRole;
    final pactType = widget.data.pactType;
    if (roleMe == null || pactType == null) return;

    final invites = widget.data.invites;
    final List<String> rolesNeeded;

    if (pactType == 'obra_menor') {
      // Solo promotor + constructor. El que crea es uno de ellos.
      rolesNeeded = roleMe == 'promotor'
          ? ['constructor']
          : (roleMe == 'constructor' ? ['promotor'] : ['promotor', 'constructor']);
    } else {
      // obra_mayor: 3 roles, falta los 2 que no es el creador.
      final all = ['promotor', 'constructor', 'tecnico'];
      rolesNeeded = all.where((r) => r != roleMe).toList();
    }

    for (final role in rolesNeeded) {
      final exists = invites.any((i) => i.role == role);
      if (!exists) {
        invites.add(PartyInvite(role: role));
      }
    }
    widget.onChange();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Invita a las partes', style: AppTypography.h2.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Recibirán un email para unirse al pacto. Si ya tienen cuenta en PactStream, lo enlazaremos automáticamente.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Mi tarjeta (yo soy parte)
        _MyselfCard(role: _myRole ?? 'parte'),
        const SizedBox(height: AppSpacing.md),

        // Cards para invitar
        for (final invite in widget.data.invites)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _InviteCard(
              invite: invite,
              onChange: widget.onChange,
            ),
          ),

        const SizedBox(height: AppSpacing.md),
        if (widget.data.pactType == 'obra_menor')
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.warningBg,
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Obra menor sin técnico: la validación de hitos la hará el promotor con fotos como evidencia.',
                    style: AppTypography.bodyS.copyWith(color: context.colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MyselfCard extends StatelessWidget {
  const _MyselfCard({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.successBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.success, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppColors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(role),
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                Text('Tú · ya estás en el pacto',
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(String role) {
    switch (role) {
      case 'promotor':
        return 'Promotor';
      case 'constructor':
        return 'Constructor';
      case 'tecnico':
        return 'Arquitecto técnico';
      default:
        return 'Parte del pacto';
    }
  }
}

class _InviteCard extends StatefulWidget {
  const _InviteCard({required this.invite, required this.onChange});

  final PartyInvite invite;
  final VoidCallback onChange;

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.invite.email);
    _nameCtrl = TextEditingController(text: widget.invite.fullName);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.infoBg,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(_iconFor(widget.invite.role),
                    color: context.colors.brandAccent, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(_labelFor(widget.invite.role),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre completo *',
              hintText: 'Cómo aparecerá en el contrato',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              widget.invite.fullName = v;
              widget.onChange();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email *',
              hintText: 'persona@ejemplo.com',
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) {
              widget.invite.email = v.trim();
              widget.onChange();
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Necesitamos nombre y email reales para emitir el contrato a firma.',
            style: AppTypography.caption.copyWith(
              color: context.colors.textTertiary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String role) {
    switch (role) {
      case 'promotor':
        return Icons.account_balance_wallet_outlined;
      case 'constructor':
        return Icons.handyman_outlined;
      case 'tecnico':
        return Icons.architecture_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _labelFor(String role) {
    switch (role) {
      case 'promotor':
        return 'Promotor';
      case 'constructor':
        return 'Constructor';
      case 'tecnico':
        return 'Arquitecto técnico';
      default:
        return 'Invitado';
    }
  }
}
