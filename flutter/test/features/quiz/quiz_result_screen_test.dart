import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/quiz/quiz_result_screen.dart';

void main() {
  testWidgets('shows score, best streak and both actions', (tester) async {
    var playedAgain = false;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: QuizResultScreen(
          score: 8,
          total: 10,
          bestStreak: 5,
          onPlayAgain: () => playedAgain = true,
          onDone: () => done = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('80'), findsOneWidget); // ring shows percent
    expect(find.text('Best streak 5'), findsOneWidget);
    expect(find.text('Play Again'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Play Again'));
    expect(playedAgain, isTrue);

    await tester.tap(find.text('Done'));
    expect(done, isTrue);
  });
}
