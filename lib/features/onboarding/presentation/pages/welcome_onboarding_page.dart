import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/pactstream_logo.dart';
import '../../data/onboarding_prefs.dart';

/// Full-screen guided onboarding shown on first login.
///
/// Four-step PageView with:
/// - Custom abstract illustrations (CustomPaint)
/// - Brand gradient backgrounds
/// - Dot indicators
/// - Skip / Next / Get started controls
class WelcomeOnboardingPage extends ConsumerStatefulWidget {
  const WelcomeOnboardingPage({super.key});

  @override
  ConsumerState<WelcomeOnboardingPage> createState() =>
      _WelcomeOnboardingPageState();
}

class _WelcomeOnboardingPageState
    extends ConsumerState<WelcomeOnboardingPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final AnimationController _bgCtrl;
  int _currentPage = 0;

  static const _steps = 4;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  void _next() {
    AppHaptics.light();
    if (_currentPage < _steps - 1) {
      _pageCtrl.nextPage(
        duration: AppMotion.normal,
        curve: AppMotion.emphasize,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    AppHaptics.success();
    ref.read(onboardingCompleteProvider.notifier).complete();
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                      math.cos(_bgCtrl.value * 2 * math.pi),
                      math.sin(_bgCtrl.value * 2 * math.pi),
                    ),
                    end: Alignment(
                      -math.cos(_bgCtrl.value * 2 * math.pi),
                      -math.sin(_bgCtrl.value * 2 * math.pi),
                    ),
                    colors: isDark
                        ? const [
                            AppColors.darkBg,
                            Color(0xFF0D1240),
                            Color(0xFF0A1055),
                          ]
                        : const [
                            Color(0xFFF0F2FF),
                            Color(0xFFE4E9FF),
                            Color(0xFFD6DEFF),
                          ],
                  ),
                ),
              );
            },
          ),

          // Pages
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      right: AppSpacing.lg,
                    ),
                    child: AnimatedOpacity(
                      opacity: _currentPage < _steps - 1 ? 1.0 : 0.0,
                      duration: AppMotion.fast,
                      child: TextButton(
                        onPressed:
                            _currentPage < _steps - 1 ? _finish : null,
                        child: Text(
                          'Saltar',
                          style: AppTypography.bodyS.copyWith(
                            color: isDark
                                ? AppColors.ink400
                                : AppColors.ink500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) =>
                        setState(() => _currentPage = i),
                    children: [
                      _OnboardingStep(
                        illustration: _WelcomeIllustration(isDark: isDark),
                        title: 'Bienvenido a PactStream',
                        subtitle:
                            'La plataforma que genera confianza en cada proyecto de construcción.',
                        isDark: isDark,
                      ),
                      _OnboardingStep(
                        illustration: _WorksIllustration(isDark: isDark),
                        title: 'Gestiona tus obras',
                        subtitle:
                            'Crea contratos, invita participantes y controla los hitos de cada proyecto.',
                        isDark: isDark,
                      ),
                      _OnboardingStep(
                        illustration: _PaymentsIllustration(isDark: isDark),
                        title: 'Pagos seguros',
                        subtitle:
                            'Custodia en blockchain que protege a todas las partes. Los fondos se liberan al validar el trabajo.',
                        isDark: isDark,
                      ),
                      _OnboardingStep(
                        illustration:
                            _ReputationIllustration(isDark: isDark),
                        title: 'Tu reputación importa',
                        subtitle:
                            'Construye tu Trust Score con cada proyecto exitoso. Tu historial es tu mejor credencial.',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _steps,
                          (i) => _DotIndicator(
                            active: i == _currentPage,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: AnimatedSwitcher(
                          duration: AppMotion.fast,
                          child: _currentPage == _steps - 1
                              ? ElevatedButton(
                                  key: const ValueKey('start'),
                                  onPressed: _finish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.psBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    textStyle:
                                        AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Comenzar'),
                                )
                              : ElevatedButton(
                                  key: const ValueKey('next'),
                                  onPressed: _next,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.psBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    textStyle:
                                        AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Siguiente'),
                                ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────
// STEP LAYOUT
// ─────────────────────────────────────────────────────────────────

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final Widget illustration;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          SizedBox(
            height: 220,
            child: illustration,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.h1.copyWith(
              color: isDark ? AppColors.ink200 : AppColors.ink900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.ink400 : AppColors.ink600,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// DOT INDICATOR
// ─────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.active, required this.isDark});
  final bool active;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active
            ? AppColors.psBlue
            : (isDark ? AppColors.ink600 : AppColors.ink300),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// CUSTOM PAINT ILLUSTRATIONS
// All abstract/geometric — no image assets needed.
// ═════════════════════════════════════════════════════════════════

/// Step 1: Welcome — PactStream logo clean, no background elements.
class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PactStreamLogo(
        height: 64,
        variant: isDark
            ? PactStreamLogoVariant.light
            : PactStreamLogoVariant.dark,
      ),
    );
  }
}

/// Step 2: Works management — stacked cards with checkmarks.
class _WorksIllustration extends StatelessWidget {
  const _WorksIllustration({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Back card
            Positioned(
              top: 20,
              child: _IllustrationCard(
                width: 180,
                height: 120,
                isDark: isDark,
                rotation: -0.04,
                opacity: 0.5,
              ),
            ),
            // Middle card
            Positioned(
              top: 10,
              child: _IllustrationCard(
                width: 190,
                height: 130,
                isDark: isDark,
                rotation: 0.02,
                opacity: 0.7,
              ),
            ),
            // Front card with content
            _IllustrationCard(
              width: 200,
              height: 140,
              isDark: isDark,
              rotation: 0,
              opacity: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.psCyan, AppColors.psBlue],
                            ),
                          ),
                          child: const Icon(
                            Icons.construction_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 90,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.ink500
                                    : AppColors.ink300,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 60,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.ink600
                                    : AppColors.ink200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress bar
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.ink100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.65,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.psBlue, AppColors.success],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Check items
                    ...List.generate(
                      2,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 80 - i * 20.0,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.ink600
                                    : AppColors.ink200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 3: Secure payments — shield with lock.
class _PaymentsIllustration extends StatelessWidget {
  const _PaymentsIllustration({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(200, 200),
        painter: _ShieldPainter(isDark: isDark),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.psBlue,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.psBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Hexagonal shield shape
    final path = Path();
    const sides = 6;
    const radius = 85.0;
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * math.pi / sides) - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fill = Paint()
      ..color = isDark
          ? AppColors.psBlue.withValues(alpha: 0.1)
          : AppColors.psBlue.withValues(alpha: 0.06);
    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..color = isDark
          ? AppColors.psBlue.withValues(alpha: 0.3)
          : AppColors.psBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, stroke);

    // Inner hexagon
    final innerPath = Path();
    const innerRadius = 58.0;
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * math.pi / sides) - math.pi / 2;
      final x = center.dx + innerRadius * math.cos(angle);
      final y = center.dy + innerRadius * math.sin(angle);
      if (i == 0) {
        innerPath.moveTo(x, y);
      } else {
        innerPath.lineTo(x, y);
      }
    }
    innerPath.close();

    final innerStroke = Paint()
      ..color = isDark
          ? AppColors.psCyan.withValues(alpha: 0.2)
          : AppColors.psCyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(innerPath, innerStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Step 4: Trust Score — gauge arc.
class _ReputationIllustration extends StatelessWidget {
  const _ReputationIllustration({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(
          painter: _TrustGaugePainter(isDark: isDark),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  '85',
                  style: AppTypography.h1.copyWith(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.ink900,
                  ),
                ),
                Text(
                  'TRUST SCORE',
                  style: AppTypography.bodyS.copyWith(
                    color: isDark ? AppColors.ink400 : AppColors.ink500,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustGaugePainter extends CustomPainter {
  _TrustGaugePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    const radius = 85.0;
    const strokeWidth = 10.0;
    const startAngle = math.pi * 0.75; // 135 degrees
    const sweepAngle = math.pi * 1.5; // 270 degrees

    // Background arc
    final bgPaint = Paint()
      ..color = isDark ? AppColors.darkBorder : AppColors.ink200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Gradient arc (85% filled)
    const fillFraction = 0.85;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle * fillFraction,
      colors: const [
        AppColors.gaugeRed,
        AppColors.gaugeAmber,
        AppColors.gaugeGreen,
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * fillFraction,
      false,
      fillPaint,
    );

    // Endpoint dot
    final endAngle = startAngle + sweepAngle * fillFraction;
    final dotCenter = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    final dotPaint = Paint()..color = AppColors.success;
    canvas.drawCircle(dotCenter, 6, dotPaint);
    final dotOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(dotCenter, 6, dotOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────
// SHARED ILLUSTRATION CARD
// ─────────────────────────────────────────────────────────────────

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({
    required this.width,
    required this.height,
    required this.isDark,
    this.rotation = 0,
    this.opacity = 1.0,
    this.child,
  });

  final double width;
  final double height;
  final bool isDark;
  final double rotation;
  final double opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.ink200,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.psNavy)
                    .withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
