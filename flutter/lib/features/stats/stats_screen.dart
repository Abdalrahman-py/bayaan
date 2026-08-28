import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../services/learn_repository.dart';
import '../../services/progress_repository.dart';
import '../../services/quran_text.dart';
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
      setState(() => _error = 'Sign in to see your progress.');
      return;
    }
    if (_error != null) setState(() => _error = null);
    try {
      // ponytail: three round-trips because the header lives on `learn` and the
      // stats on `progress`. Collapse into one endpoint if this ever feels slow.
      final results = await Future.wait([
        LearnRepository.path(token),
        ProgressRepository.summary(token),
        ProgressRepository.sessions(token),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = _Stats(
          (results[0] as LearnPath).header,
          results[1] as ProgressSummary,
          results[2] as List<RecitationSession>,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't load your progress. Pull to retry.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      backgroundColor: AppColors.lightBg,
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
                _buildHeader(),
                const SizedBox(height: 20),
                if (_error != null)
                  _message(_error!)
                else if (stats == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildMetricsGrid(stats),
                  const SizedBox(height: 24),
                  _buildWeeklyActivityCard(stats.sessions),
                  const SizedBox(height: 24),
                  _buildFocusAreasCard(stats.summary),
                  const SizedBox(height: 24),
                  _buildRecentSessionsCard(stats.sessions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: pjs(fontSize: 14, color: AppColors.textMuted),
      ),
    ),
  );

  Widget _buildHeader() {
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
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Consistency is the key to mastery',
              style: pjs(fontSize: 13, color: AppColors.textMuted),
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

  Widget _buildMetricsGrid(_Stats stats) {
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
              iconBgColor: const Color(0xFFFFF7ED),
              value: '${header.streakCount} ${header.streakCount == 1 ? "Day" : "Days"}',
              label: 'Streak',
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.mic_rounded,
              iconColor: AppColors.tealStart,
              iconBgColor: AppColors.tealStart.withValues(alpha: 0.1),
              value: '${summary.totalSessions}',
              label: 'Ayahs Recited',
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.verified_rounded,
              iconColor: AppColors.success,
              iconBgColor: AppColors.success.withValues(alpha: 0.1),
              value: '${(summary.overallAccuracy * 100).round()}%',
              label: 'Tajweed Accuracy',
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.bolt_rounded,
              iconColor: AppColors.gold,
              iconBgColor: AppColors.gold.withValues(alpha: 0.15),
              value: '${header.xp}',
              label: 'Total XP',
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
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
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
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: pjs(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _buildWeeklyActivityCard(List<RecitationSession> sessions) {
    final today = _startOfDay(DateTime.now());
    // Last 7 days, oldest first — a bucket per day of recitation counts.
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days
        .map((d) => sessions.where((s) => _startOfDay(s.createdAt) == d).length)
        .toList();
    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);

    return _card(
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
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: height,
                      decoration: BoxDecoration(
                        color: count == 0
                            ? const Color(0xFFF5F1E6)
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
                            ? AppColors.textDark
                            : AppColors.textMuted,
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

  /// Tajweed rules and sifat the reciter misses most — the only per-rule signal
  /// the backend records is a mistake count, so this is "where to focus", not
  /// a mastery percentage.
  Widget _buildFocusAreasCard(ProgressSummary summary) {
    final entries = [
      ...summary.mistakeBreakdown.entries.map((e) => (e.key, e.value, AppColors.tajweedError)),
      ...summary.sifatBreakdown.entries.map((e) => (e.key, e.value, AppColors.sifatError)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final top = entries.take(5).toList();
    final maxCount = top.isEmpty ? 0 : top.first.$2;

    return _card(
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
                                  color: AppColors.textDark,
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
                            backgroundColor: const Color(0xFFF5F1E6),
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

  Widget _buildRecentSessionsCard(List<RecitationSession> sessions) {
    final recent = sessions.take(5).toList();
    return _card(
      title: 'Recent Practice Sessions',
      child: recent.isEmpty
          ? _emptyLine('No recitations yet.')
          : Column(
              children: [
                for (final s in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                s.allCorrect
                                    ? 'Ayah ${s.aya} · no mistakes'
                                    : 'Ayah ${s.aya} · ${s.mistakesCount} '
                                          '${s.mistakesCount == 1 ? "mistake" : "mistakes"}',
                                style: pjs(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _relativeDate(s.createdAt),
                          style: pjs(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
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

  Widget _emptyLine(String text) => Text(
    text,
    style: pjs(fontSize: 13, color: AppColors.textMuted),
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

  Widget _card({required String title, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F1E6)),
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
                  color: AppColors.textDark,
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
