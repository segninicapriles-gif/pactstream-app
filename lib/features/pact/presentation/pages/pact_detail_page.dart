import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_detail.dart';
import '../../data/pact_providers.dart';
import '../sheets/pact_action_sheets.dart';
import '../widgets/addendums_section.dart';
import '../widgets/deposit_widget.dart';
import '../widgets/pact_state_badge.dart';
import '../widgets/predeposit_pending_card.dart';

/// Detalle completo del pacto.
///
/// Estructura:
///   - Header: título, display_id, ubicación, badge de estado
///   - Resumen económico: total, en custodia, liberado, comisión
///   - Partes: lista con avatares, rol y estado de invitación/firma
///   - Hitos: timeline en orden con badges de estado
///   - CTAs por estado/rol (placeholder por ahora — chunks 3 y 4 los activan)
class PactDetailPage extends ConsumerStatefulWidget {
  const PactDetailPage({super.key, required this.pactId});

  final String pactId;

  @override
  ConsumerState<PactDetailPage> createState() => _PactDetailPageState();
}

class _PactDetailPageState extends ConsumerState<PactDetailPage> {
  String get pactId => widget.pactId;

  Future<void> _refresh() async {
    ref.invalidate(pactDetailProvider(pactId));
    await ref.read(pactDetailProvider(pactId).future);
  }

  /// Handlers de las acciones v2.0. Cada uno abre su sheet y, si la
  /// acción se ejecutó con éxito, refresca el detalle del pacto.
  Future<void> _handleFundInitial(PactDetail detail) async {
    final ok = await showFundInitialDepositSheet(context, detail: detail);
    if (ok && mounted) await _refresh();
  }

  Future<void> _handleReplenish(PactDetail detail) async {
    final ok = await showReplenishDepositSheet(context, detail: detail);
    if (ok && mounted) await _refresh();
  }

  Future<void> _handleCreateCert(PactDetail detail) async {
    final ok = await showCreateCertSheet(context, detail: detail);
    if (ok && mounted) await _refresh();
  }

  Future<void> _handleProposeAddendum(PactDetail detail) async {
    final ok = await showProposeAddendumSheet(context, detail: detail);
    if (ok && mounted) await _refresh();
  }

  Future<void> _handleSignAddendum(
      PactDetail detail, PactAddendum addendum) async {
    final myRole = detail.me?.role;
    if (myRole == null) return;
    final ok = await showSignAddendumSheet(
      context,
      addendum: addendum,
      myRole: myRole,
    );
    if (ok && mounted) await _refresh();
  }

  // === v2.1 · handlers reales (chunk 5) ===

  Future<void> _handleSetupAdvance(PactDetail detail) async {
    final ok = await showSetupAdvanceSheet(context, detail: detail);
    if (ok && mounted) await _refresh();
  }

  Future<void> _handlePredeposit(PactMilestone m) async {
    final ok = await showPredepositMilestoneSheet(context, milestone: m);
    if (ok && mounted) await _refresh();
  }

  Future<void> _handleForceAdvance(PactMilestone m) async {
    final ok = await showForceAdvanceSheet(context, milestone: m);
    if (ok && mounted) await _refresh();
  }

  /// El FAB "Nueva certificación" solo aparece si soy constructor de un
  /// pacto v2/v2.1 en ejecución.
  bool _canCreateCert(PactDetail detail) {
    return detail.pact.isV2OrLater &&
        detail.pact.state == 'in_execution' &&
        detail.me?.role == 'constructor';
  }

  /// "Proponer anexo" solo está disponible para partes activas en un pacto
  /// v2/v2.1 en ejecución o pausado.
  bool _canProposeAddendum(PactDetail detail) {
    if (!detail.pact.isV2OrLater) return false;
    if (detail.me == null) return false;
    return detail.pact.state == 'in_execution' ||
        detail.pact.state == 'paused_pending_tech';
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(pactDetailProvider(pactId));

    // FAB solo si soy constructor en un pacto v2 in_execution.
    final fab = detailAsync.maybeWhen(
      data: (d) => _canCreateCert(d)
          ? FloatingActionButton.extended(
              onPressed: () => _handleCreateCert(d),
              backgroundColor: AppColors.psBlue,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add_chart),
              label: const Text('Nueva certificación'),
            )
          : null,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.ink50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        title: Text('Detalle de obra', style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(pactDetailProvider(pactId)),
          ),
        ],
      ),
      floatingActionButton: fab,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No se pudo cargar el pacto',
                  textAlign: TextAlign.center,
                  style: AppTypography.h3,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyS
                      .copyWith(color: AppColors.ink500),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(pactDetailProvider(pactId)),
                  child: const Text('Reintentar'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Header(detail: detail),
              const SizedBox(height: AppSpacing.md),
              // Resumen económico clásico (v1) o widget de depósito (v2/v2.1).
              if (detail.pact.isV2OrLater)
                DepositWidget(
                  detail: detail,
                  onFundInitial: () => _handleFundInitial(detail),
                  onReplenish: () => _handleReplenish(detail),
                  onSetupAdvance: () => _handleSetupAdvance(detail),
                )
              else
                _MoneySummary(detail: detail),

              // v2.1 · Pre-depósitos pendientes (cards específicas)
              if (detail.pact.isV21 &&
                  detail.pendingPredepositMilestones.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (final m in detail.pendingPredepositMilestones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PredepositPendingCard(
                      milestone: m,
                      myRole: detail.me?.role,
                      onPredeposit: () => _handlePredeposit(m),
                      onForceAdvance: () => _handleForceAdvance(m),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              _PartiesSection(
                parties: detail.parties,
                isCreator: detail.pact.isCreator,
              ),
              const SizedBox(height: AppSpacing.md),
              _MilestonesSection(detail: detail),
              if (detail.pact.isV2OrLater) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: AddendumsSection(
                    detail: detail,
                    onProposeAddendum: _canProposeAddendum(detail)
                        ? () => _handleProposeAddendum(detail)
                        : null,
                    onSignAddendum: (a) => _handleSignAddendum(detail, a),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_contractAvailable(detail.pact.state))
                _ContractPdfLink(pactId: detail.pact.id),
              if (_contractAvailable(detail.pact.state))
                const SizedBox(height: AppSpacing.md),
              _NextStepCta(detail: detail),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// Estados del pacto en los que el contrato PDF ya tiene sentido mostrar.
bool _contractAvailable(String state) {
  return const {
    'signing',
    'signed',
    'funded',
    'in_execution',
    'disputed',
    'completed',
    'closed',
  }.contains(state);
}

class _ContractPdfLink extends StatelessWidget {
  const _ContractPdfLink({required this.pactId});

  final String pactId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/pacts/$pactId/contract-pdf'),
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: AppColors.ink200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: const Icon(Icons.picture_as_pdf,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contrato del pacto · PDF',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w800)),
                  Text('Ver, descargar o imprimir el contrato firmado',
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink400),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// HEADER
// =====================================================================

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final PactDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.pact;
    final stateStyle = PactStateStyle.forPactState(p.state);
    final isMenor = p.pactType == 'obra_menor';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pills superiores
          Row(
            children: [
              PactStateBadge(style: stateStyle),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink100,
                  borderRadius: BorderRadius.circular(AppSpacing.xl),
                ),
                child: Text(
                  isMenor ? 'OBRA MENOR' : 'OBRA MAYOR',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink600,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                p.displayId,
                style: AppTypography.mono
                    .copyWith(fontSize: 11, color: AppColors.ink500),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Título grande
          Text(p.title, style: AppTypography.h2),

          const SizedBox(height: AppSpacing.xs),

          // Dirección
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.ink500),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${p.obraAddressLine}'
                  '${p.obraCity != null ? ', ${p.obraCity}' : ''}'
                  '${p.obraProvince != null && p.obraProvince != p.obraCity ? ' (${p.obraProvince})' : ''}',
                  style: AppTypography.bodyS
                      .copyWith(color: AppColors.ink500),
                ),
              ),
            ],
          ),

          // Descripción (si la hay y no es trivial)
          if (p.description != null &&
              p.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(p.description!.trim(),
                style: AppTypography.body
                    .copyWith(color: AppColors.ink700)),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// MONEY
// =====================================================================

class _MoneySummary extends StatelessWidget {
  const _MoneySummary({required this.detail});

  final PactDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.pact;
    final feeCents =
        (p.totalAmountCents * p.platformFeePct.toDouble() / 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.psNavy,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.psNavy, Color(0xFF14193D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IMPORTE TOTAL',
              style: AppTypography.caption
                  .copyWith(color: AppColors.psCyan)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppFormatters.moneyLong(p.totalAmountCents),
            style: AppTypography.displayL.copyWith(
              color: AppColors.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _moneyRow('Liberado',
              AppFormatters.moneyShort(detail.amountReleasedCents),
              valueColor: AppColors.success),
          _moneyRow(
              'En custodia',
              AppFormatters.moneyShort(detail.amountInCustodyCents),
              valueColor: AppColors.psCyan),
          _moneyRow(
              'Comisión PactStream (${p.platformFeePct}%)',
              AppFormatters.moneyShort(feeCents),
              muted: true),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value,
      {Color? valueColor, bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodyS.copyWith(
                color: muted
                    ? AppColors.white.withValues(alpha: 0.5)
                    : AppColors.white.withValues(alpha: 0.85),
              )),
          Text(value,
              style: AppTypography.body.copyWith(
                color: valueColor ?? AppColors.white,
                fontWeight: muted ? FontWeight.w500 : FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

// =====================================================================
// PARTIES
// =====================================================================

class _PartiesSection extends StatelessWidget {
  const _PartiesSection({
    required this.parties,
    required this.isCreator,
  });

  final List<PactParty> parties;
  final bool isCreator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Partes del pacto', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${parties.where((p) => p.hasAccepted).length} de ${parties.length} han aceptado · '
            '${parties.where((p) => p.hasSigned).length} han firmado',
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < parties.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.ink200),
            _PartyTile(
              party: parties[i],
              canResend: isCreator,
              onResend: () => _resend(context, parties[i]),
            ),
          ],
        ],
      ),
    );
  }

  void _resend(BuildContext context, PactParty party) {
    // Sin sistema de email transaccional todavía. En el chunk de firma
    // (Sprint 2 chunk 3) conectamos Resend / Postmark y este botón
    // dispara un re-envío real.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.psNavy,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Reenvío programado para ${party.snapshotEmail ?? party.snapshotFullName ?? 'la parte'}. '
          'El envío real de emails se activa en el próximo paso (firma).',
          style: AppTypography.bodyS.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({
    required this.party,
    required this.canResend,
    required this.onResend,
  });

  final PactParty party;
  final bool canResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final roleSpec = _roleSpec(party.role);
    final statusLabel = _statusLabel();
    // El nombre real puede faltar en pactos antiguos; usamos email de
    // fallback para pactos creados antes de la validación obligatoria.
    final displayName = (party.snapshotFullName ?? '').trim().isNotEmpty
        ? party.snapshotFullName!
        : (party.snapshotEmail ?? 'Sin identidad');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: roleSpec.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(roleSpec.icon,
                color: roleSpec.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (party.isMe) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('TÚ',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ],
                  ],
                ),
                Text(
                  roleSpec.label,
                  style: AppTypography.bodyS
                      .copyWith(color: AppColors.ink500),
                ),
                // Email separado solo si tenemos nombre (si no, el email
                // YA es el displayName de arriba y no queremos duplicar).
                if ((party.snapshotFullName ?? '').trim().isNotEmpty &&
                    party.snapshotEmail != null) ...[
                  Text(
                    party.snapshotEmail!,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.ink500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                Text(
                  statusLabel,
                  style: AppTypography.bodyS.copyWith(
                    color: party.hasAccepted
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Icono + menú "..." cuando es invitación pendiente
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (party.hasSigned)
                const Icon(Icons.verified,
                    color: AppColors.success, size: 22)
              else if (party.hasAccepted)
                const Icon(Icons.check_circle_outline,
                    color: AppColors.psBlue, size: 22)
              else
                const Icon(Icons.hourglass_empty,
                    color: AppColors.warning, size: 22),
              if (canResend && !party.hasAccepted) ...[
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onResend,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('Reenviar',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.psBlue,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel() {
    if (party.hasSigned) return 'Firmó el contrato';
    if (party.hasAccepted) return 'Aceptó la invitación';
    return 'Pendiente de aceptar';
  }

  ({String label, IconData icon, Color color}) _roleSpec(String role) {
    switch (role) {
      case 'promotor':
        return (
          label: 'Promotor',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.psBlue,
        );
      case 'constructor':
        return (
          label: 'Constructor',
          icon: Icons.handyman_outlined,
          color: AppColors.success,
        );
      case 'tecnico':
        return (
          label: 'Arquitecto técnico',
          icon: Icons.architecture_outlined,
          color: AppColors.tecnicoAccent,
        );
      default:
        return (
          label: role,
          icon: Icons.person_outline,
          color: AppColors.ink500,
        );
    }
  }
}

// =====================================================================
// MILESTONES
// =====================================================================

class _MilestonesSection extends StatelessWidget {
  const _MilestonesSection({required this.detail});

  final PactDetail detail;

  @override
  Widget build(BuildContext context) {
    final isV2 = detail.pact.isV2OrLater;
    final milestones = detail.milestones;
    final paid = milestones.where((m) => m.state == 'paid').length;

    final sectionTitle = isV2 ? 'Certificaciones' : 'Hitos';
    String subtitle;
    if (milestones.isEmpty) {
      subtitle = isV2
          ? 'Aún no hay certificaciones. El constructor las emitirá según el avance.'
          : 'Aún no hay hitos.';
    } else {
      subtitle = isV2
          ? '${milestones.length} certificaciones · $paid pagadas'
          : '${milestones.length} hitos · $paid pagados';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(sectionTitle, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.md),
          if (milestones.isEmpty && isV2)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.ink50,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                border: Border.all(color: AppColors.ink200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timeline_outlined,
                      size: 18, color: AppColors.ink500),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      detail.me?.role == 'constructor'
                          ? 'Como constructor podrás emitir tu primera certificación cuando el pacto esté en ejecución.'
                          : 'El constructor podrá emitir certificaciones cuando el pacto esté en ejecución.',
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink600),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < milestones.length; i++)
              _MilestoneTile(
                milestone: milestones[i],
                pactId: detail.pact.id,
                isV2: isV2,
                isLast: i == milestones.length - 1,
              ),
        ],
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.pactId,
    required this.isLast,
    this.isV2 = false,
  });

  final PactMilestone milestone;
  final String pactId;
  final bool isLast;
  final bool isV2;

  @override
  Widget build(BuildContext context) {
    final stateStyle = PactStateStyle.forMilestoneState(milestone.state);
    final isPaid = milestone.state == 'paid';
    final isCurrent = milestone.state != 'paid' &&
        milestone.state != 'pending';

    return InkWell(
      onTap: () =>
          context.push('/pacts/$pactId/milestones/${milestone.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Línea de timeline
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.psBlue
                            : AppColors.ink200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isPaid
                        ? const Icon(Icons.check,
                            color: AppColors.white, size: 14)
                        : Text(
                            '${milestone.ordinal}',
                            style: AppTypography.caption.copyWith(
                              color: isCurrent
                                  ? AppColors.white
                                  : AppColors.ink600,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.ink200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Contenido
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone.name,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      PactStateBadge(style: stateStyle, compact: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        AppFormatters.moneyShort(milestone.amountCents),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.psBlue,
                        ),
                      ),
                      if (milestone.targetDate != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: AppColors.ink500),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(milestone.targetDate!),
                          style: AppTypography.bodyS
                              .copyWith(color: AppColors.ink500),
                        ),
                      ],
                    ],
                  ),
                  if (milestone.description != null &&
                      milestone.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      milestone.description!,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink600),
                    ),
                  ],
                  // Badges v2: factura, doc detallado, versión editada
                  if (isV2 && (milestone.hasInvoice ||
                      milestone.hasDetailedDoc ||
                      milestone.isEdited)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (milestone.hasInvoice)
                          _MilestoneBadge(
                            icon: Icons.receipt_long_outlined,
                            label: milestone.invoiceNumber != null
                                ? 'F: ${milestone.invoiceNumber}'
                                : 'Factura',
                            color: AppColors.success,
                          ),
                        if (milestone.hasDetailedDoc)
                          const _MilestoneBadge(
                            icon: Icons.description_outlined,
                            label: 'Doc',
                            color: AppColors.psBlue,
                          ),
                        if (milestone.isEdited)
                          _MilestoneBadge(
                            icon: Icons.history,
                            label: 'v${milestone.version}',
                            color: AppColors.ink500,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Mini badge para los hitos en v2 (factura, doc adjunto, versión editada).
class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppTypography.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 10)),
        ],
      ),
    );
  }
}

// =====================================================================
// NEXT STEP CTA — acciones contextuales según mi rol y estado del pacto
// =====================================================================

class _NextStepCta extends ConsumerStatefulWidget {
  const _NextStepCta({required this.detail});

  final PactDetail detail;

  @override
  ConsumerState<_NextStepCta> createState() => _NextStepCtaState();
}

class _NextStepCtaState extends ConsumerState<_NextStepCta> {
  bool _accepting = false;
  String? _error;

  Future<void> _mockFund() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Activar obra (modo dev)?'),
        content: const Text(
          'Esto simula el depósito del promotor. El pacto pasará a "En ejecución" y se activará el primer hito. En producción, esto lo hará Mangopay tras confirmar el ingreso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await ref
          .read(pactsRepositoryProvider)
          .mockFundPact(widget.detail.pact.id);
      ref.invalidate(myPactsProvider);
      ref.invalidate(pactDetailProvider(widget.detail.pact.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('Obra activada · primer hito en curso',
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _accept() async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await ref.read(pactsRepositoryProvider).acceptInvitation(
            widget.detail.pact.id,
          );
      ref.invalidate(myPactsProvider);
      ref.invalidate(pactDetailProvider(widget.detail.pact.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('Invitación aceptada',
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final me = detail.me;
    final state = detail.pact.state;

    // Caso 1 — soy parte invitada y no he aceptado
    if (me != null && !me.hasAccepted && state == 'inviting') {
      return _PrimaryActionCard(
        title: 'Tienes una invitación pendiente',
        description:
            'Como ${_roleLabel(me.role)}, tu aceptación es necesaria para que el pacto avance a firma.',
        cta: _accepting ? 'Aceptando…' : 'Aceptar invitación',
        icon: Icons.mail_outline,
        loading: _accepting,
        onPressed: _accepting ? null : _accept,
        error: _error,
      );
    }

    // Caso 2 — soy parte, ya acepté, pero no he firmado y el pact está en firma
    if (me != null &&
        me.hasAccepted &&
        !me.hasSigned &&
        (state == 'signing' || state == 'inviting')) {
      // En 'inviting' permito leer y firmar por adelantado solo si la
      // BD lo aceptara, pero por seguridad pedimos signing primero.
      final unlocked = state == 'signing';
      return _PrimaryActionCard(
        title: unlocked
            ? 'Es momento de firmar el contrato'
            : 'Pendiente de que todas las partes acepten',
        description: unlocked
            ? 'Lee el contrato completo. Tu firma electrónica tiene la misma validez legal que una manuscrita.'
            : 'Cuando todas las partes acepten, podrás firmar el contrato.',
        cta: 'Leer y firmar contrato',
        icon: Icons.draw,
        onPressed: unlocked
            ? () => context.push('/pacts/${detail.pact.id}/sign')
            : null,
      );
    }

    // Caso 3 — todos firmaron, pacto signed → activar la ejecución
    if (state == 'signed') {
      if (me?.role == 'promotor') {
        return _PrimaryActionCard(
          title: 'Activa la ejecución de la obra',
          description:
              'Mock del depósito Mangopay (chunk 5 lo sustituye por la pasarela real). Al confirmar, el primer hito arranca y el constructor podrá subir evidencias.',
          cta: 'Activar obra (modo dev)',
          icon: Icons.play_arrow_rounded,
          onPressed: () => _mockFund(),
        );
      }
      return _InfoCard(
        title: 'Esperando que el promotor active la obra',
        description:
            'En cuanto el promotor active el depósito, el constructor podrá empezar a subir evidencias del primer hito.',
      );
    }

    // Caso 4 — pacto activo
    if (state == 'in_execution' || state == 'active') {
      final next = detail.nextMilestone;
      if (next != null) {
        return _InfoCard(
          title: 'Hito en curso: ${next.name}',
          description:
              'El constructor sube evidencias y el técnico (u el promotor en obra menor) valida.',
        );
      }
    }

    // Caso 5 — esperando aceptaciones de otros
    if (state == 'inviting' && me != null && me.hasAccepted) {
      final pending =
          detail.parties.where((p) => !p.hasAccepted).length;
      return _InfoCard(
        title: 'Esperando aceptaciones',
        description:
            '$pending parte${pending == 1 ? "" : "s"} aún no han aceptado. Cuando todas acepten, podréis firmar.',
      );
    }

    return const SizedBox.shrink();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'promotor':
        return 'promotor';
      case 'constructor':
        return 'constructor';
      case 'tecnico':
        return 'arquitecto técnico';
      default:
        return role;
    }
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.title,
    required this.description,
    required this.cta,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.error,
  });

  final String title;
  final String description;
  final String cta;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.psGradientDeep,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.psCyan, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: AppTypography.h3
                        .copyWith(color: AppColors.white)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(description,
              style: AppTypography.bodyS.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85))),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error!,
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            icon: loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.psNavy,
                    ),
                  )
                : const Icon(Icons.arrow_forward),
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.psNavy,
            ),
            label: Text(cta),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.psBlue, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              color: AppColors.psBlue, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(description,
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
