import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../services/learn_content.dart';
import '../../services/learn_repository.dart';
import '../../services/lesson_audio_player.dart';
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
  bool? _lastCorrect;

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
    final correct = selected == item.answer;
    _results.add({'item_ref': item.itemRef, 'correct': correct});
    setState(() {
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
    });
    _preloadCurrent();
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final token = widget.auth.accessToken;
    try {
      if (token != null) {
        await LearnRepository.submitPlacement(token, _results);
      }
    } catch (_) {
      // Best-effort — the roadmap still works at the default level.
    }
    if (!mounted) return;
    context.go(AppRoutes.learn);
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: bank == null
            ? const Center(child: CircularProgressIndicator())
            : bank.isEmpty
            ? _buildSkip()
            : _submitting
            ? const Center(child: CircularProgressIndicator())
            : _buildItem(bank[_index]),
      ),
    );
  }

  Widget _buildSkip() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "No placement items yet — we'll start you from the beginning.",
            textAlign: TextAlign.center,
            style: pjs(fontSize: 15, color: AppColors.textMuted),
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

  Widget _buildItem(LessonItem item) {
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
              backgroundColor: const Color(0xFFF5F1E6),
              valueColor: AlwaysStoppedAnimation(AppColors.tealStart),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Arabic Placement',
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
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
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (item.promptTextAr != null)
            Center(
              child: Text(
                item.promptTextAr!,
                textDirection: TextDirection.rtl,
                style: arabic(fontSize: 56, color: AppColors.tealStart),
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
                    color: AppColors.tealStart.withOpacity(0.12),
                  ),
                  child: Icon(
                    Icons.volume_up,
                    size: 36,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
          if (_lastCorrect == null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: item.options.map((opt) {
                final isAudio = opt.endsWith('.ogg');
                return GestureDetector(
                  onTap: () => _answer(item, opt),
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFF5F1E6)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: isAudio
                        ? Icon(
                            Icons.volume_up,
                            color: AppColors.tealStart,
                            size: 28,
                          )
                        : Text(
                            opt,
                            textDirection: TextDirection.rtl,
                            style: arabic(
                              fontSize: 30,
                              color: AppColors.tealStart,
                            ),
                          ),
                  ),
                );
              }).toList(),
            )
          else ...[
            Center(
              child: Icon(
                _lastCorrect! ? Icons.check_circle : Icons.cancel,
                size: 48,
                color: _lastCorrect!
                    ? AppColors.success
                    : AppColors.tajweedError,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealStart,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: pjs(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
