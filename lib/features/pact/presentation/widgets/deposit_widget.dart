import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_detail.dart';

/// Card del depósito en custodia (solo se renderiza en pacts v2.0).
///
/// Muestra el balance actual, el % del presupuesto consumido y un CTA
/// contextual según el rol y el estado:
///   - Promotor con depósito bajo  → "Reponer depósito"
///   - Promotor con pacto firmado y aún sin depositar → "Depositar X €"
///   - Resto → solo visualización
class DepositWidget extends StatelessWidget {
  const DepositWidget({
    super.key,
    required this.detail,
    this.onFundInitial,
    this.onReplenish,
  });

  final PactDetail detail;

  /// Callback cuando el promotor pulsa "Depositar X €" (estado signed).
  final VoidCallback? onFundInitial;

  /// Callback cuando el promotor pulsa "Reponer depósito".
  final VoidCallback? onReplenish;

  @override
  Widget build(BuildContext context) {
    final pact = detail.pact;
    if (!pact.isV2) return const SizedBox.shrink();

    final required = pact.depositRequiredCents;
    final current = pact.depositCurrentCents;
    final pct = required == 0 ? 0.0 : (current / required).clamp(0.0, 1.0);

    // Estado visual del widget
    final isLow = detail.isDepositLow && pact.state == 'in_execution';
    final isUnfunded = pact.state == 'signed';
    final accent = isLow
        ? AppColors.warning
        : (isUnfunded ? AppColors.psBlue : AppColors.success);
    final bg = isLow
        ? AppColors.warningBg
        : (isUnfunded ? AppColors.infoBg : AppColors.successBg);

    // Rol del usuario actual (para CTAs)
    final myRole = detail.me?.role;
    final isPromotor = myRole == 'promotor';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: accent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.account_balance_outlined, size: 18, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Text('Depósito en custodia',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (pact.depositRequiredPct != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pact.depositRequiredPct!.toStringAsFixed(0)} % pactado',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.ink600),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Balance
          if (isUnfunded) ...[
            _UnfundedBlock(
              required: required,
              onFund: isPromotor ? onFundInitial : null,
            ),
          ] else ...[
            _BalanceBlock(
              current: current,
              required: required,
              pct: pct,
              accent: accent,
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Métricas inferiores
          _MetricsRow(
            consumed: pact.budgetConsumedCents,
            total: detail.effectiveBudgetCents,
            originalTotal: pact.totalAmountCents,
            addendumsCents: detail.addendumsTotalCents,
          ),

          // Alerta + CTA
          if (isLow) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                border: Border.all(color: AppColors.warning, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'El depósito está por debajo del 25 % del importe pactado. '
                      'El constructor podría parar la obra hasta que se reponga.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink900),
                    ),
                  ),
                ],
              ),
            ),
            if (isPromotor && onReplenish != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                onPressed: onReplenish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.white,
                ),
                label: const Text('Reponer depósito'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({
    required this.current,
    required this.required,
    required this.pct,
    required this.accent,
  });

  final int current;
  final int required;
  final double pct;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              AppFormatters.moneyLong(current),
              style: AppTypography.h1.copyWith(color: AppColors.psNavy),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '/ ${AppFormatters.moneyShort(required)}',
              style: AppTypography.body.copyWith(color: AppColors.ink500),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.white,
            valueColor: AlwaysStoppedAnimation(accent),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${(pct * 100).toStringAsFixed(0)} % del depósito requerido',
          style: AppTypography.caption.copyWith(color: AppColors.ink600),
        ),
      ],
    );
  }
}

class _UnfundedBlock extends StatelessWidget {
  const _UnfundedBlock({required this.required, this.onFund});

  final int required;
  final VoidCallback? onFund;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              AppFormatters.moneyLong(required),
              style: AppTypography.h1.copyWith(color: AppColors.psNavy),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('pendiente de depositar',
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.ink600)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'El pacto ya está firmado. El promotor debe depositar este importe en custodia para que el constructor pueda empezar la obra.',
          style: AppTypography.caption.copyWith(color: AppColors.ink600),
        ),
        if (onFund != null) ...[
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            icon: const Icon(Icons.shield_outlined, size: 18),
            onPressed: onFund,
            label: Text('Depositar ${AppFormatters.moneyShort(required)}'),
          ),
        ],
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.consumed,
    required this.total,
    required this.originalTotal,
    required this.addendumsCents,
  });

  final int consumed;
  final int total;
  final int originalTotal;
  final int addendumsCents;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Certificado',
            value: AppFormatters.moneyShort(consumed),
          ),
        ),
        Container(width: 1, height: 28, color: AppColors.ink200),
        Expanded(
          child: _Metric(
            label: 'Presupuesto',
            value: AppFormatters.moneyShort(total),
            sublabel: addendumsCents != 0
                ? '${addendumsCents > 0 ? '+' : ''}${AppFormatters.moneyShort(addendumsCents)} anexos'
                : null,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.sublabel});

  final String label;
  final String value;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style:
                AppTypography.caption.copyWith(color: AppColors.ink500)),
        Text(value,
            style:
                AppTypography.body.copyWith(fontWeight: FontWeight.w800)),
        if (sublabel != null)
          Text(sublabel!,
              style: AppTypography.caption
                  .copyWith(color: AppColors.ink500)),
      ],
    );
  }
}
