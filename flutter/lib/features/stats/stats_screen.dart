import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../models/models.dart';
import '../../services/auth_controller.dart';
import '../../services/learn_repository.dart';
import '../../services/progress_repository.dart';
import '../../services/quran_text.dart';
import '../audio_compare/audio_compare_screen.dart';
import '../learn/models/lesson.dart';

/// Progress, Tajweed accuracy, and recitation stats — all read from the
/// `progress` Edge Function (summary + sessions) and the `learn` header
/// (xp / streak / level). Nothing on this screen is synthetic.
class StatsScreen extends StatefulWidget {
  final AuthController auth;
  const StatsScreen({super.key, required this.auth});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _Stats {
  final LearnHeader header;
  final ProgressSummary summary;
  final List<RecitationSession> sessions;
  const _Stats(this.header, this.summary, this.sessions);
}

class _StatsScreenState extends State<StatsScreen> {
  _Stats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.auth.accessToken;
    if (token == null) {
      if (mounted) {
        setState(() => _error = 'Sign in to see your progress.');
      }
      return;
    }

    LearnHeader? header;
    ProgressSummary? summary;
    List<RecitationSession>? sessions;

    try {
      final results = await Future.wait([
        LearnRepository.path(token)
            .then<LearnHeader?>((p) => p.header)
            .catchError((_) => null),
        ProgressRepository.summary(token)
            .then<ProgressSummary?>((s) => s)
            .catchError((_) => null),
        ProgressRepository.sessions(token)
            .then<List<RecitationSession>?>((s) => s)
            .catchError((_) => null),
      ]);
      header = results[0] as LearnHeader?;
      summary = results[1] as ProgressSummary?;
      sessions = results[2] as List<RecitationSession>?;
    } catch (_) {}

    header ??= const LearnHeader(
      arabicLevel: 0,
      xp: 0,
      streakCount: 0,
      dailyGoalMinutes: 10,
      reviewsDue: 0,
    );

    summary ??= const ProgressSummary(
      totalSessions: 0,
      perfectSessions: 0,
      overallAccuracy: 0.0,
      totalMistakes: 0,
      mistakeBreakdown: {},
      sifatBreakdown: {},
    );

    sessions ??= const [];

    if (mounted) {
      setState(() {
        _stats = _Stats(header!, summary!, sessions!);
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final stats = _stats;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.tealStart,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(palette),
                const SizedBox(height: 20),
                if (_error != null)
                  _message(_error!, palette)
                else if (stats == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildMetricsGrid(stats, palette),
                  const SizedBox(height: 24),
                  _buildWeeklyActivityCard(stats.sessions, palette),
                  const SizedBox(height: 24),
                  _buildFocusAreasCard(stats.summary, palette),
                  const SizedBox(height: 24),
                  _buildRecentSessionsCard(stats.sessions, palette),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text, AppPalette palette) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: pjs(fontSize: 14, color: palette.textMuted),
      ),
    ),
  );

  Widget _buildHeader(AppPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Progress',
              style: pjs(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Consistency is the key to mastery',
              style: pjs(fontSize: 13, color: palette.textMuted),
            ),
          ],
        ),
        Text(
          'وَقُل رَّبِّ زِدْنِي عِلْمًا',
          textDirection: TextDirection.rtl,
          style: arabic(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(_Stats stats, AppPalette palette) {
    final summary = stats.summary;
    final header = stats.header;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFF97316),
              iconBgColor: const Color(0xFFF97316).withValues(alpha: 0.15),
              value: '${header.streakCount} ${header.streakCount == 1 ? "Day" : "Days"}',
              label: 'Streak',
              palette: palette,
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.mic_rounded,
              iconColor: AppColors.tealStart,
              iconBgColor: AppColors.tealStart.withValues(alpha: 0.1),
              value: '${summary.totalSessions}',
              label: 'Ayahs Recited',
              palette: palette,
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.verified_rounded,
              iconColor: AppColors.success,
              iconBgColor: AppColors.success.withValues(alpha: 0.1),
              value: '${(summary.overallAccuracy * 100).round()}%',
              label: 'Tajweed Accuracy',
              palette: palette,
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.bolt_rounded,
              iconColor: AppColors.gold,
              iconBgColor: AppColors.gold.withValues(alpha: 0.15),
              value: '${header.xp}',
              label: 'Total XP',
              palette: palette,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required double width,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String value,
    required String label,
    required AppPalette palette,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: pjs(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: pjs(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _buildWeeklyActivityCard(List<RecitationSession> sessions, AppPalette palette) {
    final today = _startOfDay(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days
        .map((d) => sessions.where((s) => _startOfDay(s.createdAt) == d).length)
        .toList();
    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);

    return _card(
      palette: palette,
      title: 'Weekly Recitation',
      trailing: _pill(
        '$total ${total == 1 ? "ayah" : "ayahs"}',
        AppColors.tealStart,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (_) {
                final isToday = i == 6;
                final count = counts[i];
                final double height = maxCount == 0
                    ? 12
                    : (count / maxCount) * 80.0 + 12.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: pjs(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? AppColors.tealStart
                            : palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: height,
                      decoration: BoxDecoration(
                        color: count == 0
                            ? palette.borderColor
                            : isToday
                            ? AppColors.tealStart
                            : AppColors.tealStart.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dayNames[days[i].weekday - 1],
                      style: pjs(
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isToday
                            ? palette.textPrimary
                            : palette.textMuted,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFocusAreasCard(ProgressSummary summary, AppPalette palette) {
    final entries = [
      ...summary.mistakeBreakdown.entries.map((e) => (e.key, e.value, AppColors.tajweedError)),
      ...summary.sifatBreakdown.entries.map((e) => (e.key, e.value, AppColors.sifatError)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final top = entries.take(5).toList();
    final maxCount = top.isEmpty ? 0 : top.first.$2;

    return _card(
      palette: palette,
      title: 'Focus Areas',
      trailing: Text(
        '${summary.totalMistakes} total',
        style: pjs(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
      child: top.isEmpty
          ? _emptyLine(
              summary.totalSessions == 0
                  ? 'Recite an ayah to see where to focus.'
                  : 'No mistakes recorded — keep it up.',
              palette,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (name, count, color) in top)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: pjs(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '$count ${count == 1 ? "miss" : "misses"}',
                              style: pjs(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: maxCount == 0 ? 0 : count / maxCount,
                            minHeight: 7,
                            backgroundColor: palette.borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildRecentSessionsCard(List<RecitationSession> sessions, AppPalette palette) {
    final recent = sessions.take(5).toList();
    return _card(
      palette: palette,
      title: 'Recent Practice Sessions',
      trailing: GestureDetector(
        onTap: () => context.push(AppRoutes.sessionHistory),
        child: Text(
          'History ›',
          style: pjs(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.tealStart,
          ),
        ),
      ),
      child: recent.isEmpty
          ? _emptyLine('No recitations yet.', palette)
          : Column(
              children: [
                for (final s in recent)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final verse = QuranText.verse(s.sura, s.aya) ??
                          Verse(
                            sura: s.sura,
                            aya: s.aya,
                            uthmani: '',
                            surahNameEn: 'Surah ${s.sura}',
                            surahNameAr: '',
                          );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AudioCompareScreen(
                            verse: verse,
                            mistakes: const [],
                            sifatErrors: const [],
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (s.allCorrect
                                      ? AppColors.success
                                      : AppColors.tajweedError)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              s.allCorrect
                                  ? Icons.check_rounded
                                  : Icons.priority_high_rounded,
                              size: 20,
                              color: s.allCorrect
                                  ? AppColors.success
                                  : AppColors.tajweedError,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  QuranText.verse(s.sura, s.aya)?.surahNameEn ??
                                      'Surah ${s.sura}',
                                  style: pjs(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  s.allCorrect
                                      ? 'Ayah ${s.aya} · no mistakes'
                                      : 'Ayah ${s.aya} · ${s.mistakesCount} '
                                            '${s.mistakesCount == 1 ? "mistake" : "mistakes"}',
                                  style: pjs(
                                    fontSize: 12,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _relativeDate(s.createdAt),
                            style: pjs(fontSize: 11, color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  static String _relativeDate(DateTime when) {
    final days = _startOfDay(DateTime.now()).difference(_startOfDay(when)).inDays;
    return switch (days) {
      <= 0 => 'Today',
      1 => 'Yesterday',
      < 7 => '$days days ago',
      < 30 => '${days ~/ 7}w ago',
      _ => '${when.year}-${when.month.toString().padLeft(2, '0')}-'
          '${when.day.toString().padLeft(2, '0')}',
    };
  }

  Widget _emptyLine(String text, AppPalette palette) => Text(
    text,
    style: pjs(fontSize: 13, color: palette.textMuted),
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      text,
      style: pjs(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _card({
    required AppPalette palette,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
