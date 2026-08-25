import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/recitation_controller.dart';
import '../../shared/widgets/dashed_circle_painter.dart';

/// Linear interpolation of an animated score counter.
/// Exposed for tests; [t] is the animation value in [0, 1].
int interpolateScore(double t, {required int from, required int to}) =>
    (from + (to - from) * t).round();

/// bayaan-celebration from Figma — shown when ResultState.allCorrect.
/// Polish ported from the bayyan client: count-up score, dashed gold ring,
/// ornamental stars, staggered entry animations. The Continue button keeps
/// driving controller.nextAyah.
class CelebrationScreen extends StatefulWidget {
  final RecitationController controller;
  final int sura;
  final int aya;

  const CelebrationScreen({
    super.key,
    required this.controller,
    required this.sura,
    required this.aya,
  });

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _scoreController;

  late final Animation<double> _plateAnim;
  late final Animation<double> _scoreCountAnim;
  late final Animation<double> _labelAnim;
  late final Animation<double> _messageAnim;
  late final Animation<Offset> _messageSlide;
  late final Animation<double> _starsAnim;
  late final Animation<double> _buttonAnim;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _plateAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    );
    _labelAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
    );
    _messageAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOut),
    );
    _messageSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_messageAnim);
    _starsAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.70, 0.90, curve: Curves.easeOutBack),
    );
    _buttonAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(_buttonAnim);

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scoreCountAnim = CurvedAnimation(
      parent: _scoreController,
      curve: Curves.easeOutCubic,
    );

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _scoreController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightBg, Color(0xFFF5F1E6)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(),
                _buildScorePlate(),
                const SizedBox(height: 32),
                _buildMessage(),
                const SizedBox(height: 28),
                _buildOrnamentStars(),
                const Spacer(),
                _buildContinueButton(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScorePlate() {
    return FadeTransition(
      opacity: _plateAnim,
      child: ScaleTransition(
        scale: _plateAnim,
        child: Container(
          width: 220,
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: DashedCirclePainter(
                    color: AppColors.gold.withOpacity(0.5),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _scoreCountAnim,
                    builder: (context, child) {
                      final current = interpolateScore(
                        _scoreCountAnim.value,
                        from: 0,
                        to: 100,
                      );
                      return Text(
                        '$current',
                        style: pjs(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealStart,
                        ),
                      );
                    },
                  ),
                  FadeTransition(
                    opacity: _labelAnim,
                    child: Text(
                      'MASHAALLAH',
                      style: pjs(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage() {
    return FadeTransition(
      opacity: _messageAnim,
      child: SlideTransition(
        position: _messageSlide,
        child: Column(
          children: [
            Text(
              'Perfect recitation.',
              textAlign: TextAlign.center,
              style: pjs(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every word and every tajweed rule, exactly right. Keep this pace.',
              textAlign: TextAlign.center,
              style: pjs(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrnamentStars() {
    return FadeTransition(
      opacity: _starsAnim,
      child: ScaleTransition(
        scale: _starsAnim,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStar(16),
            const SizedBox(width: 16),
            _buildStar(24),
            const SizedBox(width: 16),
            _buildStar(16),
          ],
        ),
      ),
    );
  }

  Widget _buildStar(double size) {
    return Transform.rotate(
      angle: 45 * 3.14159 / 180,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: Transform.rotate(
          angle: 45 * 3.14159 / 180,
          child: Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return FadeTransition(
      opacity: _buttonAnim,
      child: SlideTransition(
        position: _buttonSlide,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              widget.controller.nextAyah(widget.sura, widget.aya, (s, a) {
                context.pushReplacement(AppRoutes.recordingPath(s, a));
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealStart,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Text(
              'Continue Journey',
              style: pjs(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
