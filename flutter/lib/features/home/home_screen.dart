import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../services/accounts_manager.dart';
import '../../services/auth_controller.dart';
import '../../services/quran_text.dart';

class HomeScreen extends StatefulWidget {
  final AuthController auth;
  const HomeScreen({super.key, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const double _completionTarget = 0.71;

  late final AnimationController _entryController;

  late final Animation<double> _headerAnim;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardAnim;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _suggestedAnim;
  late final Animation<Offset> _suggestedSlide;
  late final Animation<double> _progressFillAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _headerAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(_headerAnim);

    _cardAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.20, 0.60, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_cardAnim);

    _suggestedAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    _suggestedSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_suggestedAnim);

    _progressFillAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 0.95, curve: Curves.easeOutCubic),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  String get _displayName {
    final active = AccountsManager.instance.activeAccount;
    if (active.name.isNotEmpty && active.name != 'Learner') return active.name;
    final email = widget.auth.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Learner';
  }

  String get _avatarInitial =>
      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'B';

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(palette),
                    _buildResumeSection(palette),
                    _buildQuizSection(palette),
                    _buildSuggestedSection(palette),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return FadeTransition(
      opacity: _headerAnim,
      child: SlideTransition(
        position: _headerSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السَّلامُ عَلَيْكُم',
                      textDirection: TextDirection.rtl,
                      style: arabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assalamu Alaikum, $_displayName',
                      overflow: TextOverflow.ellipsis,
                      style: pjs(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealStart,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: Text(
                  _avatarInitial,
                  style: pjs(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeSection(AppPalette palette) {
    return FadeTransition(
      opacity: _cardAnim,
      child: SlideTransition(
        position: _cardSlide,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue Learning',
                style: pjs(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(AppRoutes.learn),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.splashGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tealStart.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ARABIC TRACK',
                                style: pjs(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              'الحروف',
                              textDirection: TextDirection.rtl,
                              style: arabic(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Learn Arabic',
                          style: pjs(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Letters, sounds, makharij — start from zero',
                          style: pjs(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.cream,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildProgressBar(palette),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push(AppRoutes.learn),
                            icon: const Icon(
                              Icons.play_arrow,
                              size: 16,
                              color: AppColors.tealEnd,
                            ),
                            label: Text(
                              'Start Learning',
                              style: pjs(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tealEnd,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildProgressBar(AppPalette palette) {
    return AnimatedBuilder(
      animation: _progressFillAnim,
      builder: (context, child) {
        final double current = _progressFillAnim.value * _completionTarget;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: current,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Module Progress',
                  style: pjs(
                    fontSize: 12,
                    color: AppColors.cream.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${(current * 100).round()}%',
                  style: pjs(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuizSection(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.quiz),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.cardBg,
              border: Border.all(color: palette.borderColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: const Icon(
                    Icons.quiz_rounded,
                    size: 20,
                    color: AppColors.tealStart,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quizzes & Tests',
                        style: pjs(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tajweed tests · Quran trivia · Islamic trivia',
                        style: pjs(fontSize: 12.5, color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedSection(AppPalette palette) {
    return FadeTransition(
      opacity: _suggestedAnim,
      child: SlideTransition(
        position: _suggestedSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested for Recitation',
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(
                    AppRoutes.ayahSelection,
                    extra: AyahSelectionArgs(
                      surahNumber: 112,
                      surahNameEnglish: 'Al-Ikhlas',
                      surahNameArabic: 'سُورَةُ الإخلاص',
                      initialPage: QuranText.pageFor(112, 1) ?? 604,
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.cardBg,
                      border: Border.all(color: palette.borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.background,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold),
                          ),
                          child: Text(
                            '112',
                            style: pjs(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.tealStart,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Al-Ikhlas (Sincerity)',
                                style: pjs(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Meccan · 4 ayahs · Deepen your tawheed',
                                style: pjs(
                                  fontSize: 13,
                                  color: palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
