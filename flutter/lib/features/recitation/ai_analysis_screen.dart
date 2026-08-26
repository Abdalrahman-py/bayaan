import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/models.dart';
import '../../services/recitation_controller.dart';
import '../../shared/widgets/animated_score_ring.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/ornamental_divider.dart';

/// bayaan-ai-analysis from Figma — the mistakes-found result screen. Shown
/// when ResultState.allCorrect is false; CelebrationScreen handles the
/// all-correct case.
class AiAnalysisScreen extends StatefulWidget {
  final RecitationController controller;
  final int sura;
  final int aya;

  const AiAnalysisScreen({
    super.key,
    required this.controller,
    required this.sura,
    required this.aya,
  });

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// issues * 12 points off, floor 15 — a real number derived from the
  /// actual mistake count, not a fabricated stat.
  int _score(ResultState r) {
    final issues = r.mistakes.length + r.sifatErrors.length;
    return (100 - (issues * 12)).clamp(15, 95);
  }

  void _showMistakeInfo(Mistake m) {
    final rule = m.ruleNameEn ?? m.kind;
    final detail = (m.expectedLen != null && m.gotLen != null)
        ? 'Expected ${m.expectedLen} · heard ${m.gotLen}'
        : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(detail == null ? rule : '$rule — $detail')),
    );
  }

  List<InlineSpan> _buildSpans(Verse verse, List<Mistake> mistakes) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = verse.uthmani;
    final ranges = List.of(mistakes)
      ..sort((a, b) => a.charRange.start.compareTo(b.charRange.start));
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in ranges) {
      final start = m.charRange.start.clamp(0, text.length);
      final end = math.max(start, m.charRange.end.clamp(0, text.length));
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      final color = m.isTajweed ? AppColors.tajweedError : AppColors.plainError;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showMistakeInfo(m);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            fontWeight: FontWeight.bold,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.stateFor(widget.sura, widget.aya);
    final result = state is ResultState ? state : null;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: result == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        const SizedBox(height: 8),
                        _buildScoreCard(result),
                        const SizedBox(height: 16),
                        _buildVerseCard(result),
                        const SizedBox(height: 16),
                        _buildInfoBanner(),
                        const SizedBox(height: 16),
                        _buildCompareButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
            AppBottomNav(
              currentIndex: 0,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.home),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
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
                'Recitation Analysis',
                style: pjs(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Detail of your tajweed feedback',
                style: pjs(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(ResultState result) {
    final score = _score(result);
    final issues = result.mistakes.length + result.sifatErrors.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealStart.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 170,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildDecorSquare(22.5),
                _buildDecorSquare(67.5),
                AnimatedScoreRing(score: score),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$issues ${issues == 1 ? 'area' : 'areas'} to refine',
            style: pjs(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorSquare(double degrees) {
    return Transform.rotate(
      angle: degrees * 3.14159 / 180,
      child: Container(
        width: 150,
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildVerseCard(ResultState result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const OrnamentalDivider(width: double.infinity, opacity: 0.3),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: arabic(
                fontSize: 24,
                color: AppColors.tealStart,
                height: 1.9,
              ),
              children: _buildSpans(result.verse, result.mistakes),
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const OrnamentalDivider(width: double.infinity, opacity: 0.3),
        ],
      ),
    );
  }

  Widget _buildCompareButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () =>
            context.push(AppRoutes.audioComparePath(widget.sura, widget.aya)),
        icon: const Icon(Icons.compare_arrows_rounded, size: 18),
        label: Text(
          'Compare with Master',
          style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tealStart,
          side: const BorderSide(color: AppColors.gold, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sifatError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, size: 18, color: AppColors.sifatError),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap a highlighted word to view pronunciation feedback.',
              style: pjs(
                fontSize: 13,
                color: AppColors.sifatError,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
