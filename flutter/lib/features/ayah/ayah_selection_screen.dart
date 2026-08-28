import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/models.dart';
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
                selected: _selectedAyah,
                onPageChanged: (page) => setState(() {
                  _currentPageNumber = page;
                  _selectedAyah = null;
                }),
                onAyahTap: (ayah) => setState(() => _selectedAyah = ayah),
                onAyahLongPress: _showAyahMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Anchored to the pressed ayah rather than docked under the page — a bar
  /// below the mushaf would shrink it and re-fit the text at a smaller size.
  Future<void> _showAyahMenu(Ayah ayah, Offset at) async {
    setState(() => _selectedAyah = ayah);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        at.dx,
        at.dy,
        overlay.size.width - at.dx,
        overlay.size.height - at.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'practice',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_rounded, size: 18, color: AppColors.tealStart),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Practice this ayah',
                  style: pjs(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (choice != 'practice' || !mounted) return;
    final sura = ayah.sura > 0 ? ayah.sura : widget.surahNumber;
    if (!mounted) return;
    context.push(AppRoutes.recordingPath(sura, ayah.number));
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
                child: const Icon(
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

