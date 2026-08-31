import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/progress_ring_painter.dart';

class OnboardingPage3 extends StatefulWidget {
  const OnboardingPage3({super.key});

  @override
  State<OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends State<OnboardingPage3>
    with TickerProviderStateMixin {
  static const double _targetProgress = 0.76;

  late final AnimationController _entryController;
  late final AnimationController _ringController;

  late final Animation<double> _ringContainerAnim;
  late final Animation<double> _ringProgressAnim;
  late final Animation<double> _textAnim;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _ringContainerAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    );

    _textAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_textAnim);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringProgressAnim = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _ringController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Expanded(child: Center(child: _buildProgressRing(palette))),
        _buildTexts(palette),
      ],
    );
  }

  Widget _buildProgressRing(AppPalette palette) {
    return FadeTransition(
      opacity: _ringContainerAnim,
      child: ScaleTransition(
        scale: _ringContainerAnim,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            color: palette.cardBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.tealStart.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _ringProgressAnim,
            builder: (context, child) {
              final double currentProgress =
                  _ringProgressAnim.value * _targetProgress;
              return CustomPaint(
                painter: ProgressRingPainter(progress: currentProgress),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(currentProgress * 100).round()}%',
                        style: pjs(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealStart,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MASTERY',
                        style: pjs(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTexts(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _textAnim,
        child: SlideTransition(
          position: _textSlide,
          child: Column(
            children: [
              Text(
                'Improve Every Day',
                textAlign: TextAlign.center,
                style: pjs(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your recitation journey one ayah at a time. Watch your fluency bloom like sacred geometry.',
                textAlign: TextAlign.center,
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

