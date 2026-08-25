import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../shared/widgets/app_bottom_nav.dart';

class SettingsScreen extends StatelessWidget {
  final AuthController auth;
  const SettingsScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Settings',
                    style: pjs(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.email ?? '',
                    style: pjs(fontSize: 14, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => auth.signOut(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.tajweedError),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        'Sign Out',
                        style: pjs(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tajweedError,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppBottomNav(
              currentIndex: 3,
              onTap: (i) {
                if (i == 0) context.go(AppRoutes.home);
                if (i == 1) context.go(AppRoutes.surahs);
                if (i == 2) context.go(AppRoutes.stats);
              },
            ),
          ],
        ),
      ),
    );
  }
}
