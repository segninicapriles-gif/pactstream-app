import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_detail.dart';

/// Línea de tiempo del dinero — genera confianza mostrando dónde está
/// cada euro depositado en cada momento (auditoría 16-jul: en fintech
/// es el generador de confianza nº1).
///
/// 4 hitos visuales de izquierda a derecha:
///
///   ● Depositado ───── ● En custodia ───── ● Liberado ───── ● Cobrado
///
/// El paso "actual" (aquel donde vive el grueso del dinero ahora) se
/// destaca en color de marca; los completados en verde; los pendientes
/// en gris. Cada uno lleva su importe debajo.
///
/// Requiere que el usuario pueda ver economics (`canViewEconomics`) —
/// si no, no se debe montar (el llamador lo comprueba).
class MoneyTimeline extends StatelessWidget {
  const MoneyTimeline({super.key, required this.detail});

  final PactDetail detail;

  @override
  Widget build(BuildContext context) {
    final pact = detail.pact;

    // ─── Cálculo de importes por estado ────────────────────────────────
    // Modelo v2.1 (con Adelanto de doble garantía):
    //   depositado    = totalAdvanceCents         (Hito 0 completo puesto por el promotor)
    //   en custodia   = depositCurrentCents       (reserva + no consumido)
    //   liberado      = advanceReleasedCents + budgetConsumedCents
    //   cobrado       = suma de milestones con paid_at (aprox: budgetConsumedCents)
    //
    // v1/v2.0 caen a un modelo simplificado sin reserva.
    final deposited = pact.isV2OrLater ? pact.totalAdvanceCents : pact.totalAmountCents;
    final inCustody = pact.depositCurrentCents;
    final released = pact.advanceReleasedCents + pact.budgetConsumedCents;
    final collected = detail.milestones
        .where((m) => m.paidAt != null)
        .fold<int>(0, (sum, m) => sum + m.amountCents);

    // ─── Determinar el paso "actual" ─────────────────────────────────
    // Regla: el estado más avanzado alcanzado > 0.
    int currentStep;
    if (collected > 0) {
      currentStep = 3;
    } else if (released > 0) {
      currentStep = 2;
    } else if (inCustody > 0) {
      currentStep = 1;
    } else {
      currentStep = 0;
    }

    final steps = <_TimelineStep>[
      _TimelineStep(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Depositado',
        sublabel: 'por el promotor',
        amountCents: deposited,
      ),
      _TimelineStep(
        icon: Icons.shield_outlined,
        label: 'En custodia',
        sublabel: 'protegido por póliza',
        amountCents: inCustody,
      ),
      _TimelineStep(
        icon: Icons.local_shipping_outlined,
        label: 'Liberado',
        sublabel: 'al constructor',
        amountCents: released,
      ),
      _TimelineStep(
        icon: Icons.task_alt_outlined,
        label: 'Cobrado',
        sublabel: 'certificado y pagado',
        amountCents: collected,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Recorrido del dinero',
                style: AppTypography.bodyS.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _stepStatusLabel(currentStep),
                style: AppTypography.caption
                    .copyWith(color: context.colors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _TimelineRow(steps: steps, currentStep: currentStep),
        ],
      ),
    );
  }

  static String _stepStatusLabel(int step) {
    switch (step) {
      case 0:
        return 'Pendiente de depósito';
      case 1:
        return 'En custodia PactStream';
      case 2:
        return 'Entregado, pendiente de certificar';
      case 3:
        return 'Certificado y liquidado';
      default:
        return '';
    }
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.amountCents,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final int amountCents;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.steps, required this.currentStep});

  final List<_TimelineStep> steps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Conector entre pasos: activo si el paso anterior está
          // completado (currentStep supera el índice del paso anterior).
          final prevStep = (i - 1) ~/ 2;
          final isDone = prevStep < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 18), // alinea con el círculo del icono
              child: Container(
                height: 2,
                color: isDone ? AppColors.success : context.colors.divider,
              ),
            ),
          );
        }
        final stepIdx = i ~/ 2;
        return _TimelineNode(
          step: steps[stepIdx],
          state: stepIdx < currentStep
              ? _NodeState.done
              : stepIdx == currentStep
                  ? _NodeState.current
                  : _NodeState.pending,
        );
      }),
    );
  }
}

enum _NodeState { done, current, pending }

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.step, required this.state});

  final _TimelineStep step;
  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconColor, ring) = switch (state) {
      _NodeState.done => (
          AppColors.success.withOpacity(0.15),
          AppColors.success,
          AppColors.success,
        ),
      _NodeState.current => (
          context.colors.brandAccentBg,
          context.colors.brandAccent,
          context.colors.brandAccent,
        ),
      _NodeState.pending => (
          context.colors.card,
          context.colors.textTertiary,
          context.colors.border,
        ),
    };

    final labelColor = state == _NodeState.pending
        ? context.colors.textTertiary
        : context.colors.textPrimary;

    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: state == _NodeState.current ? 2 : 1),
            ),
            child: Icon(step.icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            step.label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontWeight: state == _NodeState.pending ? FontWeight.w500 : FontWeight.w700,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppFormatters.moneyShort(step.amountCents),
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: state == _NodeState.pending
                  ? context.colors.textTertiary
                  : iconColor,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            step.sublabel,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: context.colors.textTertiary,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
