import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
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

/// Mushaf-style paged ayah browser (ported from the bayyan client): ayahs are
/// grouped onto their real mushaf pages and rendered as simple-text pages —
/// gold-framed, ayah-number medallions, tappable ayahs. No QCF glyph fonts.
class MushafPageView extends StatefulWidget {
  final List<Ayah> ayahs;
  final ValueChanged<Ayah> onAyahTap;

  const MushafPageView({
    super.key,
    required this.ayahs,
    required this.onAyahTap,
  });

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  late final List<List<Ayah>> _pages;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pages = groupAyahsByMushafPage(widget.ayahs);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: _MushafPage(
                    ayahs: _pages[index],
                    mushafPageNumber: _pages[index].first.pageNumber,
                    onAyahTap: widget.onAyahTap,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_pages.length > 1) _buildPageDots(),
        ],
      ),
    );
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final bool isActive = index == _currentPage;
        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.tealStart
                  : AppColors.gold.withOpacity(0.35),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        );
      }),
    );
  }
}

class _MushafPage extends StatefulWidget {
  final List<Ayah> ayahs;
  final int mushafPageNumber;
  final ValueChanged<Ayah> onAyahTap;

  const _MushafPage({
    required this.ayahs,
    required this.mushafPageNumber,
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
    for (final ayah in widget.ayahs) {
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => widget.onAyahTap(ayah),
      );
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7), // warm mushaf-paper white
          border: Border.all(color: AppColors.gold, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealStart.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Thin inner gold frame — "gilded panel" feel of traditional mushafs.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            ..._buildCornerOrnaments(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: RichText(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.justify,
                        text: TextSpan(
                          style: arabic(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 2.2,
                            color: AppColors.tealStart,
                          ),
                          children: _buildAyahSpans(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPageFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerOrnaments() {
    Widget corner(Alignment alignment) {
      return Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 1.5),
              borderRadius: BorderRadius.circular(3),
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
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Text(
        '${widget.mushafPageNumber}',
        style: pjs(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.tealStart,
        ),
      ),
    );
  }

  List<InlineSpan> _buildAyahSpans() {
    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      spans.add(
        TextSpan(text: '${ayah.arabicText} ', recognizer: _recognizers[i]),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lightBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: Text(
                '${ayah.number}',
                style: pjs(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tealStart,
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
