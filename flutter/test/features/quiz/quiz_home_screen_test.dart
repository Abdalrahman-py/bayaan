import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/quiz/models/quiz_question.dart';
import 'package:bayaan/features/quiz/quiz_home_screen.dart';

QuizQuestion q(String id, QuizCategory c) => QuizQuestion(
  id: id,
  category: c,
  question: 'Q',
  choices: const ['a', 'b'],
  correctIndex: 0,
);

void main() {
  testWidgets('renders the three category cards with question counts', (
    tester,
  ) async {
    final bank = QuizQuestionBank([
      q('1', QuizCategory.tajweed),
      q('2', QuizCategory.tajweed),
      q('3', QuizCategory.quranTrivia),
      q('4', QuizCategory.islamicTrivia),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: QuizHomeScreen(loader: () async => bank),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tajweed Tests'), findsOneWidget);
    expect(find.text('Quran Trivia'), findsOneWidget);
    expect(find.text('Islamic Trivia'), findsOneWidget);
    expect(find.text('2 questions'), findsOneWidget);
    expect(find.text('1 question'), findsNWidgets(2));
  });

  testWidgets('tapping a category fires onStart with its questions', (
    tester,
  ) async {
    final bank = QuizQuestionBank([
      q('1', QuizCategory.tajweed),
      q('2', QuizCategory.quranTrivia),
    ]);
    QuizCategory? startedCategory;
    List<QuizQuestion>? startedQuestions;
    await tester.pumpWidget(
      MaterialApp(
        home: QuizHomeScreen(
          loader: () async => bank,
          onStart: (category, questions) {
            startedCategory = category;
            startedQuestions = questions;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quran Trivia'));
    expect(startedCategory, QuizCategory.quranTrivia);
    expect(startedQuestions, hasLength(1));
    expect(startedQuestions!.single.id, '2');
  });
}
