import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/animated_arabic_text.dart';

class OnboardingPage2 extends StatefulWidget {
  const OnboardingPage2({super.key});

  @override
  State<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends State<OnboardingPage2>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;

  late final Animation<double> _cardAnim;
  late final Animation<double> _cardRotate;
  late final Animation<double> _starsTopAnim;
  late final Animation<double> _ayahAnim;
  late final Animation<double> _starsBottomAnim;
  late final Animation<double> _textAnim;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _cardAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
    );
    _cardRotate = Tween<double>(begin: -0.04, end: 0.0).animate(_cardAnim);

    _starsTopAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.30, 0.50, curve: Curves.easeOut),
    );
    _ayahAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.38, 0.68, curve: Curves.easeOut),
    );
    _starsBottomAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
    );

    _textAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 0.78, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_textAnim);

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: _buildCalligraphyCard(palette)),
          ),
        ),
        _buildTexts(palette),
      ],
    );
  }

  Widget _buildCalligraphyCard(AppPalette palette) {
    return FadeTransition(
      opacity: _cardAnim,
      child: AnimatedBuilder(
        animation: _cardRotate,
        builder: (context, child) {
          return Transform.rotate(angle: _cardRotate.value, child: child);
        },
        child: ScaleTransition(
          scale: _cardAnim,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            decoration: BoxDecoration(
              color: palette.cardBg,
              border: Border.all(color: AppColors.gold, width: 1),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.tealStart.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _starsTopAnim,
                  child: _buildStarsRow(descending: true),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _ayahAnim,
                  child: AnimatedArabicText(
                    text: 'بِسْمِ اللَّهِ الرَّحِيمِ',
                    duration: const Duration(milliseconds: 1200),
                    style: arabic(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tealStart,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _starsBottomAnim,
                  child: _buildStarsRow(descending: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStarsRow({required bool descending}) {
    final sizes = descending ? [6.0, 4.0, 2.0] : [2.0, 4.0, 6.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sizes
          .map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: s,
                height: s,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )
          .toList(),
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
                'Understand Every Mistake',
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
                'See exactly where your pronunciation can improve, tracked syllable-by-syllable directly on the script itself.',
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

