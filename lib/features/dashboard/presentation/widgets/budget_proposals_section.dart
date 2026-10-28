import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/budget_proposals.dart';
import '../../data/dashboard_providers.dart';
import 'dashboard_shared.dart';

/// Presupuestos que constructores han enviado al promotor desde CostPact.
/// Sin propuestas pendientes no ocupa sitio.
class BudgetProposalsSection extends ConsumerWidget {
  const BudgetProposalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals = ref.watch(budgetProposalsProvider).valueOrNull ?? const [];
    if (proposals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionHeader(title: 'Presupuestos recibidos'),
        const SizedBox(height: AppSpacing.sm),
        for (final p in proposals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ProposalCard(proposal: p),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _ProposalCard extends ConsumerStatefulWidget {
  const _ProposalCard({required this.proposal});
  final BudgetProposal proposal;

  @override
  ConsumerState<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends ConsumerState<_ProposalCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final pactId = await acceptBudgetProposal(widget.proposal.id);
      ref.invalidate(budgetProposalsProvider);
      ref.invalidate(dashboardDataProvider);
      if (mounted) context.push('/pacts/$pactId');
    } catch (e) {
      _fail('No se pudo crear la obra: $e');
    }
  }

  Future<void> _decline() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar presupuesto'),
        content: Text(
            '${widget.proposal.constructorName} podrá enviarte una versión nueva desde CostPact.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rechazar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await declineBudgetProposal(widget.proposal.id);
      ref.invalidate(budgetProposalsProvider);
    } catch (e) {
      _fail('No se pudo rechazar: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final co = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: co.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600, color: co.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${p.constructorName} · ${p.planItems} hitos',
                      style: AppTypography.bodyS.copyWith(color: co.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(AppFormatters.moneyShort(p.totalAmountCents),
                  style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600, color: co.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Al aceptarlo se crea la obra a tu nombre, en borrador, con el '
            'constructor invitado. Podrás revisarla antes de firmar.',
            style: AppTypography.caption.copyWith(color: co.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _decline,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _accept,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Crear la obra'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
