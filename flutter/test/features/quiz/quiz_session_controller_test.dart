import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/quiz/models/quiz_question.dart';
import 'package:bayaan/features/quiz/quiz_session_controller.dart';

QuizQuestion q(String id, int correctIndex) => QuizQuestion(
  id: id,
  category: QuizCategory.tajweed,
  question: 'Q $id',
  choices: const ['a', 'b'],
  correctIndex: correctIndex,
);

void main() {
  final questions = [q('1', 0), q('2', 1), q('3', 0)];

  group('QuizSessionController', () {
    test('starts at the first question with zero score and progress', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      expect(c.currentQuestion, isNotNull);
      expect(c.answeredCount, 0);
      expect(c.score, 0);
      expect(c.bestStreak, 0);
      expect(c.isComplete, isFalse);
    });

    test('a correct answer scores and advances to the next question', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      final first = c.currentQuestion!;
      final correctIndex = first.correctIndex;
      c.answer(correctIndex);
      expect(c.score, 1);
      expect(c.currentStreak, 1);
      expect(c.answeredCount, 1);
      expect(c.currentQuestion!.id, isNot(first.id));
    });

    test('a wrong answer keeps the score and resets the streak', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      final wrongIndex = 1 - c.currentQuestion!.correctIndex;
      c.answer(wrongIndex);
      expect(c.score, 0);
      expect(c.currentStreak, 0);
    });

    test('bestStreak tracks the longest run of correct answers', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      // Answer the first question wrong, every remaining question right.
      var first = true;
      while (!c.isComplete) {
        final q = c.currentQuestion!;
        c.answer(first ? 1 - q.correctIndex : q.correctIndex);
        first = false;
      }
      expect(c.bestStreak, questions.length - 1);
      expect(c.score, questions.length - 1);
    });

    test('completes after the last question and exposes results', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      while (!c.isComplete) {
        c.answer(c.currentQuestion!.correctIndex);
      }
      expect(c.isComplete, isTrue);
      expect(c.currentQuestion, isNull);
      expect(c.answeredCount, 3);
      expect(c.score, 3);
      expect(c.answeredCorrectly, everyElement(isTrue));
    });

    test('each answer call consumes exactly one question', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      c.answer(c.currentQuestion!.correctIndex);
      final second = c.currentQuestion!;
      c.answer(1 - second.correctIndex); // different question now
      expect(c.answeredCount, 2);
      expect(c.score, 1);
    });

    test('restart resets everything', () {
      final c = QuizSessionController(questions: questions, seed: 1);
      c.answer(c.currentQuestion!.correctIndex);
      c.restart();
      expect(c.answeredCount, 0);
      expect(c.score, 0);
      expect(c.currentStreak, 0);
      expect(c.bestStreak, 0);
      expect(c.isComplete, isFalse);
    });

    test('shuffle is deterministic per seed and covers every question', () {
      final a = QuizSessionController(questions: questions, seed: 42);
      final b = QuizSessionController(questions: questions, seed: 42);
      final c = QuizSessionController(questions: questions, seed: 7);
      String order(QuizSessionController x) {
        final ids = <String>[];
        while (!x.isComplete) {
          ids.add(x.currentQuestion!.id);
          x.answer(0);
        }
        return ids.join(',');
      }

      expect(order(a), order(b));
      expect(order(c), isNot(order(a)));
      expect(
        a.answeredCount,
        questions.length,
        reason: 'every question appears exactly once',
      );
    });
  });
}
