import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/models.dart';
import '../../../services/quran_text.dart';
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

/// Greedy line breaker. The mushaf look comes from laying each line out with
/// `spaceBetween`, which needs the words grouped per line up front — Flutter's
/// `TextAlign.justify` cannot do it because it never stretches a last line.
List<List<T>> wrapTokens<T>(
  List<T> tokens, {
  required double maxWidth,
  required double spaceWidth,
  required double Function(T) widthOf,
}) {
  final lines = <List<T>>[];
  var current = <T>[];
  var used = 0.0;

  for (final token in tokens) {
    final w = widthOf(token);
    final needed = current.isEmpty ? w : used + spaceWidth + w;
    if (current.isNotEmpty && needed > maxWidth) {
      lines.add(current);
      current = [token];
      used = w;
    } else {
      current.add(token);
      used = needed;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// One piece of a mushaf page: either a surah's opening ornament or a run of
/// consecutive ayahs from a single surah. A page can hold several of each —
/// page 604 runs Al-Ikhlas, Al-Falaq and An-Nas one after the other.
sealed class MushafBlock {
  const MushafBlock();
}

class SurahOpening extends MushafBlock {
  final int sura;

  /// Al-Fatihah carries the basmalah as its own first ayah, and At-Tawbah has
  /// none at all, so neither gets the standalone basmalah line.
  bool get showBasmalah => sura != 1 && sura != 9;

  const SurahOpening(this.sura);
}

class AyahRun extends MushafBlock {
  final int sura;
  final List<Ayah> ayahs;

  const AyahRun(this.sura, this.ayahs);
}

/// Splits a page's ayahs into surah openings and ayah runs, in reading order.
List<MushafBlock> splitIntoSurahBlocks(List<Ayah> pageAyahs) {
  final blocks = <MushafBlock>[];
  var run = <Ayah>[];

  void flush() {
    if (run.isEmpty) return;
    blocks.add(AyahRun(run.first.sura, run));
    run = <Ayah>[];
  }

  for (final ayah in pageAyahs) {
    if (run.isNotEmpty && ayah.sura != run.first.sura) flush();
    if (ayah.number == 1) {
      flush();
      blocks.add(SurahOpening(ayah.sura));
    }
    run.add(ayah);
  }
  flush();
  return blocks;
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

  /// Ayah currently selected; null when nothing is selected. Carries the whole
  /// ayah rather than its number, because a number alone is ambiguous on a page
  /// that runs several surahs — page 604 holds three different ayah 1s.
  final Ayah? selected;
  final ValueChanged<Ayah> onAyahTap;

  /// Long press on an ayah, with the global position of the press so callers
  /// can anchor a menu to the ayah instead of moving the page around it.
  final void Function(Ayah ayah, Offset globalPosition)? onAyahLongPress;
  final ValueChanged<int>? onPageChanged;

  const MushafPageView({
    super.key,
    this.ayahs,
    this.pages,
    this.initialPage = 1,
    this.selected,
    required this.onAyahTap,
    this.onAyahLongPress,
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
              selected: widget.selected,
              onAyahTap: widget.onAyahTap,
              onAyahLongPress: widget.onAyahLongPress,
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
  final Ayah? selected;
  final ValueChanged<Ayah> onAyahTap;
  final void Function(Ayah ayah, Offset globalPosition)? onAyahLongPress;

  const _MushafPage({
    required this.ayahs,
    required this.mushafPageNumber,
    this.sura,
    this.surahNameEn,
    this.surahNameAr,
    this.selected,
    required this.onAyahTap,
    this.onAyahLongPress,
  });

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

/// One laid-out item on a line: a word of Quranic text, or the ayah-end
/// medallion that closes a verse.
sealed class _Tok {
  const _Tok();
}

class _WordTok extends _Tok {
  final String text;
  final Ayah ayah;

  /// The closing medallion travels with the ayah's last word, so a line break
  /// can never strand the verse number on a line of its own.
  final bool endsAyah;

  const _WordTok(this.text, this.ayah, {this.endsAyah = false});
}

/// Arabic-Indic digits, as printed in the mushaf.
String _arabicDigits(int n) =>
    n.toString().split('').map((d) => String.fromCharCode(0x0660 + int.parse(d))).join();

class _MushafPageState extends State<_MushafPage> {
  /// Widths are measured once at this size and scaled, rather than re-measured
  /// for every candidate font size — glyph advances scale linearly, and a page
  /// holds ~150 words across ~15 candidate sizes.
  static const _baseSize = 20.0;
  static const _lineHeightFactor = 1.9;

  late List<MushafBlock> _blocks;
  final Map<String, double> _baseWidths = {};

  @override
  void initState() {
    super.initState();
    _blocks = splitIntoSurahBlocks(widget.ayahs);
  }

  @override
  void didUpdateWidget(covariant _MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ayahs != oldWidget.ayahs) {
      _blocks = splitIntoSurahBlocks(widget.ayahs);
      _baseWidths.clear();
    }
  }

  TextStyle _textStyle(double size) => arabic(
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.0,
    color: AppColors.tealStart,
  );

  double _baseWidthOf(String word) => _baseWidths.putIfAbsent(word, () {
    final painter = TextPainter(
      text: TextSpan(text: word, style: _textStyle(_baseSize)),
      textDirection: TextDirection.rtl,
    )..layout();
    return painter.width;
  });

  double _tokenWidth(_Tok tok, double size) => switch (tok) {
    _WordTok(:final text, :final endsAyah) =>
      _baseWidthOf(text) * size / _baseSize +
          (endsAyah ? size * 1.25 + size * 0.2 : 0),
  };

  List<_Tok> _tokensFor(AyahRun run) {
    final toks = <_Tok>[];
    for (final ayah in run.ayahs) {
      final words = ayah.arabicText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      for (var i = 0; i < words.length; i++) {
        toks.add(_WordTok(words[i], ayah, endsAyah: i == words.length - 1));
      }
    }
    return toks;
  }

  /// Height a surah opening occupies at [size], banner plus optional basmalah.
  double _openingHeight(SurahOpening opening, double size) =>
      size * 2.4 + (opening.showBasmalah ? size * 2.0 : 0);

  /// Largest size at which every block fits the page without scrolling.
  double _fitFontSize(double maxWidth, double maxHeight) {
    for (var size = 26.0; size >= 11.0; size -= 0.5) {
      var total = 0.0;
      for (final block in _blocks) {
        switch (block) {
          case SurahOpening():
            total += _openingHeight(block, size);
          case AyahRun():
            final lines = wrapTokens<_Tok>(
              _tokensFor(block),
              maxWidth: maxWidth,
              spaceWidth: size * 0.28,
              widthOf: (t) => _tokenWidth(t, size),
            );
            total += lines.length * size * _lineHeightFactor;
        }
        if (total > maxHeight) break;
      }
      if (total <= maxHeight) return size;
    }
    return 11.0;
  }

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
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildPageBody(constraints),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPageFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageBody(BoxConstraints constraints) {
    if (_blocks.isEmpty) return const SizedBox.shrink();
    final width = constraints.maxWidth;
    final size = _fitFontSize(width, constraints.maxHeight);

    final children = <Widget>[];
    for (final block in _blocks) {
      switch (block) {
        case SurahOpening():
          children.add(_buildSurahOpening(block, size));
        case AyahRun():
          children.addAll(_buildRunLines(block, size, width));
      }
    }

    // Mushaf pages sit at the top of the panel; a short page leaves the rest
    // of the sheet blank rather than stretching its lines apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _buildRunLines(AyahRun run, double size, double width) {
    final lines = wrapTokens<_Tok>(
      _tokensFor(run),
      maxWidth: width,
      spaceWidth: size * 0.28,
      widthOf: (t) => _tokenWidth(t, size),
    );

    return List.generate(lines.length, (i) {
      final isLast = i == lines.length - 1;
      return SizedBox(
        height: size * _lineHeightFactor,
        child: Row(
          textDirection: TextDirection.rtl,
          // Every line but a surah's last is stretched edge to edge, which is
          // what gives the page its mushaf block shape.
          mainAxisAlignment: isLast
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            for (final tok in lines[i]) _buildToken(tok, size, isLast),
          ],
        ),
      );
    });
  }

  Widget _buildToken(_Tok tok, double size, bool spaced) {
    // A centred last line has no stretching to separate its words, so it
    // carries its own inter-word gap.
    final pad = spaced
        ? EdgeInsets.symmetric(horizontal: size * 0.14)
        : EdgeInsets.zero;

    final _WordTok(:text, :ayah, :endsAyah) = tok as _WordTok;
    final selected = _isSelected(ayah);

    return Padding(
      padding: pad,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ayahGesture(
            ayah,
            Text(
              text,
              textDirection: TextDirection.rtl,
              style: _textStyle(size).copyWith(
                backgroundColor: selected
                    ? AppColors.gold.withValues(alpha: 0.22)
                    : null,
              ),
            ),
          ),
          if (endsAyah) ...[
            SizedBox(width: size * 0.2),
            _buildMedallion(ayah, size),
          ],
        ],
      ),
    );
  }

  /// Tap selects the ayah; long press hands it, and where it was pressed, to
  /// the caller.
  Widget _ayahGesture(Ayah ayah, Widget child) => GestureDetector(
    onTap: () => widget.onAyahTap(ayah),
    onLongPressStart: widget.onAyahLongPress == null
        ? null
        : (details) => widget.onAyahLongPress!(ayah, details.globalPosition),
    child: child,
  );

  bool _isSelected(Ayah ayah) {
    final sel = widget.selected;
    return sel != null && sel.sura == ayah.sura && sel.number == ayah.number;
  }

  Widget _buildMedallion(Ayah ayah, double size) {
    final selected = _isSelected(ayah);
    final diameter = size * 1.25;
    return _ayahGesture(
      ayah,
      Container(
        width: diameter,
        height: diameter,
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
          _arabicDigits(ayah.number),
          textDirection: TextDirection.rtl,
          style: arabic(
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.tealStart,
          ),
        ),
      ),
    );
  }

  Widget _buildSurahOpening(SurahOpening opening, double size) {
    final ch = QuranText.chapters.isNotEmpty &&
            opening.sura <= QuranText.chapters.length
        ? QuranText.chapters[opening.sura - 1]
        : null;
    final nameAr = ch?.nameAr ?? widget.surahNameAr ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: size * 2.0,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: size * 0.2),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.35),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(size),
            ),
            child: Row(
              children: [
                _buildBannerRosette(size),
                Expanded(
                  child: Text(
                    'سُورَةُ $nameAr',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: arabic(
                      fontSize: size * 0.8,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                _buildBannerRosette(size),
              ],
            ),
          ),
        ),
        if (opening.showBasmalah)
          SizedBox(
            height: size * 2.0,
            child: Center(
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: arabic(
                  fontSize: size * 0.85,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealStart,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerRosette(double size) => Padding(
    padding: EdgeInsets.symmetric(horizontal: size * 0.4),
    child: Icon(
      Icons.brightness_7_outlined,
      size: size * 0.7,
      color: AppColors.gold.withValues(alpha: 0.8),
    ),
  );

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
}

