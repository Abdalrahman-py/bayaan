import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../models/models.dart';
import '../../services/app_settings.dart';
import '../../services/reciter_audio.dart';
import '../../shared/animation/score_math.dart';
import 'compare_data.dart';
import 'widgets/audio_compare_card.dart';

/// Compare screen (ported from the bayyan client): reference ayah plate,
/// master-recitation card and your-recitation card with error bars derived
/// from the real mistake list. The master card streams the chosen reciter's
/// recording; the user's own recitation is not kept after upload, so that
/// card's waveform is still a stand-in.
class AudioCompareScreen extends StatefulWidget {
  final Verse verse;
  final List<Mistake> mistakes;
  final List<SifatError> sifatErrors;

  /// The user's own recording of this ayah, when they have just recited it.
  final Uint8List? recording;

  const AudioCompareScreen({
    super.key,
    required this.verse,
    required this.mistakes,
    this.sifatErrors = const [],
    this.recording,
  });

  @override
  State<AudioCompareScreen> createState() => _AudioCompareScreenState();
}

class _AudioCompareScreenState extends State<AudioCompareScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _headerFade;
  late final Animation<double> _referenceAnim;
  late final Animation<double> _masterCardAnim;
  late final Animation<Offset> _masterCardSlide;
  late final Animation<double> _userCardAnim;
  late final Animation<Offset> _userCardSlide;

  static const int _barCount = 24;

  final Reciter _reciter = AppSettings.instance.reciter;

  int get _score => recitationScore(
    mistakes: widget.mistakes.length,
    sifatErrors: widget.sifatErrors.length,
  );

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _headerFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _referenceAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
    );
    _masterCardAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _masterCardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_masterCardAnim);
    _userCardAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );
    _userCardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_userCardAnim);

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, palette),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildReferencePlate(palette),
                  const SizedBox(height: 20),
                  _buildMasterCard(palette),
                  const SizedBox(height: 20),
                  _buildUserCard(palette),
                  const SizedBox(height: 20),
                  _buildMatchCard(palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette palette) {
    return FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  border: Border.all(color: palette.borderColor),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compare Recitations',
                  style: pjs(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  'Analyze your timing against masters',
                  style: pjs(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencePlate(AppPalette palette) {
    return FadeTransition(
      opacity: _referenceAnim,
      child: ScaleTransition(
        scale: _referenceAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.cardBg,
            border: Border.all(color: palette.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.verse.uthmani,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: arabic(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.tealStart,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterCard(AppPalette palette) {
    return FadeTransition(
      opacity: _masterCardAnim,
      child: SlideTransition(
        position: _masterCardSlide,
        child: AudioCompareCard(
          badgeLabel: 'Master Recitation',
          badgeBg: AppColors.cream,
          badgeTextColor: AppColors.gold,
          trailingText: _reciter.shortName,
          trailingTextColor: palette.textMuted,
          playButtonColor: AppColors.tealStart,
          iconColor: Colors.white,
          borderColor: AppColors.gold,
          waveformHeights: waveformHeights(
            _barCount,
            seed: widget.verse.sura * 1000 + widget.verse.aya,
          ),
          waveformColor: AppColors.tealStart,
          audioUrl: _reciter.urlFor(widget.verse.sura, widget.verse.aya),
          autoPlay: AppSettings.instance.autoPlayReference,
        ),
      ),
    );
  }

  /// Ranks what went wrong most often, so "practise this next" is concrete.
  List<MapEntry<String, int>> get _focusAreas {
    final counts = <String, int>{};
    for (final m in widget.mistakes) {
      final label = m.ruleNameEn ?? (m.isTajweed ? 'Tajweed' : 'Pronunciation');
      counts[label] = (counts[label] ?? 0) + 1;
    }
    for (final e in widget.sifatErrors) {
      counts[e.attribute] = (counts[e.attribute] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  Widget _buildMatchCard(AppPalette palette) {
    final focus = _focusAreas;
    final total = widget.mistakes.length + widget.sifatErrors.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'How close you were',
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                '$_score%',
                style: pjs(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tealStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _score / 100,
              minHeight: 8,
              backgroundColor: palette.borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.tealStart,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            total == 0
                ? 'Matched the reference with no issues detected.'
                : '$total ${total == 1 ? 'difference' : 'differences'} from '
                      '${_reciter.shortName}\'s recitation.',
            style: pjs(fontSize: 13, color: palette.textMuted),
          ),
          if (focus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Focus on',
              style: pjs(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in focus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      entry.value > 1
                          ? '${entry.key} ×${entry.value}'
                          : entry.key,
                      style: pjs(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserCard(AppPalette palette) {
    final errorBars = mistakeBins(
      widget.mistakes,
      widget.verse.uthmani.length,
      _barCount,
    );
    return FadeTransition(
      opacity: _userCardAnim,
      child: SlideTransition(
        position: _userCardSlide,
        child: AudioCompareCard(
          badgeLabel: 'Your Recitation',
          badgeBg: palette.isDark
              ? AppColorsDark.tealStart.withValues(alpha: 0.2)
              : const Color(0xFFE0F2FE),
          badgeTextColor: palette.isDark
              ? AppColorsDark.tealStart
              : const Color(0xFF0369A1),
          trailingText: '$_score% Accuracy',
          trailingTextColor: AppColors.tealStart,
          playButtonColor: palette.isDark
              ? AppColorsDark.borderColor
              : const Color(0xFFE0DCD3),
          iconColor: palette.textPrimary,
          borderColor: palette.borderColor,
          waveformHeights: waveformHeights(
            _barCount,
            seed: widget.verse.aya * 7 + widget.verse.sura,
          ),
          waveformColor: palette.textMuted,
          errorBarIndices: errorBars,
          audioBytes: widget.recording,
        ),
      ),
    );
  }
}
