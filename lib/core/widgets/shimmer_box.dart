import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Caja con efecto shimmer animado para estados de carga.
///
/// Uso:
/// ```dart
/// ShimmerBox(height: 120, radius: 12)
/// ShimmerBox(height: 16, width: 100, radius: 4) // text placeholder
/// ```
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [
                c.shimmerBase,
                c.shimmerHighlight,
                c.shimmerBase,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton genérico para una lista de cards.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _CardSkeleton(),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: c.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 16, width: 180, radius: 4),
          SizedBox(height: 8),
          ShimmerBox(height: 12, width: 120, radius: 4),
          SizedBox(height: 12),
          ShimmerBox(height: 14, radius: 4),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(height: 12, width: 100, radius: 4),
              ShimmerBox(height: 24, width: 70, radius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton para una página de detalle.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // Header
          Row(
            children: [
              ShimmerBox(height: 24, width: 80, radius: 12),
              SizedBox(width: 8),
              ShimmerBox(height: 24, width: 100, radius: 12),
            ],
          ),
          SizedBox(height: 12),
          ShimmerBox(height: 28, width: 240, radius: 4),
          SizedBox(height: 8),
          ShimmerBox(height: 14, width: 160, radius: 4),
          SizedBox(height: 24),
          // Trust Score card
          ShimmerBox(height: 72, radius: 12),
          SizedBox(height: 16),
          // Financial summary
          ShimmerBox(height: 120, radius: 12),
          SizedBox(height: 16),
          // Section
          ShimmerBox(height: 18, width: 140, radius: 4),
          SizedBox(height: 8),
          ShimmerBox(height: 80, radius: 12),
          SizedBox(height: 8),
          ShimmerBox(height: 80, radius: 12),
        ],
      ),
    );
  }
}

/// Skeleton específico para la página de perfil.
///
/// Muestra un bloque con gradiente que simula el header de perfil
/// y luego secciones de contenido con shimmer.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Simular el header con gradiente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              gradient: AppColors.psGradientDeep,
            ),
            child: Column(
              children: [
                // Avatar placeholder
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 12),
                // Name placeholder
                Container(
                  height: 20,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.microAll,
                  ),
                ),
                const SizedBox(height: 8),
                // Email placeholder
                Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: AppRadius.microAll,
                  ),
                ),
                const SizedBox(height: 12),
                // Role badge placeholder
                Container(
                  height: 24,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
              ],
            ),
          ),
          // Content placeholders
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                ShimmerBox(height: 14, width: 180, radius: 4),
                SizedBox(height: 8),
                ShimmerBox(height: 64, radius: 12),
                SizedBox(height: 24),
                ShimmerBox(height: 14, width: 200, radius: 4),
                SizedBox(height: 8),
                ShimmerBox(height: 200, radius: 12),
                SizedBox(height: 24),
                ShimmerBox(height: 14, width: 160, radius: 4),
                SizedBox(height: 8),
                ShimmerBox(height: 100, radius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
