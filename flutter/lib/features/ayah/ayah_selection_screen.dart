import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/ornamental_divider.dart';
import 'models/ayah.dart';
import 'widgets/mushaf_page_view.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';

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
  int? _selectedNumber; // mushaf is for reading; tap only selects

  @override
  void initState() {
    super.initState();
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
            _buildBackHeader(context),
            _buildTitleBanner(),
            const SizedBox(height: 4),
            Expanded(
              child: MushafPageView(
                ayahs: widget.ayahs,
                selectedNumber: _selectedNumber,
                onAyahTap: (ayah) =>
                    setState(() => _selectedNumber = ayah.number),
              ),
            ),
            _buildPracticeBar(context),
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

  Widget _buildPracticeBar(BuildContext context) {
    final selected = _selectedNumber;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: selected == null
              ? null
              : () => context.push(
                    AppRoutes.recordingPath(widget.surahNumber, selected),
                  ),
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: Text(
            selected == null
                ? 'Tap an ayah to select it'
                : 'Practice Ayah $selected',
            style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.tealStart,
            disabledBackgroundColor: const Color(0xFFE0DCD3),
            disabledForegroundColor: AppColors.textMuted,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
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
