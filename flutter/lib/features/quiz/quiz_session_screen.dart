import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import 'models/quiz_question.dart';
import 'quiz_session_controller.dart';

/// One quiz run. [questions] is the (pre-filtered) set for the chosen
/// category; the screen shuffles and drives them via QuizSessionController.
/// When the last question is answered, [onComplete] fires with the score and
/// best streak so the parent can navigate.
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
  int? _picked;

  @override
  void initState() {
    super.initState();
    _controller = QuizSessionController(questions: widget.questions);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choose(int index) {
    if (_picked != null) return;
    setState(() => _picked = index);
    _controller.answer(index);
  }

  void _next() {
    if (_controller.isComplete) {
      widget.onComplete(_controller.score, _controller.bestStreak);
      return;
    }
    setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) {
    final question = _controller.currentQuestion;
    if (question == null) return _buildFinishedView();
    final answered = _picked != null;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgressBar(),
                    const SizedBox(height: 24),
                    _buildQuestionCard(question),
                    const SizedBox(height: 20),
                    ...List.generate(question.choices.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildChoice(question, i, answered),
                      );
                    }),
                    if (answered) ...[
                      const SizedBox(height: 4),
                      _buildExplanation(question),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tealStart,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          child: Text(
                            'Next',
                            style: pjs(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
              Icon(Icons.emoji_events_rounded, size: 64, color: AppColors.gold),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
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
                    style: pjs(fontSize: 15, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    final done = _controller.answeredCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: done / total,
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
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildChoice(QuizQuestion question, int index, bool answered) {
    final picked = _picked == index;
    final correct = question.correctIndex == index;

    Color? bg;
    Color? border;
    Color? textColor = AppColors.textDark;
    IconData? icon;
    if (answered) {
      if (correct) {
        bg = AppColors.success.withOpacity(0.12);
        border = AppColors.success;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
      } else if (picked) {
        bg = AppColors.tajweedError.withOpacity(0.12);
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
                    color: textColor ?? AppColors.tealStart,
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

  Widget _buildExplanation(QuizQuestion question) {
    final correct = _picked == question.correctIndex;
    final explanation = question.explanation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (correct ? AppColors.success : AppColors.tajweedError)
            .withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        explanation == null
            ? (correct ? 'Correct!' : 'Not quite — keep going.')
            : (correct ? 'Correct! ' : 'Not quite. ') + explanation,
        style: pjs(
          fontSize: 13,
          height: 1.4,
          color: correct ? AppColors.success : AppColors.tajweedError,
        ),
      ),
    );
  }
}
