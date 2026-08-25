import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/app_bottom_nav.dart';

/// ponytail: no progress/history backend yet (bayaan-progress /
/// bayaan-session-history in Figma aren't built) — placeholder so the nav
/// tab doesn't dead-end.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Stats are coming soon',
                        style: pjs(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your recitation history and progress will show up here.',
                        textAlign: TextAlign.center,
                        style: pjs(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AppBottomNav(
              currentIndex: 2,
              onTap: (i) {
                if (i == 0) context.go(AppRoutes.home);
                if (i == 1) context.go(AppRoutes.surahs);
                if (i == 3) context.go(AppRoutes.settings);
              },
            ),
          ],
        ),
      ),
    );
  }
}
