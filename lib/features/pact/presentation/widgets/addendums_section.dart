import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_detail.dart';

/// Sección de anexos formales al pacto (solo se renderiza en v2 con datos).
///
/// Muestra todos los anexos en orden ordinal, con estado, importe extra,
/// días extra y quién ha firmado ya. Si el caller es parte y aún no firmó
/// un anexo pendiente, ofrece el CTA "Firmar".
class AddendumsSection extends StatelessWidget {
  const AddendumsSection({
    super.key,
    required this.detail,
    this.onProposeAddendum,
    this.onSignAddendum,
  });

  final PactDetail detail;

  /// Promotor / constructor / técnico que quiere proponer un nuevo anexo.
  final VoidCallback? onProposeAddendum;

  /// Firma un anexo concreto (lo identifica por id).
  final void Function(PactAddendum)? onSignAddendum;

  @override
  Widget build(BuildContext context) {
    if (!detail.pact.isV2) return const SizedBox.shrink();
    if (detail.addendums.isEmpty && onProposeAddendum == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_outlined,
                size: 18, color: AppColors.ink600),
            const SizedBox(width: AppSpacing.xs),
            Text('Anexos del pacto',
                style:
                    AppTypography.h3.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            if (onProposeAddendum != null)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                onPressed: onProposeAddendum,
                label: const Text('Proponer'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Los anexos modifican el pacto cuando hay imprevistos o cambios. '
          'Para activarse necesitan la firma de todas las partes.',
          style: AppTypography.caption.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (detail.addendums.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.ink50,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(color: AppColors.ink200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.ink500),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'No hay anexos en este pacto.',
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink500),
                  ),
                ),
              ],
            ),
          )
        else
          for (final a in detail.addendums)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AddendumCard(
                addendum: a,
                detail: detail,
                onSign: onSignAddendum,
              ),
            ),
      ],
    );
  }
}

class _AddendumCard extends StatelessWidget {
  const _AddendumCard({
    required this.addendum,
    required this.detail,
    this.onSign,
  });

  final PactAddendum addendum;
  final PactDetail detail;
  final void Function(PactAddendum)? onSign;

  @override
  Widget build(BuildContext context) {
    final isActive = addendum.isActive;
    final isCancelled = addendum.state == 'cancelled';
    final isPending = addendum.isPending;

    Color accent;
    Color bg;
    IconData icon;
    String stateLabel;
    if (isActive) {
      accent = AppColors.success;
      bg = AppColors.successBg;
      icon = Icons.check_circle_outline;
      stateLabel = 'Activo';
    } else if (isCancelled) {
      accent = AppColors.ink500;
      bg = AppColors.ink50;
      icon = Icons.cancel_outlined;
      stateLabel = 'Cancelado';
    } else {
      accent = AppColors.psBlue;
      bg = AppColors.infoBg;
      icon = Icons.pending_outlined;
      stateLabel = addendum.state == 'proposed' ? 'Propuesto' : 'En firma';
    }

    // Mi firma
    final myRole = detail.me?.role;
    final myHasSigned =
        myRole != null && addendum.signedByRole(myRole);
    final canISign = isPending && myRole != null && !myHasSigned;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Text('Anexo #${addendum.ordinal}',
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(stateLabel,
                    style: AppTypography.caption
                        .copyWith(color: accent, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(
                AppFormatters.timeRelative(addendum.createdAt),
                style: AppTypography.caption
                    .copyWith(color: AppColors.ink500),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(addendum.title,
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w700)),
          if (addendum.description != null) ...[
            const SizedBox(height: 4),
            Text(addendum.description!,
                style: AppTypography.bodyS.copyWith(color: AppColors.ink600)),
          ],

          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Badge(
                  icon: Icons.euro,
                  label: '${addendum.extraAmountCents >= 0 ? '+' : ''}'
                      '${AppFormatters.moneyShort(addendum.extraAmountCents)}',
                  color: addendum.extraAmountCents >= 0
                      ? AppColors.success
                      : AppColors.error),
              if (addendum.extraDays != 0) ...[
                const SizedBox(width: AppSpacing.xs),
                _Badge(
                    icon: Icons.event,
                    label:
                        '${addendum.extraDays > 0 ? '+' : ''}${addendum.extraDays} días',
                    color: AppColors.ink600),
              ],
              if (addendum.hasDoc) ...[
                const SizedBox(width: AppSpacing.xs),
                _Badge(
                    icon: Icons.description_outlined,
                    label: 'Doc',
                    color: AppColors.psBlue),
              ],
            ],
          ),

          if (addendum.justification != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Text(addendum.justification!,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.ink600)),
            ),
          ],

          if (isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            _SignaturesRow(addendum: addendum, detail: detail),
            if (canISign && onSign != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 18),
                onPressed: () => onSign!(addendum),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.psBlue,
                  foregroundColor: AppColors.white,
                ),
                label: const Text('Firmar este anexo'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SignaturesRow extends StatelessWidget {
  const _SignaturesRow({required this.addendum, required this.detail});

  final PactAddendum addendum;
  final PactDetail detail;

  @override
  Widget build(BuildContext context) {
    final roles = detail.pact.pactType == 'obra_mayor'
        ? const ['promotor', 'constructor', 'tecnico']
        : const ['promotor', 'constructor'];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final r in roles)
          _SignaturePill(
            role: r,
            signed: addendum.signedByRole(r),
          ),
      ],
    );
  }
}

class _SignaturePill extends StatelessWidget {
  const _SignaturePill({required this.role, required this.signed});

  final String role;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final label = role == 'promotor'
        ? 'Promotor'
        : (role == 'constructor' ? 'Constructor' : 'Técnico');
    final color = signed ? AppColors.success : AppColors.ink500;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(signed ? Icons.check_circle : Icons.pending,
              size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
