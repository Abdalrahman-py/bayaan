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
);

void main() {
  testWidgets('renders the question and four choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionScreen(
          questions: [q('1', 'What rule applies?', 2)],
          onComplete: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What rule applies?'), findsOneWidget);
    for (final c in ['Alpha', 'Beta', 'Gamma', 'Delta']) {
      expect(find.text(c), findsOneWidget);
    }
  });

  testWidgets('tapping the correct choice shows the next button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionScreen(
          questions: [q('1', 'One?', 1), q('2', 'Two?', 0)],
          onComplete: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
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

    // The session shuffles questions; answer whichever is displayed correctly.
    for (var i = 0; i < 2; i++) {
      final visible = qs.firstWhere(
        (x) => tester.any(find.text(x.question)),
      );
      final correctLabel = visible.choices[visible.correctIndex];
      await tester.ensureVisible(find.text(correctLabel));
      await tester.tap(find.text(correctLabel));
      await tester.pumpAndSettle();
      if (i == 0) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }
    await tester.ensureVisible(find.text('Finish'));
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(completedScore, 2);
    expect(completedStreak, 2);
  });
}
