import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../animation/score_math.dart';
import 'progress_ring_painter.dart';

/// Score ring that counts up to [score] on entry (polish ported from the
/// bayyan client). Pure presentation: takes the final score, animates itself.
class AnimatedScoreRing extends StatefulWidget {
  final int score;
  final double size;
  final double strokeWidth;

  const AnimatedScoreRing({
    super.key,
    required this.score,
    this.size = 120,
    this.strokeWidth = 10,
  });

  @override
  State<AnimatedScoreRing> createState() => _AnimatedScoreRingState();
}

class _AnimatedScoreRingState extends State<AnimatedScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final current = interpolateScore(
            _anim.value,
            from: 0,
            to: widget.score,
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: ProgressRingPainter(
                    progress: current / 100,
                    strokeWidth: widget.strokeWidth,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$current',
                    style: pjs(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tealStart,
                    ),
                  ),
                  Text(
                    '/100',
                    style: pjs(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
