import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_detail.dart';

/// Widget de "Custodia activa" (v2.1) o "Depósito en custodia" (v2.0).
///
/// Se adapta al modelo según `pact.modelVersion`:
///   - v2.0: muestra balance del depósito, alerta si está bajo, CTA depositar/reponer
///   - v2.1: muestra reserva custodiada + anticipo asegurado + póliza
///
/// El nombre `DepositWidget` se mantiene por compatibilidad con los imports.
class DepositWidget extends StatelessWidget {
  const DepositWidget({
    super.key,
    required this.detail,
    this.onFundInitial,
    this.onReplenish,
    this.onSetupAdvance,
  });

  final PactDetail detail;

  /// v2.0 · promotor pulsa "Depositar X €" (estado signed)
  final VoidCallback? onFundInitial;

  /// v2.0 · promotor pulsa "Reponer depósito"
  final VoidCallback? onReplenish;

  /// v2.1 · promotor pulsa "Configurar Adelanto" (estado signed)
  final VoidCallback? onSetupAdvance;

  @override
  Widget build(BuildContext context) {
    final pact = detail.pact;
    if (!pact.isV2OrLater) return const SizedBox.shrink();

    // En v2.1 usamos el nuevo render. En v2.0 reusamos el clásico.
    if (pact.isV21) {
      return _CustodyWidgetV21(
        detail: detail,
        onSetupAdvance: onSetupAdvance,
      );
    }
    return _DepositWidgetV20(
      detail: detail,
      onFundInitial: onFundInitial,
      onReplenish: onReplenish,
    );
  }
}

// =====================================================================
// V2.1 · Custodia activa (Adelanto + reserva + póliza)
// =====================================================================

class _CustodyWidgetV21 extends StatelessWidget {
  const _CustodyWidgetV21({
    required this.detail,
    this.onSetupAdvance,
  });

  final PactDetail detail;
  final VoidCallback? onSetupAdvance;

  @override
  Widget build(BuildContext context) {
    final pact = detail.pact;
    final policy = detail.suretyPolicy;
    final myRole = detail.me?.role;
    final isPromotor = myRole == 'promotor';

    // El Adelanto se considera "configurado" cuando ya se ejecutó
    // sf_pact_setup_advance (es decir, hay algo entregado al constructor).
    // Mientras eso no pase, el widget está en modo "pendiente de Adelanto".
    final isAdvanceSetup = pact.advanceReleasedCents > 0;

    if (!isAdvanceSetup) {
      // CTA disponible solo cuando el pacto está firmado por todas las partes.
      final canSetupNow = pact.state == 'signed';
      return _UnfundedV21(
        detail: detail,
        onSetupAdvance:
            (isPromotor && canSetupNow) ? onSetupAdvance : null,
        canSetupNow: canSetupNow,
      );
    }

    // Estado en ejecución: muestra reserva + anticipo + póliza
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.success, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: AppColors.success),
              const SizedBox(width: AppSpacing.xs),
              Text('Custodia activa',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (pact.depositRequiredPct != null)
                _MiniPill(
                  label:
                      'Adelanto ${pact.depositRequiredPct!.toStringAsFixed(0)} %',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Bloque 1 · Reserva custodiada
          _CustodyBlock(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.success,
            label: 'Reserva de finiquito',
            sublabel: pact.advanceReservePct != null
                ? '${pact.advanceReservePct!.toStringAsFixed(0)} % custodiado en PactStream'
                : 'Custodiada hasta el finiquito',
            value: AppFormatters.moneyLong(pact.advanceReserveCents),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Bloque 2 · Anticipo asegurado (con barra de cobertura)
          if (pact.advanceReleasedCents > 0)
            _AdvanceCoverageBlock(
              releasedCents: pact.advanceReleasedCents,
              outstandingCents: pact.advanceOutstandingCents,
              policy: policy,
            ),

          // Bloque 3 · Pre-depósitos en curso (suma deposit_current - reserva)
          if (pact.depositCurrentCents > pact.advanceReserveCents) ...[
            const SizedBox(height: AppSpacing.sm),
            _CustodyBlock(
              icon: Icons.savings_outlined,
              iconColor: AppColors.psBlue,
              label: 'Pre-depósitos en curso',
              sublabel: 'Esperando validación técnica para liberar',
              value: AppFormatters.moneyLong(
                  pact.depositCurrentCents - pact.advanceReserveCents),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Footer · obra ejecutada
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: Row(
              children: [
                Text('Obra ejecutada',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.ink600)),
                const Spacer(),
                Text(
                  '${AppFormatters.moneyShort(pact.budgetConsumedCents)} / ${AppFormatters.moneyShort(pact.totalAmountCents)}',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnfundedV21 extends StatelessWidget {
  const _UnfundedV21({
    required this.detail,
    this.onSetupAdvance,
    this.canSetupNow = false,
  });

  final PactDetail detail;
  final VoidCallback? onSetupAdvance;
  /// `true` si el pacto ya está firmado por todas las partes y el promotor
  /// puede configurar el Adelanto. `false` si aún está en `inviting`/`signing`.
  final bool canSetupNow;

  @override
  Widget build(BuildContext context) {
    final pact = detail.pact;
    final totalAdvance = pact.totalAdvanceCents;
    final subtitle = canSetupNow
        ? 'pendiente de depositar como Adelanto'
        : 'a depositar cuando todas las partes hayan firmado';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.psBlue, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: AppColors.psBlue),
              const SizedBox(width: AppSpacing.xs),
              Text('Configurar Adelanto',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (pact.depositRequiredPct != null)
                _MiniPill(
                  label:
                      '${pact.depositRequiredPct!.toStringAsFixed(0)} % pactado',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppFormatters.moneyLong(totalAdvance),
              style: AppTypography.h1.copyWith(color: AppColors.psNavy)),
          Text(
            subtitle,
            style: AppTypography.bodyS.copyWith(color: AppColors.ink600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Reserva de finiquito',
                          style: AppTypography.caption),
                    ),
                    Text(
                      AppFormatters.moneyShort(pact.advanceReserveCents),
                      style: AppTypography.caption
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined,
                        size: 14, color: AppColors.psBlue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Anticipo al constructor (día 1)',
                          style: AppTypography.caption),
                    ),
                    Text(
                      AppFormatters.moneyShort(pact.advanceVariableCents),
                      style: AppTypography.caption
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (onSetupAdvance != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_outline, size: 18),
              onPressed: onSetupAdvance,
              label: Text(
                'Configurar Adelanto · ${AppFormatters.moneyShort(totalAdvance)}',
              ),
            ),
        ],
      ),
    );
  }
}

class _CustodyBlock extends StatelessWidget {
  const _CustodyBlock({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.bodyS
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(sublabel,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.ink500)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(value,
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800, color: iconColor)),
        ],
      ),
    );
  }
}

/// Bloque del Anticipo asegurado con barra de cobertura decreciente.
class _AdvanceCoverageBlock extends StatelessWidget {
  const _AdvanceCoverageBlock({
    required this.releasedCents,
    required this.outstandingCents,
    this.policy,
  });

  final int releasedCents;
  final int outstandingCents;
  final SuretyPolicy? policy;

  @override
  Widget build(BuildContext context) {
    final coverage = releasedCents <= 0
        ? 0.0
        : (outstandingCents / releasedCents).clamp(0.0, 1.0);

    final isAdminPending = policy?.isPendingAdmin ?? true;
    final policyLabel = isAdminPending
        ? 'Póliza pendiente de admin'
        : 'Asegurado por ${policy!.insurerName}';
    final policyColor =
        isAdminPending ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.payments_outlined,
                  size: 18, color: AppColors.psBlue),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anticipo asegurado',
                        style: AppTypography.bodyS
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      'Saldo vivo de la cobertura (decrece con cada cert)',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(AppFormatters.moneyShort(outstandingCents),
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w800)),
                  Text('de ${AppFormatters.moneyShort(releasedCents)}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: coverage,
              minHeight: 6,
              backgroundColor: AppColors.ink200,
              valueColor: const AlwaysStoppedAnimation(AppColors.psBlue),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                isAdminPending
                    ? Icons.pending_outlined
                    : Icons.verified_outlined,
                size: 12,
                color: policyColor,
              ),
              const SizedBox(width: 4),
              Text(
                policyLabel,
                style: AppTypography.caption.copyWith(
                  color: policyColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(color: AppColors.ink600)),
    );
  }
}

// =====================================================================
// V2.0 · Render clásico (compatible con pacts antiguos del Sprint 4)
// =====================================================================

class _DepositWidgetV20 extends StatelessWidget {
  const _DepositWidgetV20({
    required this.detail,
    this.onFundInitial,
    this.onReplenish,
  });

  final PactDetail detail;
  final VoidCallback? onFundInitial;
  final VoidCallback? onReplenish;

  @override
  Widget build(BuildContext context) {
    final pact = detail.pact;
    final required = pact.depositRequiredCents;
    final current = pact.depositCurrentCents;
    final pct = required == 0 ? 0.0 : (current / required).clamp(0.0, 1.0);

    final isLow = detail.isDepositLow && pact.state == 'in_execution';
    final isUnfunded = pact.state == 'signed';
    final accent = isLow
        ? AppColors.warning
        : (isUnfunded ? AppColors.psBlue : AppColors.success);
    final bg = isLow
        ? AppColors.warningBg
        : (isUnfunded ? AppColors.infoBg : AppColors.successBg);

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
          Row(
            children: [
              Icon(Icons.account_balance_outlined, size: 18, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Text('Depósito en custodia',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (pact.depositRequiredPct != null)
                _MiniPill(
                  label:
                      '${pact.depositRequiredPct!.toStringAsFixed(0)} % pactado',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isUnfunded) ...[
            Text(AppFormatters.moneyLong(required),
                style: AppTypography.h1.copyWith(color: AppColors.psNavy)),
            Text('pendiente de depositar',
                style: AppTypography.bodyS.copyWith(color: AppColors.ink600)),
            const SizedBox(height: AppSpacing.md),
            if (isPromotor && onFundInitial != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.shield_outlined, size: 18),
                onPressed: onFundInitial,
                label: Text('Depositar ${AppFormatters.moneyShort(required)}'),
              ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(AppFormatters.moneyLong(current),
                    style: AppTypography.h1.copyWith(color: AppColors.psNavy)),
                const SizedBox(width: AppSpacing.xs),
                Text('/ ${AppFormatters.moneyShort(required)}',
                    style:
                        AppTypography.body.copyWith(color: AppColors.ink500)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.white,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${(pct * 100).toStringAsFixed(0)} % del depósito requerido',
              style: AppTypography.caption.copyWith(color: AppColors.ink600),
            ),
          ],
          if (isLow && isPromotor && onReplenish != null) ...[
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
      ),
    );
  }
}
