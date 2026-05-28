import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class PsErrorView extends StatelessWidget {
  const PsErrorView({
    super.key,
    this.title = 'Algo salió mal',
    this.subtitle,
    this.onRetry,
    this.compact = false,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final bool compact;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final co = context.colors;
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: co.errorBg,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.error, size: 24),
            const SizedBox(width: AppSpacing.sm),
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
                            .copyWith(color: co.textSecondary)),
                ],
              ),
            ),
            if (onRetry != null)
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: AppColors.error),
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
            Icon(icon, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: AppTypography.h3.copyWith(color: co.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyS.copyWith(color: co.textTertiary)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
