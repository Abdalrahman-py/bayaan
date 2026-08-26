import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/auth_controller.dart';
import '../../services/lesson_audio_player.dart';
import '../../shared/widgets/ornamental_divider.dart';
import 'lesson_controller.dart';
import 'models/lesson.dart';

/// Plays one lesson end to end: teach card -> exercise items -> summary.
/// Owns its own LessonController so navigating back and re-entering the
/// lesson always starts fresh.
class LessonScreen extends StatefulWidget {
  final String lessonId;
  final AuthController auth;
  const LessonScreen({super.key, required this.lessonId, required this.auth});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _controller = LessonController();
  final _audio = LessonAudioPlayer();
  bool _navigatedToSummary = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.load(widget.lessonId);
  }

  void _onChange() {
    if (!mounted) return;
    if (_controller.phase == LessonPhase.summary && !_navigatedToSummary) {
      _navigatedToSummary = true;
      context
          .push(AppRoutes.lessonResultPath(widget.lessonId), extra: _controller)
          .then((_) {
        if (mounted && context.canPop()) {
          context.pop();
        }
      });
    }
    if (_controller.phase == LessonPhase.exercise) {
      final asset = _controller.currentItem.promptAsset;
      if (asset != null) _audio.preload(asset);
    }
    if (mounted) setState(() {});
  }

  Future<void> _play(String promptAsset) => _audio.play(promptAsset);

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    _audio.dispose();
    super.dispose();
  }

  String? _selectedOption;

  @override
  Widget build(BuildContext context) {
    final showFeedback = _controller.phase == LessonPhase.itemFeedback;
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            if (showFeedback) _buildDuolingoFeedbackBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final lesson = _controller.lesson;
    final total = lesson?.items.length ?? 0;
    final progress =
        (_controller.phase == LessonPhase.exercise ||
                _controller.phase == LessonPhase.recording ||
                _controller.phase == LessonPhase.grading ||
                _controller.phase == LessonPhase.itemFeedback) &&
            total > 0
        ? (_controller.itemIndex + 1) / total
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.learn),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 18, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFF5F1E6),
                valueColor: AlwaysStoppedAnimation(AppColors.tealStart),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.phase) {
      case LessonPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case LessonPhase.error:
        return Center(
          child: Text(
            _controller.errorMessage ?? 'Something went wrong.',
            style: pjs(fontSize: 14, color: AppColors.tajweedError),
          ),
        );
      case LessonPhase.teaching:
        return _buildTeach();
      case LessonPhase.exercise:
      case LessonPhase.itemFeedback:
        return SingleChildScrollView(child: _buildExercise());
      case LessonPhase.recording:
        return _buildRecording();
      case LessonPhase.grading:
        return const Center(child: CircularProgressIndicator());
      case LessonPhase.summary:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildTeach() {
    final teach = _controller.lesson!.teach!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _controller.lesson!.titleEn,
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          if (teach.glyphs.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: teach.glyphs
                  .map(
                    (g) => Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.gold),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        g,
                        textDirection: TextDirection.rtl,
                        style: arabic(fontSize: 32, color: AppColors.tealStart),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          const OrnamentalDivider(width: double.infinity, opacity: 0.3),
          const SizedBox(height: 16),
          Text(
            teach.narrationEn,
            textAlign: TextAlign.center,
            style: pjs(fontSize: 15, height: 1.6, color: AppColors.textDark),
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _controller.beginExercises,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealStart,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(
                'Begin Practice',
                style: pjs(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercise() {
    final item = _controller.currentItem;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            item.type.instruction,
            textAlign: TextAlign.center,
            style: pjs(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          if (item.promptTextAr != null) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                item.promptTextAr!,
                textDirection: TextDirection.rtl,
                style: arabic(fontSize: 56, color: AppColors.tealStart),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (item.promptAsset != null) ...[
            const SizedBox(height: 12),
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
                  child: Icon(
                    Icons.volume_up,
                    size: 36,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'TAP TO LISTEN',
                style: pjs(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (item.type == ExerciseType.echo ||
              item.type == ExerciseType.readAloudSyllable)
            _buildEchoPrompt(item)
          else
            _buildOptions(item),
        ],
      ),
    );
  }

  Widget _buildEchoPrompt(LessonItem item) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            item.referenceText ?? '',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: arabic(fontSize: 32, color: AppColors.tealStart),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _controller.startEcho(),
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tealStart,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'TAP TO REPEAT IT',
          style: pjs(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.tealStart,
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(LessonItem item) {
    final bool isFeedback = _controller.phase == LessonPhase.itemFeedback;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: item.options.map((opt) {
        final isAudio = opt.endsWith('.ogg');
        final bool isCorrect = opt == item.answer;
        final bool isPicked = opt == _selectedOption;

        Color? bg;
        Color? border;
        Color textColor = AppColors.tealStart;

        if (isFeedback) {
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

        return GestureDetector(
          onTap: isFeedback
              ? null
              : () {
                  setState(() => _selectedOption = opt);
                  if (isAudio) _play(opt);
                  _controller.answerChoice(opt);
                },
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg ?? Colors.white,
              border: Border.all(
                color: border ?? const Color(0xFFF5F1E6),
                width: border != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isAudio
                ? Icon(Icons.volume_up, color: textColor, size: 28)
                : Text(
                    opt,
                    textDirection: TextDirection.rtl,
                    style: arabic(fontSize: 30, color: textColor),
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecording() {
    final s = _controller.elapsedRecordingSec;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tajweedError,
            ),
            child: GestureDetector(
              onTap: () =>
                  _controller.stopEchoAndGrade(widget.auth.accessToken),
              child: const Icon(Icons.stop, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}',
            style: pjs(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.tealStart,
            ),
          ),
        ],
      ),
    );
  }

  /// Duolingo-style bottom banner matching QuizSessionScreen.
  Widget _buildDuolingoFeedbackBanner() {
    final correct = _controller.lastCorrect ?? false;
    final feedback = _controller.lastFeedback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
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
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              feedback,
              style: pjs(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textDark,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!correct) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedOption = null);
                      _controller.retryItem();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.tajweedError,
                      side: const BorderSide(color: AppColors.tajweedError),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Try Again',
                      style: pjs(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedOption = null);
                    _controller.next();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        correct ? AppColors.success : AppColors.tealStart,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
        ],
      ),
    );
  }
}
