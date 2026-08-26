import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import 'models/quiz_question.dart';
import 'quiz_session_controller.dart';

/// One quiz run with Duolingo-style interactive feedback:
/// 1. Pick choice -> immediate feedback (correct celebration / wrong try-again).
/// 2. Explanation is presented.
/// 3. Tap "Continue" to proceed to next question.
class QuizSessionScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final void Function(int score, int bestStreak) onComplete;

  const QuizSessionScreen({
    super.key,
    required this.questions,
    required this.onComplete,
  });

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  late final QuizSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QuizSessionController(questions: widget.questions);
    _controller.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  void _choose(int index) {
    if (_controller.isCurrentAnswered) return;
    _controller.submitChoice(index);
  }

  void _next() {
    if (_controller.isComplete) {
      widget.onComplete(_controller.score, _controller.bestStreak);
      return;
    }
    _controller.next();
    if (_controller.isComplete) {
      widget.onComplete(_controller.score, _controller.bestStreak);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isComplete) return _buildFinishedView();
    final question = _controller.currentQuestion;
    if (question == null) return _buildFinishedView();

    final answered = _controller.isCurrentAnswered;
    final picked = _controller.currentSelection;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgressBar(),
                    const SizedBox(height: 20),
                    _buildQuestionCard(question),
                    const SizedBox(height: 20),
                    ...List.generate(question.choices.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildChoice(question, i, answered, picked),
                      );
                    }),
                  ],
                ),
              ),
            ),
            if (answered) _buildDuolingoFeedbackBanner(question),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedView() {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, size: 72, color: AppColors.gold),
              const SizedBox(height: 16),
              Text(
                'Quiz complete!',
                style: pjs(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_controller.score}/${widget.questions.length} correct · '
                'best streak ${_controller.bestStreak}',
                style: pjs(fontSize: 15, color: AppColors.textMuted),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      widget.onComplete(_controller.score, _controller.bestStreak),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealStart,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'Finish',
                    style: pjs(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                size: 20,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Quiz',
              style: pjs(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF5F1E6)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Score ${_controller.score} · Streak ${_controller.currentStreak}',
              style: pjs(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.tealStart,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = widget.questions.length;
    final done = _controller.currentIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? (done / total).clamp(0.0, 1.0) : 0,
            minHeight: 8,
            backgroundColor: const Color(0xFFF5F1E6),
            valueColor: const AlwaysStoppedAnimation(AppColors.tealStart),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Question ${done + 1} of $total',
          style: pjs(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(QuizQuestion question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        question.question,
        textAlign: TextAlign.center,
        style: pjs(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildChoice(QuizQuestion question, int index, bool answered, int? picked) {
    final bool isPicked = picked == index;
    final bool isCorrect = question.correctIndex == index;

    Color? bg;
    Color? border;
    Color? textColor = AppColors.textDark;
    IconData? icon;

    if (answered) {
      if (isCorrect) {
        bg = AppColors.success.withValues(alpha: 0.12);
        border = AppColors.success;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
      } else if (isPicked) {
        bg = AppColors.tajweedError.withValues(alpha: 0.12);
        border = AppColors.tajweedError;
        textColor = AppColors.tajweedError;
        icon = Icons.cancel_rounded;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: answered ? null : () => _choose(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg ?? Colors.white,
            border: Border.all(
              color: border ?? const Color(0xFFF5F1E6),
              width: border != null ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg ?? AppColors.lightBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: border ?? AppColors.gold),
                ),
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: pjs(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  question.choices[index],
                  style: pjs(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, size: 20, color: textColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Duolingo-style bottom banner with celebration / try-again and continue button.
  Widget _buildDuolingoFeedbackBanner(QuizQuestion question) {
    final bool correct = _controller.isCurrentCorrect;
    final String? explanation = question.explanation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xFFE8F5E9) // soft green
            : const Color(0xFFFFEBEE), // soft red
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
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
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
                    onPressed: () => _controller.retryCurrent(),
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
                  onPressed: _next,
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

