
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/models.dart';
import '../../services/recitation_controller.dart';
import 'highlighted_verse.dart';
import 'mistake_highlights.dart';
import '../../shared/animation/score_math.dart';
import '../../shared/widgets/animated_score_ring.dart';
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
  int _score(ResultState r) => recitationScore(
    mistakes: r.mistakes.length,
    sifatErrors: r.sifatErrors.length,
  );

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
                        const SizedBox(height: 12),
                        _buildLegend(result),
                        const SizedBox(height: 16),
                        _buildMistakeList(result),
                        const SizedBox(height: 16),
                        _buildCompareButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
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
              child: const Icon(
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
          HighlightedVerse(
            text: result.verse.uthmani,
            highlights: mistakeHighlights(
              result.verse.uthmani,
              result.mistakes,
            ),
            style: arabic(
              fontSize: 24,
              color: AppColors.tealStart,
              height: 1.9,
            ),
            tajweedColor: AppColors.tajweedError,
            plainColor: AppColors.plainError,
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

  static const _tajweedLabel = 'Tajweed rule';
  static const _pronunciationLabel = 'Pronunciation';
  static const _sifatLabel = 'Letter quality';

  /// Says what the two highlight colours in the verse above actually mean.
  /// Tajweed slips and plain mispronunciations are different kinds of error
  /// and are corrected differently, so they never share a colour.
  Widget _buildLegend(ResultState result) {
    final hasTajweed = result.mistakes.any((m) => m.isTajweed);
    final hasPlain = result.mistakes.any((m) => !m.isTajweed);
    if (!hasTajweed && !hasPlain) return const SizedBox.shrink();
    return Row(
      children: [
        if (hasTajweed) ...[
          _legendChip(AppColors.tajweedError, _tajweedLabel),
          const SizedBox(width: 8),
        ],
        if (hasPlain) _legendChip(AppColors.plainError, _pronunciationLabel),
      ],
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: pjs(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  /// The exact sound flagged, snapped to cluster boundaries so a combining
  /// mark is never severed from its letter.
  String _snippet(Verse verse, Mistake m) =>
      mistakeSnippet(verse.uthmani, m);

  /// Leads with the length the rule requires, and says only which direction
  /// the attempt missed by.
  ///
  /// Deliberately never prints the heard count. `predicted_len` is the model's
  /// estimate from the CTC phoneme sequence, not a measurement of the audio's
  /// timeline, so "you held 2" can be wrong when the reciter held none at all.
  /// A learner told that would add two more counts, land on four, and walk
  /// away believing four is the rule. The target is authoritative and the
  /// direction is robust; the heard count is neither.
  static String _maddDetail(int got, int expected) {
    final target = expected == 1 ? '1 count' : '$expected counts';
    if (got < expected) return 'Hold $target — yours was too short';
    if (got > expected) return 'Hold $target — yours was too long';
    return 'Hold $target';
  }

  /// The engine reports an edit operation; the reciter needs plain words.
  static String _kindLabel(String kind) => switch (kind) {
    'insert' => 'Extra sound added',
    'delete' => 'Sound left out',
    'replace' => 'Pronounced differently',
    _ => kind,
  };

  /// Every mistake, laid out to be read straight through — tajweed rules
  /// first, then plain pronunciation, then letter characteristics (sifat),
  /// which the score already counted but the screen never used to show.
  Widget _buildMistakeList(ResultState result) {
    final tajweed = result.mistakes.where((m) => m.isTajweed).toList();
    final plain = result.mistakes.where((m) => !m.isTajweed).toList();
    final sifat = result.sifatErrors;
    if (tajweed.isEmpty && plain.isEmpty && sifat.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What to fix',
          style: pjs(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        if (tajweed.isNotEmpty)
          _section(
            title: _tajweedLabel,
            color: AppColors.tajweedError,
            count: tajweed.length,
            rows: [
              for (final m in tajweed)
                _mistakeRow(
                  color: AppColors.tajweedError,
                  arabicText: _snippet(result.verse, m),
                  title: m.ruleNameEn ?? _kindLabel(m.kind),
                  subtitle: m.ruleNameAr,
                  detail: (m.expectedLen != null && m.gotLen != null)
                      ? _maddDetail(m.gotLen!, m.expectedLen!)
                      // Without a rule name the title already says this.
                      : (m.ruleNameEn != null ? _kindLabel(m.kind) : null),
                ),
            ],
          ),
        if (plain.isNotEmpty) ...[
          if (tajweed.isNotEmpty) const SizedBox(height: 12),
          _section(
            title: _pronunciationLabel,
            color: AppColors.plainError,
            count: plain.length,
            rows: [
              for (final m in plain)
                _mistakeRow(
                  color: AppColors.plainError,
                  arabicText: _snippet(result.verse, m),
                  title: _kindLabel(m.kind),
                  subtitle: null,
                  detail: (m.expectedLen != null && m.gotLen != null)
                      ? _maddDetail(m.gotLen!, m.expectedLen!)
                      : null,
                ),
            ],
          ),
        ],
        if (sifat.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section(
            title: _sifatLabel,
            color: AppColors.sifatError,
            count: sifat.length,
            rows: [
              for (final e in sifat)
                _mistakeRow(
                  color: AppColors.sifatError,
                  arabicText: e.phonemesGroup,
                  title: e.attribute,
                  subtitle: null,
                  detail: 'Heard ${e.predicted} — should be ${e.expected}',
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _section({
    required String title,
    required Color color,
    required int count,
    required List<Widget> rows,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Text(
              '$title · $count',
              style: pjs(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          for (final row in rows) row,
        ],
      ),
    );
  }

  Widget _mistakeRow({
    required Color color,
    required String arabicText,
    required String title,
    required String? subtitle,
    required String? detail,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (arabicText.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 110),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                arabicText,
                textDirection: TextDirection.rtl,
                style: arabic(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          if (arabicText.isNotEmpty) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: pjs(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    textDirection: TextDirection.rtl,
                    style: arabic(fontSize: 14, color: AppColors.textMuted),
                  ),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail,
                      style: pjs(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
