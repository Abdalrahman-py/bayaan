import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import '../../shared/widgets/ornamental_divider.dart';
import '../../shared/widgets/animated_arabic_text.dart';
import 'models/ayah.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../services/quran_translation.dart';

class AyahSelectionScreen extends StatefulWidget {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final List<Ayah> ayahs;

  const AyahSelectionScreen({
    super.key,
    this.surahNumber = 1,
    this.surahNameEnglish = 'Al-Fatihah',
    this.surahNameArabic = 'سُورَةُ الفَاتِحَة',
    this.ayahs = const [],
  });

  @override
  State<AyahSelectionScreen> createState() => _AyahSelectionScreenState();
}

class _AyahSelectionScreenState extends State<AyahSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<double> _bannerFade;
  late final Animation<double> _bannerScale;
  late List<Ayah> _ayahs;

  @override
  void initState() {
    super.initState();
    _ayahs = widget.ayahs;
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _bannerFade = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
    );
    _bannerScale = _bannerFade;
    _headerController.forward();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final results = await Future.wait([
      QuranTranslation.forSurah(widget.surahNumber),
      QuranTranslation.transliterationForSurah(widget.surahNumber),
    ]);
    if (!mounted) return;
    final translations = results[0];
    final transliterations = results[1];
    if (translations == null && transliterations == null) return;
    setState(() {
      _ayahs = _ayahs
          .map(
            (a) => Ayah(
              number: a.number,
              arabicText: a.arabicText,
              translation: translations?[a.number],
              transliteration: transliterations?[a.number],
            ),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
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
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildBackHeader(context),
                  _buildTitleBanner(),
                  ...List.generate(_ayahs.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: StaggeredFadeSlide(
                        index: index,
                        child: _AyahRow(
                          ayah: _ayahs[index],
                          onTap: () => context.push(
                            AppRoutes.recordingPath(
                              widget.surahNumber,
                              _ayahs[index].number,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            AppBottomNav(
              currentIndex: 1,
              onTap: (i) {
                if (i == 0) context.go(AppRoutes.home);
                if (i == 1) context.go(AppRoutes.surahs);
                if (i == 2) context.go(AppRoutes.stats);
                if (i == 3) context.go(AppRoutes.settings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackHeader(BuildContext context) {
    return FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.surahs),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF5F1E6)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.surahNameEnglish,
                  style: pjs(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Choose an ayah to practice',
                  style: pjs(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBanner() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FadeTransition(
        opacity: _bannerFade,
        child: ScaleTransition(
          scale: _bannerScale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.gold),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const OrnamentalDivider(width: double.infinity, opacity: 0.3),
                const SizedBox(height: 12),
                Text(
                  widget.surahNameArabic,
                  textDirection: TextDirection.rtl,
                  style: arabic(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tealStart,
                  ),
                ),
                const SizedBox(height: 12),
                const OrnamentalDivider(width: double.infinity, opacity: 0.3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AyahRow extends StatelessWidget {
  final Ayah ayah;
  final VoidCallback onTap;

  const _AyahRow({required this.ayah, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF5F1E6)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lightBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Text(
                      '${ayah.number}',
                      style: pjs(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tealStart,
                      ),
                    ),
                  ),
                  Text(
                    'TAP TO PRACTICE ▸',
                    style: pjs(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedArabicText(
                  text: ayah.arabicText,
                  duration: const Duration(milliseconds: 600),
                  textAlign: TextAlign.right,
                  style: arabic(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
              if (ayah.transliteration != null) ...[
                const SizedBox(height: 8),
                Text(
                  ayah.transliteration!,
                  style: pjs(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.tealStart,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              if (ayah.translation != null) ...[
                const SizedBox(height: 8),
                Text(
                  ayah.translation!,
                  style: pjs(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
