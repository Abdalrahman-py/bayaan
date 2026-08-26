import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import 'models/quiz_question.dart';

/// Quiz launcher: three category cards with question counts. [loader] is the
/// question-bank source (bundled asset by default; injected in tests).
class QuizHomeScreen extends StatefulWidget {
  final Future<QuizQuestionBank> Function() loader;

  /// Fired when a category card is tapped; the parent navigates to the
  /// session screen with [questions].
  final void Function(QuizCategory category, List<QuizQuestion> questions)?
      onStart;

  const QuizHomeScreen({
    super.key,
    this.loader = QuizQuestionBank.loadFromBundle,
    this.onStart,
  });

  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  late final Future<QuizQuestionBank> _bankFuture;

  @override
  void initState() {
    super.initState();
    _bankFuture = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<QuizQuestionBank>(
                future: _bankFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load questions.',
                        style: pjs(fontSize: 14, color: AppColors.textMuted),
                      ),
                    );
                  }
                  final bank = snapshot.data;
                  if (bank == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      for (final category in QuizCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCategoryCard(category, bank),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quizzes & Tests',
                  style: pjs(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Test your tajweed and Quran knowledge',
                  style: pjs(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(QuizCategory category, QuizQuestionBank bank) {
    final questions = bank.byCategory(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onStart == null
            ? null
            : () => widget.onStart!(category, questions),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold),
                ),
                child: Icon(
                  _iconFor(category),
                  size: 22,
                  color: AppColors.tealStart,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: pjs(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${questions.length} '
                      '${questions.length == 1 ? 'question' : 'questions'}',
                      style: pjs(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(QuizCategory category) => switch (category) {
    QuizCategory.tajweed => Icons.record_voice_over_rounded,
    QuizCategory.quranTrivia => Icons.menu_book_rounded,
    QuizCategory.islamicTrivia => Icons.mosque_rounded,
  };
}
