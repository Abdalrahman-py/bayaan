import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/models.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'compare_data.dart';
import 'widgets/audio_compare_card.dart';

/// Compare screen (ported from the bayyan client): reference ayah plate,
/// master-recitation card and your-recitation card with error bars derived
/// from the real mistake list. Reference audio is not bundled yet, so the
/// waveforms are synthetic and playback is an animated simulation.
class AudioCompareScreen extends StatefulWidget {
  final Verse verse;
  final List<Mistake> mistakes;
  final String masterName;

  const AudioCompareScreen({
    super.key,
    required this.verse,
    required this.mistakes,
    this.masterName = 'Sheikh Al-Husary',
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

  int get _score {
    final issues = widget.mistakes.length;
    return (100 - (issues * 12)).clamp(15, 95);
  }

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
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildReferencePlate(),
                  const SizedBox(height: 20),
                  _buildMasterCard(),
                  const SizedBox(height: 20),
                  _buildUserCard(),
                ],
              ),
            ),
            AppBottomNav(currentIndex: 0, onTap: (i) {}),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF5F1E6)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: AppColors.textDark,
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
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Analyze your timing against masters',
                  style: pjs(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencePlate() {
    return FadeTransition(
      opacity: _referenceAnim,
      child: ScaleTransition(
        scale: _referenceAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF5F1E6)),
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

  Widget _buildMasterCard() {
    return FadeTransition(
      opacity: _masterCardAnim,
      child: SlideTransition(
        position: _masterCardSlide,
        child: AudioCompareCard(
          badgeLabel: 'Master Recitation',
          badgeBg: AppColors.cream,
          badgeTextColor: AppColors.gold,
          trailingText: widget.masterName,
          trailingTextColor: AppColors.textMuted,
          playButtonColor: AppColors.tealStart,
          iconColor: Colors.white,
          borderColor: AppColors.gold,
          waveformHeights: waveformHeights(
            _barCount,
            seed: widget.verse.sura * 1000 + widget.verse.aya,
          ),
          waveformColor: AppColors.tealStart,
        ),
      ),
    );
  }

  Widget _buildUserCard() {
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
          badgeBg: const Color(0xFFE0F2FE),
          badgeTextColor: const Color(0xFF0369A1),
          trailingText: '$_score% Accuracy',
          trailingTextColor: AppColors.tealStart,
          playButtonColor: const Color(0xFFE0DCD3),
          iconColor: AppColors.textDark,
          borderColor: const Color(0xFFF5F1E6),
          waveformHeights: waveformHeights(
            _barCount,
            seed: widget.verse.aya * 7 + widget.verse.sura,
          ),
          waveformColor: AppColors.textMuted,
          errorBarIndices: errorBars,
        ),
      ),
    );
  }
}
