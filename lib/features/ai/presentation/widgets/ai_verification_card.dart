/// Card del dictamen IA para la pantalla MilestoneDetailPage.
///
/// Se incrusta entre la sección de Evidencias y los CTAs de validación.
/// Muestra:
///   - Score (0-100) con barra de progreso
///   - Verdict badge (ok / review_needed / block)
///   - Summary
///   - Findings con severidad (verde / ámbar / rojo)
///   - Checklist match (✓ / ✗)
///   - Recomendación
///   - Botón "Verificar con IA" si aún no hay dictamen o el usuario quiere
///     uno nuevo.
///
/// Cuando no hay dictamen previo, muestra un estado vacío con CTA de
/// "Analizar evidencias". Solo se muestra si el hito tiene ≥ 1 evidencia.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/ai_models.dart';
import '../../data/ai_providers.dart';
import 'ai_verdict_badge.dart';

class AiVerificationCard extends ConsumerWidget {
  const AiVerificationCard({
    super.key,
    required this.pactId,
    required this.milestoneId,
    required this.evidenceCount,
  });

  final String pactId;
  final String milestoneId;
  final int evidenceCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationAsync =
        ref.watch(milestoneVerificationProvider(milestoneId));
    final verifyState =
        ref.watch(visionVerifyNotifierProvider(milestoneId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: AppColors.psBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con gradiente IA
          _AiCardHeader(
            verifyState: verifyState,
            onVerify: evidenceCount > 0
                ? () => ref
                    .read(visionVerifyNotifierProvider(milestoneId).notifier)
                    .verify(pactId: pactId, milestoneId: milestoneId)
                : null,
          ),
          // Contenido
          verificationAsync.when(
            loading: () => const _LoadingBody(),
            error: (e, _) => _ErrorBody(
              message: e.toString(),
              onRetry: () => ref.invalidate(
                  milestoneVerificationProvider(milestoneId)),
            ),
            data: (verification) {
              if (verifyState is VisionVerifyLoading) {
                return const _AnalyzingBody();
              }
              if (verifyState is VisionVerifyError) {
                return _ErrorBody(
                  message: (verifyState as VisionVerifyError).message,
                  onRetry: () => ref
                      .read(visionVerifyNotifierProvider(milestoneId).notifier)
                      .reset(),
                );
              }

              // Usar el resultado más reciente entre BD y la última llamada.
              final latest = verifyState is VisionVerifyDone
                  ? (verifyState as VisionVerifyDone).verification
                  : verification;

              if (latest == null) {
                return _EmptyBody(
                  evidenceCount: evidenceCount,
                  onVerify: evidenceCount > 0
                      ? () => ref
                          .read(visionVerifyNotifierProvider(milestoneId)
                              .notifier)
                          .verify(
                              pactId: pactId, milestoneId: milestoneId)
                      : null,
                );
              }

              return _VerificationBody(verification: latest);
            },
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// HEADER
// =====================================================================

class _AiCardHeader extends StatelessWidget {
  const _AiCardHeader({
    required this.verifyState,
    required this.onVerify,
  });

  final VisionVerifyState verifyState;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final isLoading = verifyState is VisionVerifyLoading;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.psNavy,
            AppColors.psBlue.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.md)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.psCyan.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppColors.psCyan, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Análisis IA',
                  style: AppTypography.body.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Claude Vision · PactStream',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.psCyan,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (onVerify != null && !isLoading)
            TextButton(
              onPressed: onVerify,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.psCyan,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Analizar',
                style: AppTypography.caption.copyWith(
                  color: AppColors.psCyan,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// ESTADOS VACÍOS / CARGA / ERROR
// =====================================================================

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _AnalyzingBody extends StatelessWidget {
  const _AnalyzingBody();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.psBlue),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Analizando evidencias…',
            style: AppTypography.bodyS
                .copyWith(color: AppColors.ink600),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: 32),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No se pudo obtener el análisis',
            style: AppTypography.body
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                AppTypography.bodyS.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
              onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.evidenceCount, required this.onVerify});
  final int evidenceCount;
  final VoidCallback? onVerify;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              color: AppColors.ink400, size: 32),
          const SizedBox(height: AppSpacing.xs),
          Text(
            evidenceCount > 0
                ? 'Aún no hay análisis IA para este hito'
                : 'Sube al menos una evidencia para activar el análisis IA',
            textAlign: TextAlign.center,
            style: AppTypography.body
                .copyWith(fontWeight: FontWeight.w700),
          ),
          if (evidenceCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Claude Vision revisará las $evidenceCount evidencia${evidenceCount == 1 ? "" : "s"} contra el checklist del hito.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              onPressed: onVerify,
              label: const Text('Analizar evidencias'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.psBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// RESULTADO DEL DICTAMEN
// =====================================================================

class _VerificationBody extends StatelessWidget {
  const _VerificationBody({required this.verification});
  final AiVerification verification;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score + Verdict
          _ScoreRow(verification: verification),
          const SizedBox(height: AppSpacing.sm),
          // Summary
          Text(
            verification.summary,
            style:
                AppTypography.body.copyWith(color: AppColors.ink700),
          ),
          // Findings
          if (verification.findings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _FindingsList(findings: verification.findings),
          ],
          // Checklist match
          if (verification.checklistMatch.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _ChecklistMatchList(items: verification.checklistMatch),
          ],
          // Recomendación
          if (verification.recommendation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: AppRadius.xsAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 14, color: AppColors.psBlue),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      verification.recommendation,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Demo badge + fecha
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (verification.isDemo)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.psNavy.withValues(alpha: 0.08),
                    borderRadius: AppRadius.xsAll,
                    border: Border.all(
                        color:
                            AppColors.psNavy.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'DEMO',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.psNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (verification.isDemo) const SizedBox(width: AppSpacing.sm),
              Text(
                _fmtDate(verification.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink400,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.verification});
  final AiVerification verification;

  @override
  Widget build(BuildContext context) {
    final scoreColor = switch (verification.verdict) {
      AiVerdict.ok           => AppColors.success,
      AiVerdict.reviewNeeded => AppColors.warning,
      AiVerdict.block        => AppColors.error,
    };
    return Row(
      children: [
        // Score circle
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: verification.score / 100.0,
                strokeWidth: 5,
                backgroundColor: AppColors.ink200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(scoreColor),
              ),
              Text(
                '${verification.score}',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiVerdictBadge(verdict: verification.verdict),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${verification.findings.length} hallazgo${verification.findings.length == 1 ? "" : "s"}'
                ' · ${verification.checklistMatch.where((c) => c.evidenceOk).length}/${verification.checklistMatch.length} checklist',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FindingsList extends StatelessWidget {
  const _FindingsList({required this.findings});
  final List<AiFinding> findings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hallazgos',
          style: AppTypography.bodyS.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.ink600),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final f in findings) ...[
          _FindingItem(finding: f),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _FindingItem extends StatelessWidget {
  const _FindingItem({required this.finding});
  final AiFinding finding;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (finding.severity) {
      AiFindingSeverity.green => AppColors.success,
      AiFindingSeverity.amber => AppColors.warning,
      AiFindingSeverity.red   => AppColors.error,
    };
    final bgColor = switch (finding.severity) {
      AiFindingSeverity.green => AppColors.successBg,
      AiFindingSeverity.amber => AppColors.warningBg,
      AiFindingSeverity.red   => AppColors.errorBg,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.xsAll,
        border: Border.all(
            color: borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: AiFindingSeverityDot(severity: finding.severity),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (finding.evidenceRef != null)
                  Text(
                    finding.evidenceRef!.split('/').last,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      letterSpacing: 0,
                      fontFamily: 'monospace',
                    ),
                  ),
                Text(
                  finding.message,
                  style: AppTypography.bodyS,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistMatchList extends StatelessWidget {
  const _ChecklistMatchList({required this.items});
  final List<AiChecklistMatch> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checklist',
          style: AppTypography.bodyS.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.ink600),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.evidenceOk
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: item.evidenceOk
                      ? AppColors.success
                      : AppColors.ink400,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.bodyS.copyWith(
                          color: item.evidenceOk
                              ? AppColors.ink700
                              : AppColors.ink500,
                        ),
                      ),
                      if (item.note != null)
                        Text(
                          item.note!,
                          style: AppTypography.caption.copyWith(
                              color: AppColors.ink500, letterSpacing: 0),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
