import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/error_humanizer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../ai/presentation/widgets/ai_verification_card.dart';
import '../../data/milestone_detail.dart';
import '../../data/pact_providers.dart';
import '../../data/dispute_actions.dart';
import '../widgets/pact_state_badge.dart';
import '../../../../core/widgets/cifra_viva.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/shimmer_box.dart';

/// Detalle de un hito + evidencias.
///
/// Vista común para los 3 roles:
///   - Constructor: ve sus evidencias + CTA "Subir evidencia" + CTA
///     "Marcar como listo" cuando hay ≥1 evidencia.
///   - Técnico: lista de evidencias en modo lectura. CTAs de validación
///     en chunk 5.
///   - Promotor: igual que técnico (en obra menor + obra mayor).
class MilestoneDetailPage extends ConsumerWidget {
  const MilestoneDetailPage({
    super.key,
    required this.pactId,
    required this.milestoneId,
  });

  final String pactId;
  final String milestoneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(milestoneDetailProvider(milestoneId));

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text('Hito',
            style: AppTypography.h3.copyWith(color: AppColors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () =>
                ref.invalidate(milestoneDetailProvider(milestoneId)),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const DetailSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudo cargar el hito',
          message: e.toString(),
          onRetry: () => ref.invalidate(milestoneDetailProvider(milestoneId)),
          scrollable: false,
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(milestoneDetailProvider(milestoneId));
            await ref.read(milestoneDetailProvider(milestoneId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Header(milestone: detail.milestone),
              const SizedBox(height: AppSpacing.md),
              _EvidencesSection(
                detail: detail,
                onUpload: detail.milestone.canUploadEvidence
                    ? () => context.push(
                          '/pacts/$pactId/milestones/$milestoneId/evidences/upload',
                        )
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              // === IA: Dictamen de evidencias ===
              AiVerificationCard(
                pactId: pactId,
                milestoneId: milestoneId,
                evidenceCount: detail.evidences.length,
              ),
              const SizedBox(height: AppSpacing.md),
              if (detail.milestone.canSubmitForReview &&
                  detail.evidences.isNotEmpty)
                _SubmitForReviewCta(
                  milestoneId: milestoneId,
                  evidenceCount: detail.evidences.length,
                )
              else if (detail.milestone.canTechReview)
                _TechReviewCta(milestone: detail.milestone)
              else if (detail.milestone.canPromotorDecide)
                _PromotorDecideCta(milestone: detail.milestone)
              else if (detail.milestone.needsConstructorRework)
                _ReworkBanner(milestone: detail.milestone)
              else if (detail.milestone.isPaid)
                _PaidBanner(milestone: detail.milestone)
              else if (detail.milestone.isInDispute)
                _DisputeBanner(milestone: detail.milestone),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// _ErrorView ahora usa ErrorStateView de core/widgets/empty_state_view.dart.

// =====================================================================
// HEADER
// =====================================================================

class _Header extends StatelessWidget {
  const _Header({required this.milestone});

  final MilestoneFull milestone;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    final stateStyle = PactStateStyle.forMilestoneState(milestone.state, context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: co.card,
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
                decoration: const BoxDecoration(
                  color: AppColors.psBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${milestone.ordinal}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  milestone.name,
                  style: AppTypography.h2.copyWith(fontSize: 22, color: co.textPrimary),
                ),
              ),
              PactStateBadge(style: stateStyle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            milestone.displayId,
            style: AppTypography.mono
                .copyWith(fontSize: 11, color: co.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.psNavy,
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CifraViva(
                  amountCents: milestone.amountCents,
                  showDecimals: true,
                  size: CifraViva.xl,
                  color: AppColors.white,
                ),
                if (milestone.targetDate != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.psCyan),
                      const SizedBox(width: 4),
                      Text(_date(milestone.targetDate!),
                          style: AppTypography.bodyS
                              .copyWith(color: AppColors.psCyan)),
                    ],
                  ),
              ],
            ),
          ),
          if (milestone.description != null &&
              milestone.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(milestone.description!.trim(),
                style: AppTypography.body
                    .copyWith(color: co.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pacto: ${milestone.pactTitle} · ${milestone.pactDisplayId}',
            style: AppTypography.bodyS.copyWith(color: co.textTertiary),
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// =====================================================================
// EVIDENCIAS
// =====================================================================

class _EvidencesSection extends StatelessWidget {
  const _EvidencesSection({
    required this.detail,
    required this.onUpload,
  });

  final MilestoneDetail detail;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: co.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Evidencias', style: AppTypography.h3.copyWith(color: co.textPrimary)),
              ),
              if (onUpload != null)
                FilledButton.icon(
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  onPressed: onUpload,
                  label: const Text('Subir'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${detail.evidences.length} evidencia${detail.evidences.length == 1 ? "" : "s"} aportada${detail.evidences.length == 1 ? "" : "s"}',
            style: AppTypography.bodyS.copyWith(color: co.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (detail.evidences.isEmpty)
            _EmptyEvidences(canUpload: onUpload != null)
          else
            for (final ev in detail.evidences) ...[
              _EvidenceCard(evidence: ev),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _EmptyEvidences extends StatelessWidget {
  const _EmptyEvidences({required this.canUpload});

  final bool canUpload;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: co.scaffold,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: co.border),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera_outlined,
              color: co.textHint, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canUpload ? 'Aún no hay evidencias' : 'Sin evidencias todavía',
            style: AppTypography.body
                .copyWith(
                  fontWeight: FontWeight.w800,
                  color: co.textPrimary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            canUpload
                ? 'Sube fotos del avance para que el técnico pueda validar el hito.'
                : 'El constructor aún no ha subido evidencias del avance.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyS
                .copyWith(color: co.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends ConsumerStatefulWidget {
  const _EvidenceCard({required this.evidence});

  final MilestoneEvidence evidence;

  @override
  ConsumerState<_EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends ConsumerState<_EvidenceCard> {
  String? _signedUrl;
  bool _loadingUrl = true;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final uploader = ref.read(evidenceUploaderProvider);
      final url = await uploader.createSignedUrl(
        storagePath: widget.evidence.storagePath,
      );
      if (!mounted) return;
      setState(() {
        _signedUrl = url;
        _loadingUrl = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _urlError = e.toString();
        _loadingUrl = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    final ev = widget.evidence;
    return Container(
      decoration: BoxDecoration(
        color: co.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          if (ev.isImage) _imagePreview(),
          // Metadata
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(ev.evidenceType),
                        size: 16, color: context.colors.brandAccent),
                    const SizedBox(width: 4),
                    Text(_typeLabel(ev.evidenceType),
                        style: AppTypography.bodyS.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colors.brandAccent,
                        )),
                    const Spacer(),
                    if (ev.isMine)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.successBg,
                          borderRadius: AppRadius.microAll,
                        ),
                        child: Text('TÚ',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                  ],
                ),
                if (ev.description != null &&
                    ev.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ev.description!,
                      style: AppTypography.body.copyWith(color: co.textPrimary)),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: co.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          ev.uploadedByName ??
                              ev.uploadedByEmail ??
                              'Sin nombre',
                          style: AppTypography.caption.copyWith(
                            color: co.textTertiary,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    // Sprint 6 · Chip "Vía equipo · NombreOrg" cuando el
                    // autor subió la evidencia siendo miembro (no owner).
                    if (ev.isUploadedByTeam)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.colors.borderSubtle,
                          borderRadius: AppRadius.microAll,
                          border: Border.all(
                            color: context.colors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_2_outlined,
                                size: 10, color: co.textPrimary),
                            const SizedBox(width: 3),
                            Text(
                              'Vía ${ev.uploaderViaOrgName!}',
                              style: AppTypography.caption.copyWith(
                                color: co.textPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 12, color: co.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          AppFormatters.timeRelative(ev.serverTimestamp),
                          style: AppTypography.caption.copyWith(
                            color: co.textTertiary,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (ev.hasGps) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        '${ev.gpsLatitude!.toStringAsFixed(5)}, ${ev.gpsLongitude!.toStringAsFixed(5)}'
                        ' (±${ev.gpsAccuracyMeters?.toStringAsFixed(0) ?? "?"} m)',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Hash: ${ev.sha256Hash.substring(0, 16)}…',
                  style: AppTypography.caption.copyWith(
                    color: co.textHint,
                    letterSpacing: 0,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    if (_loadingUrl) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: context.colors.chipBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.md),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_urlError != null || _signedUrl == null) {
      return Container(
        height: 120,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.errorBg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.md),
          ),
        ),
        child: Center(
          child: Text('No se pudo cargar la imagen',
              style: AppTypography.bodyS.copyWith(color: AppColors.error)),
        ),
      );
    }
    final semanticLabel = widget.evidence.description?.trim().isNotEmpty ==
            true
        ? 'Evidencia: ${widget.evidence.description!.trim()}'
        : 'Fotografía de evidencia del hito';
    return Semantics(
      button: true,
      label: '$semanticLabel. Toca para ampliar.',
      child: GestureDetector(
        onTap: _openZoom,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.md),
          ),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              _signedUrl!,
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (ctx, e, _) => Center(
                child: Icon(Icons.broken_image, size: 48, color: context.colors.textHint),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Visor a pantalla completa con zoom (pinch / doble dedo) para poder
  /// inspeccionar la evidencia en detalle antes de validar.
  void _openZoom() {
    if (_signedUrl == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    _signedUrl!,
                    fit: BoxFit.contain,
                    semanticLabel: 'Evidencia ampliada',
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                        ),
                      );
                    },
                    errorBuilder: (c, e, _) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.white),
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'photo':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.mic_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'note':
        return Icons.note_outlined;
      default:
        return Icons.attach_file;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'photo':
        return 'Foto';
      case 'video':
        return 'Vídeo';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Documento';
      case 'note':
        return 'Nota';
      default:
        return type;
    }
  }
}

// =====================================================================
// CTA SUBMIT FOR REVIEW
// =====================================================================

class _SubmitForReviewCta extends ConsumerStatefulWidget {
  const _SubmitForReviewCta({
    required this.milestoneId,
    required this.evidenceCount,
  });

  final String milestoneId;
  final int evidenceCount;

  @override
  ConsumerState<_SubmitForReviewCta> createState() =>
      _SubmitForReviewCtaState();
}

class _SubmitForReviewCtaState
    extends ConsumerState<_SubmitForReviewCta> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Marcar el hito como listo?'),
        content: const Text(
          'Esta acción avisa al técnico (o promotor en obra menor) para que '
          'revise tus evidencias. No podrás añadir más evidencias hasta que '
          'la revisión termine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Marcar como listo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(pactsRepositoryProvider)
          .submitMilestoneForReview(widget.milestoneId);
      ref.invalidate(milestoneDetailProvider(widget.milestoneId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('Hito enviado a revisión',
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = humanizeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.psGradientDeep,
        borderRadius: AppRadius.lgAll,
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
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.psCyan, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('¿Hito completado?',
                    style: AppTypography.h3
                        .copyWith(color: AppColors.white)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Has aportado ${widget.evidenceCount} evidencia${widget.evidenceCount == 1 ? "" : "s"}. '
            'Puedes marcar el hito como listo para que sea revisado.',
            style: AppTypography.bodyS.copyWith(
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: AppTypography.bodyS.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            icon: _submitting
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.textPrimary,
                    ),
                  )
                : const Icon(Icons.send),
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.psNavy,
            ),
            label: Text(_submitting ? 'Enviando…' : 'Marcar como listo'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// CTA: TÉCNICO REVISA (obra mayor, hito en ready_for_review)
// =====================================================================

class _TechReviewCta extends ConsumerStatefulWidget {
  const _TechReviewCta({required this.milestone});

  final MilestoneFull milestone;

  @override
  ConsumerState<_TechReviewCta> createState() => _TechReviewCtaState();
}

class _TechReviewCtaState extends ConsumerState<_TechReviewCta> {
  bool _submitting = false;
  String? _error;

  Future<void> _decide(String decision, String dialogTitle, String hint) async {
    final rationale = await _askRationale(
      title: dialogTitle,
      hint: hint,
      required: decision != 'approve',
    );
    if (rationale == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(pactsRepositoryProvider).techReviewMilestone(
            milestoneId: widget.milestone.id,
            decision: decision,
            rationale: rationale.isEmpty ? null : rationale,
          );
      ref.invalidate(milestoneDetailProvider(widget.milestone.id));
      ref.invalidate(pactDetailProvider(widget.milestone.pactId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('Decisión registrada',
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = humanizeError(e);
      });
    }
  }

  Future<String?> _askRationale({
    required String title,
    required String hint,
    required bool required,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hint,
                helperText: required
                    ? 'Obligatorio. Explica el motivo.'
                    : 'Opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final txt = ctrl.text.trim();
              if (required && txt.isEmpty) return;
              Navigator.of(ctx).pop(txt);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.tecnicoAccent,
        borderRadius: AppRadius.lgAll,
        gradient: const LinearGradient(
          colors: [AppColors.tecnicoAccent, AppColors.tecnicoAccentDark],
        ),
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
                  color: AppColors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.architecture,
                    color: AppColors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Validación técnica',
                    style: AppTypography.h3
                        .copyWith(color: AppColors.white)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Revisa las evidencias del constructor. Si todo cumple con lo pactado, aprueba para que el promotor libere el pago.',
            style: AppTypography.bodyS.copyWith(
              color: AppColors.white.withValues(alpha: 0.9),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: AppTypography.bodyS.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_submitting)
            const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    color: AppColors.white, strokeWidth: 2),
              ),
            )
          else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              onPressed: () => _decide('approve', 'Aprobar hito',
                  'Comentario opcional para el constructor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.success,
              ),
              label: const Text('Aprobar técnicamente'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.help_outline, size: 18),
                    onPressed: () => _decide('request_info',
                        'Pedir más información',
                        'Qué necesitas que aclare o aporte el constructor'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white),
                    ),
                    label: const Text('Pedir info'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _decide('reject', 'Rechazar hito',
                        'Motivo del rechazo (qué no cumple lo pactado)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white),
                    ),
                    label: const Text('Rechazar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// CTA: PROMOTOR DECIDE
// =====================================================================

class _PromotorDecideCta extends ConsumerStatefulWidget {
  const _PromotorDecideCta({required this.milestone});

  final MilestoneFull milestone;

  @override
  ConsumerState<_PromotorDecideCta> createState() =>
      _PromotorDecideCtaState();
}

class _PromotorDecideCtaState extends ConsumerState<_PromotorDecideCta> {
  bool _submitting = false;
  String? _error;

  Future<void> _decide(String decision, String dialogTitle, String hint) async {
    final rationale = await _askRationale(
      title: dialogTitle,
      hint: hint,
      required: decision == 'dispute',
    );
    if (rationale == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(pactsRepositoryProvider).promotorDecideMilestone(
            milestoneId: widget.milestone.id,
            decision: decision,
            rationale: rationale.isEmpty ? null : rationale,
          );
      ref.invalidate(milestoneDetailProvider(widget.milestone.id));
      ref.invalidate(pactDetailProvider(widget.milestone.pactId));
      ref.invalidate(myPactsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              decision == 'approve' ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
          content: Text(
            decision == 'approve'
                ? 'Pago liberado correctamente'
                : 'Objeción registrada',
            style:
                AppTypography.bodyS.copyWith(color: AppColors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = humanizeError(e);
      });
    }
  }

  Future<String?> _askRationale({
    required String title,
    required String hint,
    required bool required,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hint,
                helperText: required ? 'Obligatorio' : 'Opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final txt = ctrl.text.trim();
              if (required && txt.isEmpty) return;
              Navigator.of(ctx).pop(txt);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final isMenor = m.pactType == 'obra_menor';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.psGradientDeep,
        borderRadius: AppRadius.lgAll,
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
                child: const Icon(Icons.account_balance_wallet,
                    color: AppColors.psCyan, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isMenor
                      ? 'Decide sobre el hito'
                      : 'Te toca decidir',
                  style: AppTypography.h3
                      .copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isMenor
                ? 'En obra menor sin técnico, eres tú quien valida el avance del constructor. Si las evidencias prueban el cumplimiento, aprueba y se liberará el pago.'
                : 'El técnico ha aprobado este hito. Si las evidencias prueban el cumplimiento, aprueba y libera el pago al constructor.',
            style: AppTypography.bodyS.copyWith(
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: AppTypography.bodyS.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_submitting)
            const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    color: AppColors.white, strokeWidth: 2),
              ),
            )
          else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              onPressed: () => _decide(
                'approve',
                'Aprobar y liberar pago',
                'Comentario opcional',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.success,
              ),
              label: Text(
                'Aprobar y liberar ${AppFormatters.moneyShort(m.amountCents)}',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel, size: 18),
              onPressed: () => _decide(
                'dispute',
                'Objetar el hito',
                'Motivo de la objeción (qué no cumple lo pactado)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.white),
              ),
              label: const Text('Objetar / abrir disputa'),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// BANNER: CONSTRUCTOR DEBE RE-TRABAJAR
// =====================================================================

class _ReworkBanner extends StatelessWidget {
  const _ReworkBanner({required this.milestone});

  final MilestoneFull milestone;

  @override
  Widget build(BuildContext context) {
    final rejected = milestone.state == 'rejected_by_tech';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: rejected ? context.colors.errorBg : context.colors.warningBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: rejected ? AppColors.error : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? Icons.cancel_outlined : Icons.help_outline,
            color: rejected ? AppColors.error : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rejected
                      ? 'El técnico ha rechazado el hito'
                      : 'El técnico ha pedido más información',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: rejected ? AppColors.error : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rejected
                      ? 'Revisa las observaciones, corrige lo que haga falta y vuelve a marcar el hito como listo.'
                      : 'Aporta la información o evidencias adicionales que ha solicitado el técnico.',
                  style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
                ),
                // P1-4 · Motivo escrito por quien validó. Solo se muestra
                // si el backend lo devuelve (requiere la migración
                // 20260715000001_milestone_detail_validation_rationale).
                if (milestone.hasValidationRationale) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: AppRadius.xsAll,
                      border: Border.all(
                        color:
                            (rejected ? AppColors.error : AppColors.warning)
                                .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.lastValidationByName != null
                              ? 'Observaciones de ${milestone.lastValidationByName}'
                              : 'Observaciones del técnico',
                          style: AppTypography.caption.copyWith(
                            color: context.colors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '“${milestone.lastValidationRationale!.trim()}”',
                          style: AppTypography.bodyS.copyWith(
                            color: context.colors.textPrimary,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// BANNER: PAGADO
// =====================================================================

class _PaidBanner extends StatelessWidget {
  const _PaidBanner({required this.milestone});

  final MilestoneFull milestone;

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
          const Icon(Icons.verified, color: AppColors.success, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hito pagado',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    )),
                const SizedBox(height: 2),
                Text(
                  'Se liberaron ${AppFormatters.moneyLong(milestone.amountCents)} al constructor.',
                  style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
                ),
                if (milestone.paidAt != null)
                  Text(
                    AppFormatters.dateTimeDetail(milestone.paidAt!),
                    style: AppTypography.caption.copyWith(
                      color: context.colors.textTertiary,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// BANNER: EN DISPUTA — centro de resolución guiada
// =====================================================================
//
// Auditoría 16-jul (F2.1): antes este banner solo decía "se activa en el
// siguiente sprint" — el escenario que justifica el escrow acababa en un
// muro. Ahora es un panel de resolución con:
//   - tranquilización sobre el dinero (queda en custodia),
//   - timeline visual de los 4 pasos de resolución,
//   - cita del motivo si el técnico/promotor dejó rationale,
//   - plazo legal explícito (AppConstants.disputeResolutionDays),
//   - acciones concretas: subir evidencia adicional, ver evidencias, y
//     escalar al equipo por email (mailto).
// El sistema E2E de disputas (RPCs, mediación in-app, votación) queda
// como scope de otra sesión; esto rescata al usuario del callejón HOY.

class _DisputeBanner extends ConsumerWidget {
  const _DisputeBanner({required this.milestone});

  final MilestoneFull milestone;

  static Future<void> _resolveDispute(
    BuildContext context,
    WidgetRef ref,
    MilestoneFull milestone,
    DisputeResolution resolution,
  ) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(resolution.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resolution == DisputeResolution.favorConstructor
                  ? 'Se procede al pago del hito.'
                  : 'El hito vuelve a ejecución para los ajustes necesarios.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota de resolución (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DisputeActions.resolve(
        milestoneId: milestone.id,
        resolution: resolution,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      ref.invalidate(milestoneDetailProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disputa resuelta')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _emailSupport() async {
    final subject = Uri.encodeComponent(
      'Disputa hito ${milestone.displayId} · ${milestone.pactDisplayId}',
    );
    final body = Uri.encodeComponent(
      'Hola equipo de PactStream,\n\n'
      'Necesito ayuda para resolver una disputa abierta en el hito '
      '${milestone.displayId} del pacto ${milestone.pactDisplayId} '
      '("${milestone.pactTitle}").\n\n'
      'Describo brevemente la situación:\n\n',
    );
    final uri = Uri.parse('mailto:${AppConstants.supportEmail}?subject=$subject&body=$body');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rationale = milestone.hasValidationRationale
        ? milestone.lastValidationRationale
        : null;
    final validator = milestone.lastValidationByName;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.warning, width: 1),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel, color: AppColors.warning, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Este hito está en disputa',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'El dinero queda protegido en custodia. Nada se libera '
                        'hasta que ambas partes acuerden o el equipo intervenga.',
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Motivo (cita del rationale si existe) ────────────────
          if (rationale != null && rationale.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      validator != null && validator.isNotEmpty
                          ? 'Motivo de $validator'
                          : 'Motivo',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"$rationale"',
                      style: AppTypography.bodyS.copyWith(
                        color: context.colors.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Timeline de resolución ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cómo se resuelve',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _DisputeTimeline(),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 14, color: context.colors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Plazo estimado de resolución: hasta '
                        '${AppConstants.disputeResolutionDays} días.',
                        style: AppTypography.caption
                            .copyWith(color: context.colors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Acciones ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (milestone.myRole == 'constructor')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    onPressed: () => context.push(
                      '/pacts/${milestone.pactId}/milestones/${milestone.id}/evidences/upload',
                    ),
                    label: const Text('Aportar prueba adicional'),
                  ),
                if (milestone.myRole == 'constructor')
                  const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  icon: const Icon(Icons.support_agent, size: 18),
                  onPressed: _emailSupport,
                  label: const Text('Contactar con el equipo de PactStream'),
                ),
                if (milestone.myRole == 'tecnico' ||
                    milestone.myRole == 'promotor') ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Resolución',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => _resolveDispute(
                      context, ref, milestone,
                      DisputeResolution.favorConstructor,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Rechazar disputa · pagar hito'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(
                    onPressed: () => _resolveDispute(
                      context, ref, milestone,
                      DisputeResolution.favorPromotor,
                    ),
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: const Text('Aprobar disputa · volver a ejecución'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline horizontal con los 4 pasos de resolución. El "actual" se
/// destaca; los futuros quedan grises. Sin RPC nueva: es informativo
/// (el sistema E2E de disputas viene en otra fase).
class _DisputeTimeline extends StatelessWidget {
  const _DisputeTimeline();

  @override
  Widget build(BuildContext context) {
    // De momento todos los hitos in_dispute están en "Diálogo entre partes"
    // (paso 1): el promotor abrió la objeción. Cuando exista la RPC de
    // escalación pasará a 2, y con la resolución del equipo a 3.
    const currentStep = 1;
    final steps = [
      ('Objeción presentada', Icons.gavel),
      ('Diálogo entre partes', Icons.forum_outlined),
      ('Mediación PactStream', Icons.support_agent),
      ('Resolución', Icons.check_circle_outline),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final prevStep = (i - 1) ~/ 2;
          final isDone = prevStep < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                height: 2,
                color: isDone
                    ? AppColors.warning
                    : context.colors.divider,
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final (label, icon) = steps[idx];
        final isDone = idx < currentStep;
        final isCurrent = idx == currentStep;
        final color = isDone
            ? AppColors.warning
            : isCurrent
                ? AppColors.warning
                : context.colors.textTertiary;
        return SizedBox(
          width: 68,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDone || isCurrent
                      ? AppColors.warning.withOpacity(0.15)
                      : context.colors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isDone || isCurrent
                      ? context.colors.textPrimary
                      : context.colors.textTertiary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
