import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A single step in a guided tour.
class CoachMarkStep {
  const CoachMarkStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.icon,
    this.alignment = CoachMarkAlignment.bottom,
  });

  /// Title displayed in the tooltip.
  final String title;

  /// Description text.
  final String description;

  /// GlobalKey of the target widget to highlight.
  /// If null, the tooltip appears centered (no spotlight).
  final GlobalKey? targetKey;

  /// Optional icon displayed next to the title.
  final IconData? icon;

  /// Where to place the tooltip relative to the target.
  final CoachMarkAlignment alignment;
}

enum CoachMarkAlignment { top, bottom, center }

/// Full-screen overlay that highlights a target widget and shows a tooltip.
///
/// Usage:
/// ```dart
/// CoachMarkOverlay.show(
///   context: context,
///   steps: [CoachMarkStep(...)],
///   onComplete: () => prefs.markGuidedTourComplete(),
/// );
/// ```
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onDismiss,
  });

  final List<CoachMarkStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onDismiss;

  /// Show the coach mark overlay as a route overlay.
  static void show({
    required BuildContext context,
    required List<CoachMarkStep> steps,
    required VoidCallback onComplete,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => CoachMarkOverlay(
        steps: steps,
        onComplete: () {
          entry.remove();
          onComplete();
        },
        onDismiss: () {
          entry.remove();
          onComplete(); // Also mark as complete on dismiss
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _next() async {
    if (_currentStep >= widget.steps.length - 1) {
      await _animController.reverse();
      widget.onComplete();
      return;
    }

    await _animController.reverse();
    if (!mounted) return;
    setState(() => _currentStep++);
    _animController.forward();
  }

  void _skip() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  CoachMarkStep get _step => widget.steps[_currentStep];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find target rect if available
    Rect? targetRect;
    if (_step.targetKey?.currentContext != null) {
      final box =
          _step.targetKey!.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final pos = box.localToGlobal(Offset.zero);
        targetRect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
      }
    }

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Dark overlay with spotlight cutout
            Positioned.fill(
              child: GestureDetector(
                onTap: _next,
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    targetRect: targetRect,
                    overlayColor: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),

            // Pulsing ring around target
            if (targetRect != null)
              Positioned(
                left: targetRect.left - 6,
                top: targetRect.top - 6,
                child: _PulsingRing(
                  width: targetRect.width + 12,
                  height: targetRect.height + 12,
                ),
              ),

            // Tooltip card
            _buildTooltip(context, size, targetRect, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(
      BuildContext context, Size screenSize, Rect? targetRect, bool isDark) {
    final tooltipWidth = screenSize.width < 500
        ? screenSize.width - AppSpacing.xl * 2
        : 340.0;

    // Calculate position
    double left;
    double top;

    if (targetRect == null || _step.alignment == CoachMarkAlignment.center) {
      // Center on screen
      left = (screenSize.width - tooltipWidth) / 2;
      top = screenSize.height * 0.35;
    } else if (_step.alignment == CoachMarkAlignment.bottom) {
      // Below target
      left = (targetRect.left + targetRect.width / 2 - tooltipWidth / 2)
          .clamp(AppSpacing.md, screenSize.width - tooltipWidth - AppSpacing.md);
      top = targetRect.bottom + 16;
      // If it would go below screen, place above
      if (top + 180 > screenSize.height) {
        top = targetRect.top - 180;
      }
    } else {
      // Above target
      left = (targetRect.left + targetRect.width / 2 - tooltipWidth / 2)
          .clamp(AppSpacing.md, screenSize.width - tooltipWidth - AppSpacing.md);
      top = targetRect.top - 180;
      if (top < AppSpacing.lg) {
        top = targetRect.bottom + 16;
      }
    }

    return Positioned(
      left: left,
      top: top,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.topCenter,
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark ? AppColors.ink800 : AppColors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: AppColors.psBlue.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.psBlue.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step counter
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.psBlue.withValues(alpha: 0.1),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(
                      '${_currentStep + 1} / ${widget.steps.length}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.psBlue,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _skip,
                    child: Text(
                      'Saltar',
                      style: AppTypography.bodyS.copyWith(
                        color: isDark ? AppColors.ink400 : AppColors.ink500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Icon + Title
              Row(
                children: [
                  if (_step.icon != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.psBlue, AppColors.psCyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(_step.icon, color: AppColors.white, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      _step.title,
                      style: AppTypography.h3.copyWith(
                        color: isDark ? AppColors.white : AppColors.psNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                _step.description,
                style: AppTypography.bodyS.copyWith(
                  color: isDark ? AppColors.ink300 : AppColors.ink600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.psBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  child: Text(
                    _currentStep >= widget.steps.length - 1
                        ? '¡Empezar!'
                        : 'Siguiente',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),

              // Dot indicators
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.steps.length, (i) {
                  final isActive = i == _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: isActive ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.psBlue
                          : (isDark ? AppColors.ink600 : AppColors.ink300),
                      borderRadius: AppRadius.pillAll,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a dark overlay with a rounded-rect cutout for the target.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({this.targetRect, required this.overlayColor});

  final Rect? targetRect;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (targetRect == null) {
      canvas.drawRect(fullRect, paint);
      return;
    }

    // Expand target a bit for padding
    final padded = targetRect!.inflate(8);
    final rrect =
        RRect.fromRectAndRadius(padded, const Radius.circular(12));

    // Draw overlay with cutout
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect;
}

/// Animated pulsing ring around the highlighted target.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          width: widget.width + value * 4,
          height: widget.height + value * 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.psCyan.withValues(alpha: 0.4 + value * 0.3),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
