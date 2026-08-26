import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/quiz/models/quiz_question.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuizQuestion.fromJson', () {
    test('parses a full question', () {
      final q = QuizQuestion.fromJson({
        'id': 'tajweed-1',
        'category': 'tajweed',
        'question': 'What is noon sakinah before ba?',
        'choices': ['Idhar', 'Iqlab', 'Ikhfa', 'Idgham'],
        'correctIndex': 1,
        'explanation': 'Iqlab is noon sakinah before ba.',
      });
      expect(q.id, 'tajweed-1');
      expect(q.category, QuizCategory.tajweed);
      expect(q.choices, hasLength(4));
      expect(q.correctIndex, 1);
      expect(q.explanation, isNotNull);
    });

    test('rejects invalid correctIndex', () {
      expect(
        () => QuizQuestion.fromJson({
          'id': 'x',
          'category': 'quranTrivia',
          'question': 'q',
          'choices': ['a', 'b'],
          'correctIndex': 5,
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown category', () {
      expect(
        () => QuizQuestion.fromJson({
          'id': 'x',
          'category': 'nope',
          'question': 'q',
          'choices': ['a', 'b'],
          'correctIndex': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('QuizQuestionBank', () {
    test('bundled bank loads and every question is valid', () async {
      final bank = await QuizQuestionBank.loadFromBundle();
      expect(bank.byCategory(QuizCategory.tajweed), isNotEmpty);
      expect(bank.byCategory(QuizCategory.quranTrivia), isNotEmpty);
      expect(bank.byCategory(QuizCategory.islamicTrivia), isNotEmpty);

      final ids = <String>{};
      for (final q in bank.all) {
        expect(ids.add(q.id), isTrue, reason: 'duplicate id ${q.id}');
        expect(q.choices.length, greaterThanOrEqualTo(2));
        expect(q.correctIndex, inInclusiveRange(0, q.choices.length - 1));
        expect(q.question, isNotEmpty);
      }
    });
  });
}
