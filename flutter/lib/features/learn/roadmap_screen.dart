import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../services/learn_content.dart';
import '../../services/learn_repository.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'models/lesson.dart';

/// The Arabic-track "Learn" roadmap — GET /learn/path, unit -> lesson list
/// with lock/complete state. Reachable from Home's "Learn Arabic" card.
class RoadmapScreen extends StatefulWidget {
  final AuthController auth;
  const RoadmapScreen({super.key, required this.auth});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  LearnPath? _path;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.auth.accessToken;
    if (token != null) {
      try {
        final path = await LearnRepository.path(token);
        if (mounted) {
          setState(() => _path = path);
          return;
        }
      } catch (_) {}
    }

    try {
      final units = await LearnContent.units();
      final roadmapUnits = units.map((u) {
        return RoadmapUnit(
          unitId: u.unitId,
          track: 'arabic',
          titleEn: u.titleEn,
          titleAr: u.titleAr,
          lessons: u.lessons.map((m) => RoadmapLesson(
            meta: m,
            status: LessonStatus.available,
            bestScore: 0,
            attempts: 0,
          )).toList(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _path = LearnPath(
            header: const LearnHeader(
              arabicLevel: 1,
              xp: 150,
              streakCount: 3,
              dailyGoalMinutes: 10,
              reviewsDue: 0,
            ),
            units: roadmapUnits,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't load your roadmap. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
                  Expanded(
                    child: Text(
                      'Learn Arabic',
                      style: pjs(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.placement),
                    child: Text(
                      'Placement Test',
                      style: pjs(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealStart,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_path != null) _buildHeaderCard(_path!.header),
            Expanded(child: _buildBody()),
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

  Widget _buildHeaderCard(LearnHeader h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tealStart,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat('Level', '${h.arabicLevel}'),
            _stat('XP', '${h.xp}'),
            _stat('Streak', '${h.streakCount}'),
            if (h.reviewsDue > 0) _stat('Reviews', '${h.reviewsDue}'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    children: [
      Text(
        value,
        style: pjs(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      Text(
        label,
        style: pjs(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
      ),
    ],
  );

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: pjs(fontSize: 14, color: AppColors.textMuted),
        ),
      );
    }
    if (_path == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [for (final unit in _path!.units) _buildUnit(unit)],
    );
  }

  Widget _buildUnit(RoadmapUnit unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unit.titleEn,
                  style: pjs(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                unit.titleAr,
                textDirection: TextDirection.rtl,
                style: arabic(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...unit.lessons.map(_buildLessonRow),
        ],
      ),
    );
  }

  Widget _buildLessonRow(RoadmapLesson l) {
    final locked = l.status == LessonStatus.locked;
    final completed = l.status == LessonStatus.completed;
    final color = completed
        ? AppColors.success
        : locked
        ? AppColors.textMuted
        : AppColors.tealStart;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(AppRoutes.lessonPath(l.meta.lessonId)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: locked ? const Color(0xFFF5F1E6) : Colors.white,
              border: Border.all(
                color: l.meta.isCheckpoint
                    ? AppColors.gold
                    : const Color(0xFFF5F1E6),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  completed
                      ? Icons.check_circle
                      : locked
                      ? Icons.lock_outline
                      : Icons.play_circle_outline,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.meta.titleEn,
                        style: pjs(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: locked
                              ? AppColors.textMuted
                              : AppColors.textDark,
                        ),
                      ),
                      if (l.meta.isCheckpoint)
                        Text(
                          'Checkpoint',
                          style: pjs(fontSize: 11, color: AppColors.gold),
                        ),
                    ],
                  ),
                ),
                Text(
                  l.meta.titleAr,
                  textDirection: TextDirection.rtl,
                  style: arabic(fontSize: 14, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
