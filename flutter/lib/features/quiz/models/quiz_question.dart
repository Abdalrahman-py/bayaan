import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Quiz categories offered in the app.
enum QuizCategory {
  tajweed,
  quranTrivia,
  islamicTrivia;

  static QuizCategory fromName(String name) => switch (name) {
    'tajweed' => QuizCategory.tajweed,
    'quranTrivia' => QuizCategory.quranTrivia,
    'islamicTrivia' => QuizCategory.islamicTrivia,
    _ => throw FormatException('unknown quiz category: $name'),
  };

  String get title => switch (this) {
    QuizCategory.tajweed => 'Tajweed Tests',
    QuizCategory.quranTrivia => 'Quran Trivia',
    QuizCategory.islamicTrivia => 'Islamic Trivia',
  };
}

/// One multiple-choice quiz question.
class QuizQuestion {
  final String id;
  final QuizCategory category;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.choices,
    required this.correctIndex,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final choices = (json['choices'] as List<dynamic>).cast<String>();
    final correctIndex = json['correctIndex'] as int;
    if (correctIndex < 0 || correctIndex >= choices.length) {
      throw FormatException('correctIndex out of range for ${json['id']}');
    }
    return QuizQuestion(
      id: json['id'] as String,
      category: QuizCategory.fromName(json['category'] as String),
      question: json['question'] as String,
      choices: choices,
      correctIndex: correctIndex,
      explanation: json['explanation'] as String?,
    );
  }
}

/// The bundled question bank (assets/content/quiz/questions.json).
class QuizQuestionBank {
  final List<QuizQuestion> all;

  const QuizQuestionBank(this.all);

  factory QuizQuestionBank.fromJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final questions = (decoded['questions'] as List<dynamic>)
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    return QuizQuestionBank(questions);
  }

  static Future<QuizQuestionBank> loadFromBundle() async {
    final raw = await rootBundle.loadString('assets/content/quiz/questions.json');
    return QuizQuestionBank.fromJson(raw);
  }

  List<QuizQuestion> byCategory(QuizCategory category) =>
      all.where((q) => q.category == category).toList();
}
