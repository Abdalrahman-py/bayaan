import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../shared/widgets/animated_score_ring.dart';

/// End-of-quiz summary: animated score ring, best streak, play again / done.
class QuizResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final int bestStreak;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.bestStreak,
    required this.onPlayAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final percent = (score / total * 100).round();
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScoreRing(score: percent),
              const SizedBox(height: 20),
              Text(
                '$score of $total correct',
                style: pjs(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Best streak $bestStreak',
                style: pjs(fontSize: 14, color: palette.textMuted),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealStart,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'Play Again',
                    style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: onDone,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealStart,
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
