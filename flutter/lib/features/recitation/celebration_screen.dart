import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/recitation_controller.dart';

/// bayaan-celebration from Figma — shown when ResultState.allCorrect.
class CelebrationScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Container(
                  width: 190,
                  height: 190,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '100',
                        style: pjs(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealStart,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MASHAALLAH',
                        style: pjs(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Transform.rotate(
                      angle: 45 * 3.14159 / 180,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    controller.nextAyah(sura, aya, (s, a) {
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
            ],
          ),
        ),
      ),
    );
  }
}
