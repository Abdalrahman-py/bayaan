import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_palette.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({super.key});

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _ringRotateController;

  late final Animation<double> _ringAnim;
  late final Animation<double> _wordAnim;
  late final Animation<double> _textAnim;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _ringAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
    );
    _wordAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.25, 0.60, curve: Curves.easeOut),
    );
    _textAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.40, 0.75, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_textAnim);

    _ringRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ringRotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_buildHeroCircle(palette)],
          ),
        ),
        _buildTexts(palette),
      ],
    );
  }

  Widget _buildHeroCircle(AppPalette palette) {
    return FadeTransition(
      opacity: _ringAnim,
      child: ScaleTransition(
        scale: _ringAnim,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            color: palette.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealStart.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ringRotateController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _ringRotateController.value * 6.28319,
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _wordAnim,
                child: ScaleTransition(
                  scale: _wordAnim,
                  child: Text(
                    'ٱقْرَأْ',
                    textDirection: TextDirection.rtl,
                    style: arabic(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tealStart,
                    ),
                  ),
                ),
              ),
            ],
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
                'Learn Quran with Confidence',
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
                'Practice anytime with instant, private AI feedback. Your voice is verified against noble recitations.',
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

