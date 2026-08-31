import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../services/auth_controller.dart';
import 'lesson_controller.dart';
import 'models/lesson.dart';

/// Submits the just-finished lesson (POST /learn/complete) and shows the
/// score + updated XP/streak. Reached only from LessonScreen, which passes
/// its live controller via `extra` — the outcomes already live there.
class LessonResultScreen extends StatefulWidget {
  final LessonController controller;
  final AuthController auth;
  const LessonResultScreen({
    super.key,
    required this.controller,
    required this.auth,
  });

  @override
  State<LessonResultScreen> createState() => _LessonResultScreenState();
}

class _LessonResultScreenState extends State<LessonResultScreen> {
  LearnHeader? _header;
  String? _error;

  @override
  void initState() {
    super.initState();
    _submit();
  }

  Future<void> _submit() async {
    final token = widget.auth.accessToken;
    if (token == null) {
      setState(() => _error = 'Please log in again.');
      return;
    }
    try {
      final header = await widget.controller.submit(token);
      if (!mounted) return;
      setState(() => _header = header);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save your progress, but great work!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final total = widget.controller.lesson?.items.length ?? 0;
    final correct = widget.controller.correctCount;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 72, color: AppColors.gold),
              const SizedBox(height: 20),
              Text(
                'Lesson Complete',
                style: pjs(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                total == 0 ? 'Nicely done.' : '$correct of $total correct',
                style: pjs(fontSize: 15, color: palette.textMuted),
              ),
              const SizedBox(height: 24),
              if (_header != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stat('Level', '${_header!.arabicLevel}', palette),
                    const SizedBox(width: 24),
                    _stat('XP', '${_header!.xp}', palette),
                    const SizedBox(width: 24),
                    _stat('Streak', '${_header!.streakCount}', palette),
                  ],
                )
              else if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: pjs(fontSize: 13, color: palette.textMuted),
                )
              else
                const CircularProgressIndicator(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.learn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealStart,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'Back to Roadmap',
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

  Widget _stat(String label, String value, AppPalette palette) => Column(
    children: [
      Text(
        value,
        style: pjs(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.tealStart,
        ),
      ),
      Text(label, style: pjs(fontSize: 11, color: palette.textMuted)),
    ],
  );
}
