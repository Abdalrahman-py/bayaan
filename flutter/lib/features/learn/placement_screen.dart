import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_palette.dart';
import '../../services/auth_controller.dart';
import '../../services/learn_content.dart';
import '../../services/learn_repository.dart';
import '../../services/lesson_audio_player.dart';
import '../../shared/widgets/arabic_tile.dart';
import '../../shared/widgets/ornamental_divider.dart';
import 'models/lesson.dart';

/// Adaptive placement test (PRODUCTION_PLAN.md §4.0): item bank drawn from
/// checkpoint lessons, ladder logic matches the `learn` function's own
/// handlePlacement (level 3 start, 2 misses -> down, 3 hits -> up, clamp 0-8)
/// so the client's displayed level matches what the server records.
/// ponytail: recognition-only (tier 0) for v1 — ECHO items need mic plumbing
/// that doesn't add much signal in a 12-item placement ladder; ADD if the
/// placement result proves too coarse.
class PlacementScreen extends StatefulWidget {
  final AuthController auth;
  const PlacementScreen({super.key, required this.auth});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  static const _maxItems = 12;

  List<LessonItem>? _bank;
  int _index = 0;
  int _level = 3;
  int _hits = 0;
  int _misses = 0;
  final List<Map<String, dynamic>> _results = [];
  final _audio = LessonAudioPlayer();
  bool _submitting = false;
  int? _resultLevel;
  String? _startUnitTitle;
  bool? _lastCorrect;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all =
        (await LearnContent.placementItemBank())
            .where((i) => i.gradingTier == 0 && i.options.length >= 2)
            .toList()
          ..shuffle(Random());
    if (!mounted) return;
    setState(() => _bank = all.take(_maxItems).toList());
    _preloadCurrent();
  }

  void _preloadCurrent() {
    final asset = _bank?[_index].promptAsset;
    if (asset != null) _audio.preload(asset);
  }

  Future<void> _play(String promptAsset) => _audio.play(promptAsset);

  void _answer(LessonItem item, String selected) {
    if (_lastCorrect != null) return;
    final correct = selected == item.answer;
    _results.add({'item_ref': item.itemRef, 'correct': correct});
    setState(() {
      _selectedOption = selected;
      _lastCorrect = correct;
      if (correct) {
        _hits++;
        _misses = 0;
        if (_hits == 3) {
          _level = min(8, _level + 1);
          _hits = 0;
        }
      } else {
        _misses++;
        _hits = 0;
        if (_misses == 2) {
          _level = max(0, _level - 1);
          _misses = 0;
        }
      }
    });
  }

  Future<void> _next() async {
    if (_index + 1 >= (_bank?.length ?? 0)) {
      await _finish();
      return;
    }
    setState(() {
      _index++;
      _lastCorrect = null;
      _selectedOption = null;
    });
    _preloadCurrent();
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final token = widget.auth.accessToken;
    int? level;
    try {
      if (token != null) {
        // The server runs the same ladder over the same answers, so its level
        // is the one that counts — _level is only what drove item selection.
        level = await LearnRepository.submitPlacement(token, _results);
      }
    } catch (_) {
      // Best-effort — the roadmap still works at the default level.
    }
    if (!mounted) return;
    if (level == null) {
      context.go(AppRoutes.learn);
      return;
    }
    // Level N means units 1..N are known, so the learner starts at N+1.
    final units = (await LearnContent.units())
        .where((u) => u.track == 'arabic')
        .toList();
    if (!mounted) return;
    final placed = level;
    setState(() {
      _resultLevel = placed;
      _startUnitTitle = placed < units.length ? units[placed].titleEn : null;
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: _resultLevel != null
            ? _buildResult(_resultLevel!, palette)
            : _submitting
            ? const Center(child: CircularProgressIndicator())
            : _bank == null
            ? const Center(child: CircularProgressIndicator())
            : _bank!.isEmpty
            ? _buildSkip(palette)
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildItem(_bank![_index], palette),
                    ),
                  ),
                  if (_lastCorrect != null) _buildDuolingoFeedbackBanner(palette),
                ],
              ),
      ),
    );
  }

  Widget _buildResult(int level, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Level $level',
            style: pjs(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.tealStart,
            ),
          ),
          const SizedBox(height: 8),
          const OrnamentalDivider(width: 160, opacity: 0.3),
          const SizedBox(height: 16),
          Text(
            _startUnitTitle != null
                ? "You'll start at \u201c$_startUnitTitle\u201d. Everything before it "
                      'is unlocked if you want to go back over it.'
                : "You've unlocked the whole Arabic track.",
            textAlign: TextAlign.center,
            style: pjs(fontSize: 15, color: palette.textMuted),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.learn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealStart,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(
                'See my roadmap',
                style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkip(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "No placement items yet — we'll start you from the beginning.",
            textAlign: TextAlign.center,
            style: pjs(fontSize: 15, color: palette.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.learn),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealStart,
            ),
            child: Text('Start Learning', style: pjs(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(LessonItem item, AppPalette palette) {
    final bool answered = _lastCorrect != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_index + 1) / _bank!.length,
              minHeight: 8,
              backgroundColor: palette.isDark
                  ? palette.cardBg
                  : const Color(0xFFF5F1E6),
              valueColor: const AlwaysStoppedAnimation(AppColors.tealStart),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Arabic Placement',
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const OrnamentalDivider(width: 160, opacity: 0.3),
          const SizedBox(height: 24),
          Text(
            item.type.instruction,
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (item.promptTextAr != null)
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.promptTextAr!,
                  textDirection: TextDirection.rtl,
                  style: arabic(fontSize: 56, color: AppColors.tealStart),
                ),
              ),
            ),
          if (item.promptAsset != null)
            Center(
              child: GestureDetector(
                onTap: () => _play(item.promptAsset!),
                child: Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.tealStart.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    size: 36,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: item.options.map((opt) {
              final isAudio = opt.endsWith('.ogg');
              final bool isCorrect = opt == item.answer;
              final bool isPicked = opt == _selectedOption;

              Color? bg = palette.cardBg;
              Color? border;
              Color textColor = AppColors.tealStart;

              if (answered) {
                if (isCorrect) {
                  bg = AppColors.success.withValues(alpha: 0.12);
                  border = AppColors.success;
                  textColor = AppColors.success;
                } else if (isPicked) {
                  bg = AppColors.tajweedError.withValues(alpha: 0.12);
                  border = AppColors.tajweedError;
                  textColor = AppColors.tajweedError;
                }
              }

              return ArabicTile(
                text: opt,
                icon: isAudio ? Icons.volume_up : null,
                textColor: textColor,
                background: bg,
                borderColor: border ?? palette.borderColor,
                borderWidth: border != null ? 2 : 1,
                onTap: answered
                    ? null
                    : () {
                        if (isAudio) _play(opt);
                        _answer(item, opt);
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Duolingo-style bottom banner matching QuizSessionScreen.
  Widget _buildDuolingoFeedbackBanner(AppPalette palette) {
    final bool correct = _lastCorrect ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: palette.isDark
            ? (correct ? const Color(0xFF142E25) : const Color(0xFF331B21))
            : (correct ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE)),
        border: Border(
          top: BorderSide(
            color: correct ? AppColors.success : AppColors.tajweedError,
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: correct ? AppColors.success : AppColors.tajweedError,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? 'MashaAllah! Correct!' : 'Not quite right',
                  style: pjs(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: correct ? AppColors.success : AppColors.tajweedError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    correct ? AppColors.success : AppColors.tealStart,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(
                'Continue',
                style: pjs(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
