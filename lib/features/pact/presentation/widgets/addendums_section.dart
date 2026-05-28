import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
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
            Icon(Icons.assignment_outlined,
                size: 18, color: context.colors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text('Anexos del pacto',
                style:
                    AppTypography.h3.copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
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
          style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (detail.addendums.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.scaffold,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: context.colors.textTertiary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'No hay anexos en este pacto.',
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textTertiary),
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
      accent = context.colors.textTertiary;
      bg = context.colors.scaffold;
      icon = Icons.cancel_outlined;
      stateLabel = 'Cancelado';
    } else {
      accent = context.colors.brandAccent;
      bg = context.colors.brandAccentBg;
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
        borderRadius: AppRadius.smAll,
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
                      .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(stateLabel,
                    style: AppTypography.caption
                        .copyWith(color: accent, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(
                AppFormatters.timeRelative(addendum.createdAt),
                style: AppTypography.caption
                    .copyWith(color: context.colors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(addendum.title,
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          if (addendum.description != null) ...[
            const SizedBox(height: 4),
            Text(addendum.description!,
                style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary)),
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
                    color: context.colors.textSecondary),
              ],
              if (addendum.hasDoc) ...[
                const SizedBox(width: AppSpacing.xs),
                _Badge(
                    icon: Icons.description_outlined,
                    label: 'Doc',
                    color: context.colors.brandAccent),
              ],
            ],
          ),

          if (addendum.justification != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: AppRadius.microAll,
              ),
              child: Text(addendum.justification!,
                  style:
                      AppTypography.caption.copyWith(color: context.colors.textSecondary)),
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
        borderRadius: AppRadius.smAll,
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
    final color = signed ? AppColors.success : context.colors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.mdAll,
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
