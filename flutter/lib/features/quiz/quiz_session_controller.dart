import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models/quiz_question.dart';

/// One quiz run over a shuffled set of questions.
///
/// Supports interactive Duolingo-style step-by-step answering:
/// 1. `submitChoice(index)` records and scores the answer for the current question.
/// 2. `retryCurrent()` clears the current selection if the user wants to try again.
/// 3. `next()` advances to the next question.
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

  int get currentIndex => _index;

  int get answeredCount => _index;

  int get score => _score;

  int get currentStreak => _currentStreak;

  int get bestStreak => _bestStreak;

  int? get currentSelection =>
      _index < _selected.length ? _selected[_index] : null;

  bool get isCurrentAnswered => currentSelection != null;

  bool get isCurrentCorrect {
    final picked = currentSelection;
    final q = currentQuestion;
    return picked != null && q != null && picked == q.correctIndex;
  }

  /// Which index was picked per question, in shuffled order (null = pending).
  List<int?> get selections => List.unmodifiable(_selected);

  /// True per question when the picked choice was correct.
  List<bool> get answeredCorrectly =>
      List.generate(_questions.length, (i) {
        final picked = _selected[i];
        return picked != null && picked == _questions[i].correctIndex;
      });

  /// Submits [choiceIndex] for the current question without advancing yet.
  void submitChoice(int choiceIndex) {
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
    notifyListeners();
  }

  /// Retries the current question if it was wrong.
  void retryCurrent() {
    if (isComplete) return;
    if (_selected[_index] == null) return;
    _selected[_index] = null;
    notifyListeners();
  }

  /// Advances to the next question.
  void next() {
    if (isComplete) return;
    _index++;
    notifyListeners();
  }

  /// Records [choiceIndex] for the current question and immediately advances.
  void answer(int choiceIndex) {
    if (isComplete) return;
    if (_selected[_index] != null) return;
    submitChoice(choiceIndex);
    next();
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

