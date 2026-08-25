import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/models.dart';
import '../../services/auth_controller.dart';
import '../../services/quran_translation.dart';
import '../../services/recitation_controller.dart';
import '../../shared/widgets/ornamental_divider.dart';

/// bayaan-recording from Figma. The verse card leaves a lot of empty space
/// below it before the mic button — filled with a translation card (per
/// Ramzi's suggestion) so a non-Arabic speaker knows what they're about to
/// recite, instead of sitting empty.
class RecordingScreen extends StatefulWidget {
  final RecitationController controller;
  final AuthController auth;
  final int sura;
  final int aya;

  const RecordingScreen({
    super.key,
    required this.controller,
    required this.auth,
    required this.sura,
    required this.aya,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  String? _translation;
  String? _transliteration;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    QuranTranslation.forSurah(widget.sura).then((map) {
      if (!mounted || map == null) return;
      setState(() => _translation = map[widget.aya]);
    });
    QuranTranslation.transliterationForSurah(widget.sura).then((map) {
      if (!mounted || map == null) return;
      setState(() => _transliteration = map[widget.aya]);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    final s = widget.controller.stateFor(widget.sura, widget.aya);
    if (_navigated) return;
    if (s is ResultState) {
      _navigated = true;
      final path = s.allCorrect
          ? AppRoutes.celebrationPath(widget.sura, widget.aya)
          : AppRoutes.aiAnalysisPath(widget.sura, widget.aya);
      context.push(path).then((_) {
        _navigated = false;
        widget.controller.retry(widget.sura, widget.aya);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final state = widget.controller.stateFor(widget.sura, widget.aya);
            return Column(
              children: [
                _buildHeader(state.verse),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        _buildVerseCard(state.verse),
                        const SizedBox(height: 20),
                        _buildCaption(state),
                        const SizedBox(height: 20),
                        if (state is Ready) _buildTranslationCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildMicArea(state),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Verse verse) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await widget.controller.discard(widget.sura, widget.aya);
              if (!context.mounted) return;
              context.canPop() ? context.pop() : context.go(AppRoutes.home);
            },
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
          Expanded(
            child: Text(
              '${verse.surahNameEn} · Ayah ${verse.aya}',
              textAlign: TextAlign.center,
              style: pjs(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildVerseCard(Verse verse) {
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
          Text(
            verse.uthmani,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: arabic(
              fontSize: 26,
              color: AppColors.tealStart,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 16),
          const OrnamentalDivider(width: double.infinity, opacity: 0.3),
        ],
      ),
    );
  }

  Widget _buildCaption(RecitationUiState state) {
    final label = switch (state) {
      Recording() => 'Recording… tap to stop',
      Uploading() => 'Analyzing your recitation…',
      ErrorState(:final message) => message,
      _ => 'Recite clearly in a quiet environment',
    };
    final color = state is ErrorState
        ? AppColors.tajweedError
        : AppColors.textMuted;
    return Text(
      label,
      textAlign: TextAlign.center,
      style: pjs(fontSize: 13, color: color),
    );
  }

  Widget _buildTranslationCard() {
    if (_translation == null && _transliteration == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream.withOpacity(0.5),
        border: Border.all(color: const Color(0xFFF5F1E6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_transliteration != null) ...[
            Row(
              children: [
                Icon(Icons.record_voice_over, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  'HOW TO SAY IT',
                  style: pjs(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _transliteration!,
              style: pjs(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: AppColors.textDark,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (_translation != null) ...[
            if (_transliteration != null) const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.translate, size: 14, color: AppColors.tealStart),
                const SizedBox(width: 6),
                Text(
                  'MEANING',
                  style: pjs(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tealStart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _translation!,
              style: pjs(fontSize: 14, height: 1.5, color: AppColors.textDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicArea(RecitationUiState state) {
    if (state is Uploading) {
      return const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final recording = state is Recording;
    final elapsed = recording ? state.elapsedSec : 0;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (recording) {
              widget.controller.stop(
                widget.sura,
                widget.aya,
                widget.auth.accessToken,
              );
            } else if (state is ErrorState) {
              widget.controller.retry(widget.sura, widget.aya);
            } else {
              widget.controller.start(widget.sura, widget.aya);
            }
          },
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (recording ? AppColors.tajweedError : AppColors.tealStart)
                  .withOpacity(0.15),
            ),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording ? AppColors.tajweedError : AppColors.tealStart,
              ),
              child: Icon(
                recording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recording
              ? '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}'
              : 'TAP TO RECITE',
          style: pjs(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.tealStart,
          ),
        ),
      ],
    );
  }
}
