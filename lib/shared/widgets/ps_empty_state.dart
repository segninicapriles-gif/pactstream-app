import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class PsEmptyState extends StatelessWidget {
  const PsEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.ctaLabel,
    this.onCta,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: co.scaffold,
          borderRadius: AppRadius.lgAll,
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: co.textHint),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700, color: co.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTypography.bodyS
                            .copyWith(color: co.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: co.chipBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: co.textHint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: AppTypography.h3.copyWith(color: co.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyS.copyWith(color: co.textTertiary)),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
