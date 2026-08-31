import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../models/models.dart';
import '../../services/quran_text.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import '../audio_compare/audio_compare_screen.dart';
import 'models/session_record.dart';

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

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
                  if (mockSessionRecords.isEmpty)
                    _buildEmptyState(context, palette)
                  else ...[
                    _buildSectionLabel('RECENT ATTEMPTS', palette),
                    const SizedBox(height: 12),
                    ...List.generate(mockSessionRecords.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaggeredFadeSlide(
                          index: index,
                          child: _SessionCard(
                            session: mockSessionRecords[index],
                            palette: palette,
                            onCompareTap: () => _openCompare(
                              context,
                              mockSessionRecords[index],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCompare(BuildContext context, SessionRecord session) {
    final verse = QuranText.verse(session.surahNumber, session.ayahNumber) ??
        Verse(
          sura: session.surahNumber,
          aya: session.ayahNumber,
          uthmani: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          surahNameEn: session.surahNameEnglish,
          surahNameAr: session.surahNameArabic,
        );

    final mockMistakes = List.generate(
      session.mistakesCount,
      (i) => Mistake(
        charRange: CharRange(i * 3, i * 3 + 2),
        isTajweed: true,
        kind: 'replace',
        ruleNameEn: session.tags.isNotEmpty ? session.tags[i % session.tags.length] : 'Tajweed Rule',
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioCompareScreen(
          verse: verse,
          mistakes: mockMistakes,
          sifatErrors: const [],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.cardBg,
                border: Border.all(color: palette.borderColor),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_left, size: 20, color: palette.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session History',
                style: pjs(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                'Replay and compare your recitation attempts',
                style: pjs(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, AppPalette palette) {
    return Text(
      text,
      style: pjs(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: palette.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.mic_none_rounded, size: 32, color: AppColors.gold),
          ),
          const SizedBox(height: 20),
          Text(
            'No sessions yet',
            style: pjs(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start your first recitation to review it here.',
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 13,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go(AppRoutes.home);
            },
            child: Text(
              'Go to Home',
              style: pjs(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.tealStart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionRecord session;
  final AppPalette palette;
  final VoidCallback onCompareTap;

  const _SessionCard({
    required this.session,
    required this.palette,
    required this.onCompareTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHighScore = session.score >= 90;
    final Color badgeBg = isHighScore
        ? AppColors.tealStart.withValues(alpha: 0.15)
        : AppColors.gold.withValues(alpha: 0.15);
    final Color badgeText = isHighScore ? AppColors.tealStart : AppColors.gold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            children: [
              Text(
                '${session.surahNameEnglish} · Ayah ${session.ayahNumber}',
                style: pjs(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${session.score}%',
                  style: pjs(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${session.time} · ${session.duration} · ${session.mistakesCount} ${session.mistakesCount == 1 ? "mistake" : "mistakes"}',
            style: pjs(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: session.tags.map((tag) => _buildTagChip(tag)).toList(),
                ),
              ),
              GestureDetector(
                onTap: onCompareTap,
                child: Text(
                  'Compare attempts ›',
                  style: pjs(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.borderColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: pjs(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
        ),
      ),
    );
  }
}
