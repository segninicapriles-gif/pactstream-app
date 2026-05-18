import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_detail.dart';

/// Card que muestra una certificación esperando pre-depósito (v2.1).
///
/// Se renderiza para cada milestone en `pending_predeposit` o
/// `paused_no_predeposit`. Muestra el desglose bruto/amortización/neto,
/// el progreso del pre-depósito, el countdown y CTAs contextuales según
/// rol y estado.
class PredepositPendingCard extends StatelessWidget {
  const PredepositPendingCard({
    super.key,
    required this.milestone,
    required this.myRole,
    this.onPredeposit,
    this.onForceAdvance,
  });

  final PactMilestone milestone;
  final String? myRole;
  final VoidCallback? onPredeposit;
  final VoidCallback? onForceAdvance;

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final isPaused = m.isPausedNoPredeposit;
    final isPromotor = myRole == 'promotor';
    final isConstructor = myRole == 'constructor';

    final accent = isPaused ? AppColors.error : AppColors.warning;
    final bg = isPaused ? AppColors.errorBg : AppColors.warningBg;
    final stateLabel = isPaused
        ? 'OBRA PARALIZADA'
        : 'PENDIENTE DE PRE-DEPÓSITO';

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
              Icon(
                isPaused
                    ? Icons.pan_tool_outlined
                    : Icons.schedule_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Cert #${m.ordinal} · ${m.name}',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(stateLabel,
                    style: AppTypography.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    )),
              ),
            ],
          ),

          if (m.description != null) ...[
            const SizedBox(height: 4),
            Text(m.description!,
                style: AppTypography.bodyS.copyWith(color: AppColors.ink600)),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Desglose bruto / amortización / neto
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: Column(
              children: [
                _kv('Bruto certificado',
                    AppFormatters.moneyLong(m.amountCents)),
                _kv('Amortización del Adelanto',
                    '− ${AppFormatters.moneyShort(m.advanceAmortizationCents)}',
                    muted: true),
                Divider(height: AppSpacing.sm, color: AppColors.ink200),
                _kv('Neto a pre-depositar',
                    AppFormatters.moneyLong(m.netAmountCents),
                    emphasis: true,
                    color: accent),
              ],
            ),
          ),

          // Progress del pre-depósito (si hay parcial)
          if (m.predepositReceivedCents > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: m.predepositProgress,
                minHeight: 6,
                backgroundColor: AppColors.ink200,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pre-depositado: ${AppFormatters.moneyShort(m.predepositReceivedCents)} '
              '· Falta: ${AppFormatters.moneyShort(m.predepositRemainingCents)}',
              style: AppTypography.caption.copyWith(color: AppColors.ink600),
            ),
          ],

          // Countdown / estado de paro
          const SizedBox(height: AppSpacing.sm),
          if (isPaused)
            _PausedNotice()
          else
            _CountdownNotice(deadline: m.predepositDeadlineAt),

          // Forced under responsibility (info)
          if (m.forcedUnderResponsibility) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.ink900.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel,
                      size: 14, color: AppColors.ink600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'El constructor avanza bajo su propia responsabilidad.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // CTAs
          if (isPromotor && onPredeposit != null) ...[
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 18),
              onPressed: onPredeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppColors.white,
              ),
              label: Text(
                'Pre-depositar ${AppFormatters.moneyShort(m.predepositRemainingCents)}',
              ),
            ),
          ],
          if (isConstructor && isPaused && onForceAdvance != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              onPressed: onForceAdvance,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
              label: const Text('Avanzar bajo mi responsabilidad'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v,
      {bool muted = false, bool emphasis = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: AppTypography.bodyS.copyWith(
                  color: muted ? AppColors.ink500 : AppColors.ink600,
                  fontWeight:
                      emphasis ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
          Text(v,
              style: AppTypography.body.copyWith(
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
                color: color ?? AppColors.ink900,
              )),
        ],
      ),
    );
  }
}

class _CountdownNotice extends StatelessWidget {
  const _CountdownNotice({this.deadline});
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    if (deadline == null) return const SizedBox.shrink();
    final diff = deadline!.difference(DateTime.now());
    final isOverdue = diff.isNegative;

    String label;
    if (isOverdue) {
      label = 'Plazo vencido · obra paralizable';
    } else if (diff.inDays > 0) {
      final h = diff.inHours - diff.inDays * 24;
      label = 'Quedan ${diff.inDays} d ${h} h antes del paro';
    } else if (diff.inHours > 0) {
      label = 'Quedan ${diff.inHours} h antes del paro';
    } else {
      label = 'Quedan ${diff.inMinutes} min antes del paro';
    }

    return Row(
      children: [
        Icon(Icons.timer_outlined,
            size: 14,
            color: isOverdue ? AppColors.error : AppColors.warning),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              style: AppTypography.caption.copyWith(
                color: isOverdue ? AppColors.error : AppColors.ink600,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }
}

class _PausedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.pan_tool_outlined,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Obra paralizada por falta de pre-depósito. El promotor debe completar el pre-depósito o el constructor puede avanzar bajo su responsabilidad.',
              style: AppTypography.caption.copyWith(color: AppColors.ink900),
            ),
          ),
        ],
      ),
    );
  }
}
