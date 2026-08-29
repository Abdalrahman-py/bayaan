import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/app_state.dart';

/// The branding lives in the native launch screen (see `flutter_native_splash`
/// in pubspec.yaml), which is already on screen before Flutter starts. This
/// screen only holds that same flat colour while boot finishes, so the handoff
/// is invisible — no second, animated logo playing over the first one.
///
/// It still exists as a route because boot has to live somewhere: it kicks off
/// [AppState.bootstrap] and owns the retry UI for a failed asset load.
class SplashScreen extends StatefulWidget {
  final AppState state;

  const SplashScreen({super.key, required this.state});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // GoRouter's redirect (refreshListenable: the state) moves us off splash
    // once this resolves — no explicit navigation needed here. Re-entering
    // splash after a failed boot leaves the retry button to drive it instead.
    if (widget.state.booting) widget.state.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealStart, // matches the native splash colour
      body: SafeArea(
        child: Center(
          child: ListenableBuilder(
            listenable: widget.state,
            builder: (context, _) =>
                widget.state.assetError ? _buildRetry() : const SizedBox(),
          ),
        ),
      ),
    );
  }

  Widget _buildRetry() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Couldn't load the Quran text",
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.state.retryBootstrap,
            child: Text(
              'Try again',
              style: pjs(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
