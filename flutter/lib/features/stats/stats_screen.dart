import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/app_bottom_nav.dart';

/// Comprehensive progress, Tajweed accuracy, and recitation stats dashboard.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildWeeklyActivityCard(),
                    const SizedBox(height: 24),
                    _buildTajweedMasteryCard(),
                    const SizedBox(height: 24),
                    _buildRecentSessionsCard(),
                    const SizedBox(height: 24),
                    _buildAchievementsCard(),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              currentIndex: 2,
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

  Widget _buildMetricsGrid() {
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
              value: '7 Days',
              label: 'Streak',
              sublabel: 'Best: 14 days',
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.mic_rounded,
              iconColor: AppColors.tealStart,
              iconBgColor: AppColors.tealStart.withValues(alpha: 0.1),
              value: '48',
              label: 'Ayahs Practiced',
              sublabel: '+12 this week',
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.verified_rounded,
              iconColor: AppColors.success,
              iconBgColor: AppColors.success.withValues(alpha: 0.1),
              value: '94%',
              label: 'Tajweed Accuracy',
              sublabel: 'Top 5% reciter',
            ),
            _buildMetricTile(
              width: itemWidth,
              icon: Icons.bolt_rounded,
              iconColor: AppColors.gold,
              iconBgColor: AppColors.gold.withValues(alpha: 0.15),
              value: '650',
              label: 'Total XP',
              sublabel: 'Level 4 Explorer',
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
    required String sublabel,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Text(
                sublabel,
                style: pjs(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
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

  Widget _buildWeeklyActivityCard() {
    final List<Map<String, dynamic>> days = [
      {'day': 'Mon', 'mins': 25, 'active': true},
      {'day': 'Tue', 'mins': 40, 'active': true},
      {'day': 'Wed', 'mins': 15, 'active': true},
      {'day': 'Thu', 'mins': 50, 'active': true},
      {'day': 'Fri', 'mins': 35, 'active': true},
      {'day': 'Sat', 'mins': 60, 'active': true},
      {'day': 'Sun', 'mins': 20, 'active': true, 'isToday': true},
    ];

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
                'Weekly Recitation',
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '4h 5m total',
                  style: pjs(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final double height = ((d['mins'] as int) / 60.0) * 80.0 + 12.0;
              final bool isToday = d['isToday'] == true;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${d['mins']}m',
                    style: pjs(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppColors.tealStart : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 28,
                    height: height,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.tealStart
                          : AppColors.tealStart.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d['day'] as String,
                    style: pjs(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? AppColors.textDark : AppColors.textMuted,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTajweedMasteryCard() {
    final rules = [
      {'name': 'Ghunnah (غنة)', 'percent': 0.98, 'color': AppColors.success},
      {'name': 'Qalqalah (قلقلة)', 'percent': 0.92, 'color': AppColors.success},
      {'name': 'Madd Rules (المدود)', 'percent': 0.88, 'color': AppColors.tealStart},
      {'name': 'Ikhfa & Idgham (الإخفاء والإدغام)', 'percent': 0.85, 'color': AppColors.tealStart},
      {'name': 'Makharij & Sifat (المخارج والصفات)', 'percent': 0.90, 'color': AppColors.gold},
    ];

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
                'Tajweed Mastery',
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'AI Analysis',
                style: pjs(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rules.map((r) {
            final double p = r['percent'] as double;
            final Color color = r['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        r['name'] as String,
                        style: pjs(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '${(p * 100).toInt()}%',
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
                      value: p,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFF5F1E6),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard() {
    final sessions = [
      {
        'surah': 'Al-Fatihah',
        'ayahs': 'Ayahs 1–7',
        'score': 98,
        'date': 'Today, 10:24 AM',
      },
      {
        'surah': 'Al-Ikhlas',
        'ayahs': 'Ayahs 1–4',
        'score': 95,
        'date': 'Yesterday',
      },
      {
        'surah': 'Al-Falaq',
        'ayahs': 'Ayahs 1–5',
        'score': 91,
        'date': '2 days ago',
      },
    ];

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
          Text(
            'Recent Practice Sessions',
            style: pjs(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...sessions.map((s) {
            final int score = s['score'] as int;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$score',
                      style: pjs(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['surah'] as String,
                          style: pjs(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          s['ayahs'] as String,
                          style: pjs(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    s['date'] as String,
                    style: pjs(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard() {
    final badges = [
      {
        'title': 'First Recitation',
        'icon': Icons.star_rounded,
        'color': AppColors.gold,
        'unlocked': true,
      },
      {
        'title': '7-Day Streak',
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFF97316),
        'unlocked': true,
      },
      {
        'title': 'Tajweed Starter',
        'icon': Icons.school_rounded,
        'color': AppColors.tealStart,
        'unlocked': true,
      },
      {
        'title': 'Juz Amma Master',
        'icon': Icons.emoji_events_rounded,
        'color': AppColors.textMuted,
        'unlocked': false,
      },
    ];

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
                'Milestones & Badges',
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '3 / 4 Unlocked',
                style: pjs(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: badges.map((b) {
              final bool unlocked = b['unlocked'] as bool;
              final Color color = b['color'] as Color;
              return Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? color.withValues(alpha: 0.15)
                          : const Color(0xFFF5F1E6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unlocked ? color : const Color(0xFFE0DCD3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      b['icon'] as IconData,
                      color: unlocked ? color : AppColors.textMuted,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 68,
                    child: Text(
                      b['title'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: pjs(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: unlocked ? AppColors.textDark : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
