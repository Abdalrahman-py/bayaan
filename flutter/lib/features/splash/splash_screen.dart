import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/ornamental_divider.dart';
import '../../core/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _outer1Anim;
  late final Animation<double> _outer2Anim;
  late final Animation<double> _rotatedAnim;
  late final Animation<double> _uprightAnim;
  late final Animation<double> _textAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _outer1Anim = _fadeScale(0.00, 0.40);
    _outer2Anim = _fadeScale(0.15, 0.55);
    _rotatedAnim = _fadeScale(0.32, 0.70);
    _uprightAnim = _fadeScale(0.48, 0.85);
    _textAnim = _fadeScale(0.60, 1.00);

    _controller.forward();
    // GoRouter's redirect (refreshListenable: appState) moves us off splash
    // once this resolves — no explicit navigation needed here.
    appState.bootstrap();
  }

  Animation<double> _fadeScale(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 40),
              _buildLogoSection(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        _buildOrnamentLogo(),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _textAnim,
          child: ScaleTransition(
            scale: _textAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    'بَيان',
                    textDirection: TextDirection.rtl,
                    style: arabic(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'BAYAAN',
                    style: pjs(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-POWERED QURAN RECITATION LEARNER',
                    textAlign: TextAlign.center,
                    style: pjs(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.cream.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrnamentLogo() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildOuterSquare(_outer1Anim, 22.5),
          _buildOuterSquare(_outer2Anim, 67.5),
          FadeTransition(
            opacity: _rotatedAnim,
            child: ScaleTransition(
              scale: _rotatedAnim,
              child: Transform.rotate(
                angle: 45 * 3.14159 / 180,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.tealEnd,
                    border: Border.all(color: AppColors.gold, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: _uprightAnim,
            child: ScaleTransition(
              scale: _uprightAnim,
              child: Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealEnd,
                  border: Border.all(color: AppColors.gold, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'ب',
                  textDirection: TextDirection.rtl,
                  style: arabic(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOuterSquare(Animation<double> anim, double degrees) {
    return FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: anim,
        child: Transform.rotate(
          angle: degrees * 3.14159 / 180,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          const OrnamentalDivider(width: 100, opacity: 0.3),
          const SizedBox(height: 8),
          Text(
            'Instant Precision · Reverential Practice',
            style: pjs(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.cream.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
