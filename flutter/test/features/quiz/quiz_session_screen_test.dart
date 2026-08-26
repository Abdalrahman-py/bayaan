import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/quiz/models/quiz_question.dart';
import 'package:bayaan/features/quiz/quiz_session_screen.dart';

QuizQuestion q(String id, String text, int correct) => QuizQuestion(
  id: id,
  category: QuizCategory.tajweed,
  question: text,
  choices: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
  correctIndex: correct,
  explanation: 'Explanation for $id',
);

void main() {
  testWidgets('renders the question and four choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionScreen(
          questions: [q('1', 'What rule applies?', 2)],
          onComplete: (score, streak) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What rule applies?'), findsOneWidget);
    for (final c in ['Alpha', 'Beta', 'Gamma', 'Delta']) {
      expect(find.text(c), findsOneWidget);
    }
  });

  testWidgets('tapping the correct choice shows celebration and Continue button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionScreen(
          questions: [q('1', 'One?', 1)],
          onComplete: (score, streak) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Correct!'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('tapping wrong choice shows Try Again and Continue buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionScreen(
          questions: [q('1', 'One?', 0)],
          onComplete: (score, streak) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap wrong choice ('Beta', index 1 instead of index 0)
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not quite right'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap Try Again to reset selection
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('completing the last question fires onComplete with results', (
    tester,
  ) async {
    int? completedScore;
    int? completedStreak;
    final qs = [q('1', 'One?', 0), q('2', 'Two?', 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionScreen(
          questions: qs,
          onComplete: (score, streak) {
            completedScore = score;
            completedStreak = streak;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      final visible = qs.firstWhere(
        (x) => tester.any(find.text(x.question)),
      );
      final correctLabel = visible.choices[visible.correctIndex];
      await tester.ensureVisible(find.text(correctLabel));
      await tester.tap(find.text(correctLabel));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Finish'));
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(completedScore, 2);
    expect(completedStreak, 2);
  });
}

