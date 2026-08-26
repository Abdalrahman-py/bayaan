import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/models.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../services/quran_text.dart';
import 'models/ayah.dart';
import 'widgets/mushaf_page_view.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';

class AyahSelectionScreen extends StatefulWidget {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final List<Ayah> ayahs;
  final int initialPage;

  const AyahSelectionScreen({
    super.key,
    this.surahNumber = 1,
    this.surahNameEnglish = 'Al-Fatihah',
    this.surahNameArabic = 'سُورَةُ الفَاتِحَة',
    this.ayahs = const [],
    this.initialPage = 1,
  });

  @override
  State<AyahSelectionScreen> createState() => _AyahSelectionScreenState();
}

class _AyahSelectionScreenState extends State<AyahSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  Ayah? _selectedAyah;
  late int _currentPageNumber;

  @override
  void initState() {
    super.initState();
    _currentPageNumber = widget.initialPage > 0
        ? widget.initialPage
        : (QuranText.pageFor(widget.surahNumber, 1) ?? 1);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  MushafPage? get _currentPageInfo {
    final pages = QuranText.mushafPages();
    for (final p in pages) {
      if (p.pageNumber == _currentPageNumber) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final startPage = widget.initialPage > 0
        ? widget.initialPage
        : (QuranText.pageFor(widget.surahNumber, 1) ?? 1);

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildBackHeader(context),
            Expanded(
              child: MushafPageView(
                ayahs: widget.ayahs.isNotEmpty ? widget.ayahs : null,
                initialPage: startPage,
                selectedNumber: _selectedAyah?.number,
                onPageChanged: (page) => setState(() {
                  _currentPageNumber = page;
                  _selectedAyah = null;
                }),
                onAyahTap: (ayah) => setState(() => _selectedAyah = ayah),
              ),
            ),
            if (_selectedAyah != null) _buildPracticeBar(context),
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
    final selected = _selectedAyah;
    if (selected == null) return const SizedBox.shrink();
    final int sura = selected.sura > 0 ? selected.sura : widget.surahNumber;
    final int aya = selected.number;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.recordingPath(sura, aya)),
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: Text(
            'Practice Ayah $aya',
            style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.tealStart,
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
    final pageInfo = _currentPageInfo;
    final surahEn = pageInfo?.surahNameEn ?? widget.surahNameEnglish;
    final surahAr = pageInfo?.surahNameAr ?? widget.surahNameArabic;

    return FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surahEn,
                    style: pjs(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Page $_currentPageNumber · Choose an ayah to practice',
                    style: pjs(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              surahAr,
              textDirection: TextDirection.rtl,
              style: arabic(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

