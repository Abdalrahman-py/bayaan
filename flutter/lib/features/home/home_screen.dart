import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/router/app_router.dart';
import '../../services/auth_controller.dart';
import '../../services/quran_text.dart';
import '../ayah/models/ayah.dart';

class HomeScreen extends StatefulWidget {
  final AuthController auth;
  const HomeScreen({super.key, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _entryController;

  late final Animation<double> _headerAnim;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardAnim;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _suggestedAnim;
  late final Animation<Offset> _suggestedSlide;

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

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildResumeSection(),
                    _buildSuggestedSection(),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              currentIndex: 0,
              onTap: (index) {
                switch (index) {
                  case 1:
                    context.go(AppRoutes.surahs);
                  case 2:
                    context.go(AppRoutes.stats);
                  case 3:
                    context.go(AppRoutes.settings);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String? get _firstName {
    final email = widget.auth.email;
    if (email == null || email.isEmpty) return null;
    return email.split('@').first;
  }

  String get _avatarInitial =>
      (_firstName?.isNotEmpty ?? false) ? _firstName![0].toUpperCase() : '?';

  Widget _buildHeader() {
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
                      'Assalamu Alaikum${_firstName != null ? ', $_firstName' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: pjs(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
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

  Widget _buildResumeSection() {
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
                  color: AppColors.textDark,
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
                          color: AppColors.tealStart.withOpacity(0.15),
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
                                color: Colors.white.withOpacity(0.15),
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

  Widget _buildSuggestedSection() {
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
                  color: AppColors.textDark,
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
                      ayahs: List.generate(
                        QuranText.verseCount(112),
                        (i) => Ayah(
                          number: i + 1,
                          arabicText:
                              QuranText.verse(112, i + 1)?.uthmani ?? '',
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFF5F1E6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.lightBg,
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
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Meccan · 4 ayahs · Deepen your tawheed',
                                style: pjs(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
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
