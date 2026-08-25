import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models/quiz_question.dart';

/// One quiz run over a shuffled set of questions.
///
/// `answer` records the choice and immediately advances; the controller
/// notifies listeners after each transition. `isComplete` is true once every
/// question has been answered.
class QuizSessionController extends ChangeNotifier {
  final List<QuizQuestion> _questions;
  final List<int?> _selected = [];
  int _index = 0;
  int _score = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;

  QuizSessionController({
    required List<QuizQuestion> questions,
    int? seed,
  }) : _questions = List.of(questions) {
    final rng = math.Random(seed);
    _questions.shuffle(rng);
    _selected.addAll(List.filled(_questions.length, null));
  }

  QuizQuestion? get currentQuestion =>
      _index < _questions.length ? _questions[_index] : null;

  bool get isComplete => _index >= _questions.length;

  int get answeredCount => _index;

  int get score => _score;

  int get currentStreak => _currentStreak;

  int get bestStreak => _bestStreak;

  /// Which index was picked per question, in shuffled order (null = pending).
  List<int?> get selections => List.unmodifiable(_selected);

  /// True per question when the picked choice was correct.
  List<bool> get answeredCorrectly =>
      List.generate(_questions.length, (i) {
        final picked = _selected[i];
        return picked != null && picked == _questions[i].correctIndex;
      });

  /// Records [choiceIndex] for the current question and advances. No-op when
  /// the question was already answered or the session is complete.
  void answer(int choiceIndex) {
    if (isComplete) return;
    if (_selected[_index] != null) return;
    final q = _questions[_index];
    _selected[_index] = choiceIndex;
    if (choiceIndex == q.correctIndex) {
      _score++;
      _currentStreak++;
      if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;
    } else {
      _currentStreak = 0;
    }
    _index++;
    notifyListeners();
  }

  /// Starts a fresh run with the same (re-shuffled) question set.
  void restart() {
    _index = 0;
    _score = 0;
    _currentStreak = 0;
    _bestStreak = 0;
    _selected
      ..clear()
      ..addAll(List.filled(_questions.length, null));
    notifyListeners();
  }
}
