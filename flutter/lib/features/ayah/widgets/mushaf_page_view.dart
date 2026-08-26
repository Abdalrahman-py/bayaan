import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/models.dart';
import '../../../services/quran_text.dart';
import '../../../shared/widgets/ornamental_divider.dart';
import '../models/ayah.dart';

/// Groups ayahs by their real mushaf page number (Madani, 604-page
/// convention), preserving ayah order and sorting pages ascending.
List<List<Ayah>> groupAyahsByMushafPage(List<Ayah> ayahs) {
  final Map<int, List<Ayah>> grouped = {};
  for (final ayah in ayahs) {
    grouped.putIfAbsent(ayah.pageNumber, () => []).add(ayah);
  }
  final sortedPageNumbers = grouped.keys.toList()..sort();
  return sortedPageNumbers.map((p) => grouped[p]!).toList();
}

/// Mushaf page container model holding either raw `Ayah` items or `MushafPage`.
class _MushafPageItem {
  final int pageNumber;
  final int sura;
  final String surahNameEn;
  final String surahNameAr;
  final List<Ayah> ayahs;

  const _MushafPageItem({
    required this.pageNumber,
    required this.sura,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.ayahs,
  });

  factory _MushafPageItem.fromAyahs(List<Ayah> ayahs) {
    final first = ayahs.first;
    final ch = QuranText.chapters.isNotEmpty && first.sura <= QuranText.chapters.length
        ? QuranText.chapters[first.sura - 1]
        : null;
    return _MushafPageItem(
      pageNumber: first.pageNumber,
      sura: first.sura,
      surahNameEn: ch?.nameEn ?? 'Surah ${first.sura}',
      surahNameAr: ch?.nameAr ?? '',
      ayahs: ayahs,
    );
  }

  factory _MushafPageItem.fromMushafPage(MushafPage p) {
    return _MushafPageItem(
      pageNumber: p.pageNumber,
      sura: p.sura,
      surahNameEn: p.surahNameEn,
      surahNameAr: p.surahNameAr,
      ayahs: p.ayahs.map(Ayah.fromVerse).toList(),
    );
  }
}

/// Tarteel / Madani mushaf-style paged ayah browser: ayahs are grouped onto
/// their real 604 mushaf pages and rendered with adaptive font fitting so all
/// text on each page fits in full view without clipping.
class MushafPageView extends StatefulWidget {
  final List<Ayah>? ayahs;
  final List<MushafPage>? pages;
  final int initialPage;

  /// Ayah number currently selected; null when nothing is selected.
  final int? selectedNumber;
  final ValueChanged<Ayah> onAyahTap;
  final ValueChanged<int>? onPageChanged;

  const MushafPageView({
    super.key,
    this.ayahs,
    this.pages,
    this.initialPage = 1,
    this.selectedNumber,
    required this.onAyahTap,
    this.onPageChanged,
  });

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  late List<_MushafPageItem> _pageItems;
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _initPages();
  }

  void _initPages() {
    if (widget.pages != null && widget.pages!.isNotEmpty) {
      _pageItems = widget.pages!.map(_MushafPageItem.fromMushafPage).toList();
    } else if (widget.ayahs != null && widget.ayahs!.isNotEmpty) {
      final grouped = groupAyahsByMushafPage(widget.ayahs!);
      _pageItems = grouped.map(_MushafPageItem.fromAyahs).toList();
    } else {
      final global = QuranText.mushafPages();
      _pageItems = global.map(_MushafPageItem.fromMushafPage).toList();
    }

    _currentIndex = _pageItems.indexWhere(
      (p) => p.pageNumber >= widget.initialPage,
    );
    if (_currentIndex < 0) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant MushafPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ayahs != oldWidget.ayahs || widget.pages != oldWidget.pages) {
      final oldPageNum = _pageItems.isNotEmpty && _currentIndex < _pageItems.length
          ? _pageItems[_currentIndex].pageNumber
          : widget.initialPage;
      _initPages();
      final newIndex = _pageItems.indexWhere((p) => p.pageNumber == oldPageNum);
      if (newIndex >= 0 && newIndex != _currentIndex) {
        _currentIndex = newIndex;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageItems.isEmpty) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _pageItems.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          if (widget.onPageChanged != null && index < _pageItems.length) {
            widget.onPageChanged!(_pageItems[index].pageNumber);
          }
        },
        itemBuilder: (context, index) {
          final item = _pageItems[index];
          return Directionality(
            textDirection: TextDirection.ltr,
            child: _MushafPage(
              ayahs: item.ayahs,
              mushafPageNumber: item.pageNumber,
              sura: item.sura,
              surahNameEn: item.surahNameEn,
              surahNameAr: item.surahNameAr,
              selectedNumber: widget.selectedNumber,
              onAyahTap: widget.onAyahTap,
            ),
          );
        },
      ),
    );
  }
}

class _MushafPage extends StatefulWidget {
  final List<Ayah> ayahs;
  final int mushafPageNumber;
  final int? sura;
  final String? surahNameEn;
  final String? surahNameAr;
  final int? selectedNumber;
  final ValueChanged<Ayah> onAyahTap;

  const _MushafPage({
    required this.ayahs,
    required this.mushafPageNumber,
    this.sura,
    this.surahNameEn,
    this.surahNameAr,
    this.selectedNumber,
    required this.onAyahTap,
  });

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _rebuildRecognizers();
  }

  @override
  void didUpdateWidget(covariant _MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ayahs != oldWidget.ayahs ||
        widget.onAyahTap != oldWidget.onAyahTap) {
      _rebuildRecognizers();
    }
  }

  void _rebuildRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    for (final ayah in widget.ayahs) {
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onAyahTap(ayah);
      _recognizers.add(recognizer);
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  /// Whether this page opens a new surah (starts with ayah 1 and has surah metadata).
  bool get _opensSurah =>
      widget.ayahs.any((a) => a.number == 1) &&
      widget.surahNameAr != null &&
      widget.surahNameAr!.isNotEmpty;

  Ayah? get _openingAyah =>
      _opensSurah ? widget.ayahs.firstWhere((a) => a.number == 1) : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7), // warm mushaf-paper white
          border: Border.all(color: AppColors.gold, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealStart.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Thin inner gold frame — "gilded panel" traditional aesthetic.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            ..._buildCornerOrnaments(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Expanded(
                        child: _buildAdaptiveTextContent(constraints),
                      ),
                      const SizedBox(height: 8),
                      _buildPageFooter(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveTextContent(BoxConstraints constraints) {
    Widget? headerWidget;
    double reservedHeaderHeight = 0;

    if (_opensSurah) {
      final opening = _openingAyah!;
      final suraNum = opening.sura;
      final ch = QuranText.chapters.isNotEmpty && suraNum <= QuranText.chapters.length
          ? QuranText.chapters[suraNum - 1]
          : null;
      final nameAr = ch?.nameAr ?? widget.surahNameAr ?? '';
      final nameEn = ch?.nameEn ?? widget.surahNameEn ?? 'Surah $suraNum';

      headerWidget = _buildSurahHeaderBanner(suraNum, nameAr, nameEn);
      reservedHeaderHeight = (suraNum == 1 || suraNum == 9) ? 65 : 100;
    }

    final double availableWidth = (constraints.maxWidth - 16).clamp(50, 1000);
    final double availableHeight = (constraints.maxHeight - reservedHeaderHeight - 8).clamp(80, 2000);

    final double bestFontSize = _computeBestFontSize(
      availableWidth: availableWidth,
      availableHeight: availableHeight,
    );

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          ?headerWidget,
          RichText(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            text: TextSpan(
              style: arabic(
                fontSize: bestFontSize,
                fontWeight: FontWeight.w600,
                height: 1.85,
                color: AppColors.tealStart,
              ),
              children: _buildAyahSpans(bestFontSize),
            ),
          ),
        ],
      ),
    );
  }

  double _computeBestFontSize({
    required double availableWidth,
    required double availableHeight,
  }) {
    if (availableWidth <= 0 || availableHeight <= 0) return 18.0;

    final String plainText = widget.ayahs
        .map((a) => '${a.arabicText} (${a.number})')
        .join(' ');

    for (double size = 20.0; size >= 13.0; size -= 1.0) {
      final span = TextSpan(
        text: plainText,
        style: arabic(
          fontSize: size,
          fontWeight: FontWeight.w600,
          height: 1.85,
          color: AppColors.tealStart,
        ),
      );
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: availableWidth);

      if (painter.size.height <= availableHeight) {
        return size;
      }
    }
    return 13.0;
  }

  Widget _buildSurahHeaderBanner(int suraNum, String nameAr, String nameEn) {
    final bool showBasmalah = suraNum != 1 && suraNum != 9;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.35),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nameEn,
                  style: pjs(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealStart,
                  ),
                ),
                Text(
                  'سُورَةُ $nameAr',
                  textDirection: TextDirection.rtl,
                  style: arabic(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          if (showBasmalah) ...[
            const SizedBox(height: 4),
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: arabic(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.tealStart,
              ),
            ),
            const SizedBox(height: 2),
            const OrnamentalDivider(width: 120, opacity: 0.3),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCornerOrnaments() {
    Widget corner(Alignment alignment) {
      return Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
  }

  Widget _buildPageFooter() {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Text(
        '${widget.mushafPageNumber}',
        style: pjs(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.tealStart,
        ),
      ),
    );
  }

  List<InlineSpan> _buildAyahSpans([double fontSize = 18]) {
    final spans = <InlineSpan>[];
    final double medallionSize = (fontSize * 1.1).clamp(18.0, 24.0);
    final double medallionFont = (fontSize * 0.55).clamp(9.0, 12.0);

    for (var i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final bool selected = ayah.number == widget.selectedNumber;
      final recognizer = i < _recognizers.length ? _recognizers[i] : null;

      spans.add(
        TextSpan(
          text: '${ayah.arabicText} ',
          recognizer: recognizer,
          style: selected
              ? TextStyle(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.22),
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.gold,
                  decorationThickness: 1.5,
                )
              : null,
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: recognizer != null ? () => widget.onAyahTap(ayah) : null,
              child: Container(
                width: medallionSize,
                height: medallionSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold : AppColors.lightBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '${ayah.number}',
                  style: pjs(
                    fontSize: medallionFont,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : AppColors.tealStart,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return spans;
  }
}

