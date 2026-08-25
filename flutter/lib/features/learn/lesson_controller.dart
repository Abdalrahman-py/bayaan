import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../services/learn_content.dart';
import '../../services/learn_repository.dart';
import '../../services/recitation_controller.dart' show RecitationController;
import '../../services/speech_grade_service.dart';
import 'models/lesson.dart';

enum LessonPhase {
  loading,
  teaching,
  exercise, // showing current item, awaiting input
  recording, // ECHO/READ_ALOUD_SYLLABLE mic capture
  grading, // uploaded, waiting on speech-grade
  itemFeedback, // correct/incorrect shown, "Next" enabled
  summary,
  error,
}

class _ItemOutcome {
  final String itemRef;
  final bool correct;
  final bool firstTry;
  const _ItemOutcome(this.itemRef, this.correct, this.firstTry);
}

/// Plays one lesson: teach segment -> items in order -> summary -> submit.
/// State-machine shape mirrors RecitationController (Ready/Recording/Uploading
/// there = exercise/recording/grading here) since it's the same
/// record-mic -> upload -> verdict loop for ECHO items.
class LessonController extends ChangeNotifier {
  static const _sampleRate = 16000;

  LessonContent? lesson;
  LessonPhase phase = LessonPhase.loading;
  String? errorMessage;

  int itemIndex = 0;
  bool? lastCorrect;
  String? lastFeedback;
  int elapsedRecordingSec = 0;

  final List<_ItemOutcome> _outcomes = [];
  final Set<String> _attempted = {}; // item_refs attempted at least once
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recSub;
  BytesBuilder? _recChunks;
  Timer? _recTimer;

  LessonItem get currentItem => lesson!.items[itemIndex];
  bool get isLastItem => itemIndex >= lesson!.items.length - 1;
  int get correctCount => _outcomes.where((o) => o.correct).length;

  Future<void> load(String lessonId) async {
    phase = LessonPhase.loading;
    notifyListeners();
    try {
      lesson = await LearnContent.lesson(lessonId);
      phase = LessonPhase.teaching;
    } catch (e) {
      errorMessage = "Couldn't load this lesson.";
      phase = LessonPhase.error;
    }
    notifyListeners();
  }

  void beginExercises() {
    if (lesson == null || lesson!.items.isEmpty) {
      phase = LessonPhase.summary;
    } else {
      itemIndex = 0;
      phase = LessonPhase.exercise;
    }
    notifyListeners();
  }

  /// Tier-0 items: local answer match, no network.
  void answerChoice(String selected) {
    final item = currentItem;
    final correct = selected == item.answer;
    _recordOutcome(item.itemRef, correct);
    lastCorrect = correct;
    lastFeedback = null;
    phase = LessonPhase.itemFeedback;
    notifyListeners();
  }

  Future<void> startEcho() async {
    phase = LessonPhase.recording;
    elapsedRecordingSec = 0;
    notifyListeners();
    try {
      if (!await _recorder.hasPermission()) {
        errorMessage = 'Microphone permission is needed.';
        phase = LessonPhase.error;
        notifyListeners();
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      _recChunks = BytesBuilder(copy: true);
      _recSub = stream.listen(_recChunks!.add);
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        elapsedRecordingSec++;
        notifyListeners();
      });
    } catch (_) {
      errorMessage = "Couldn't start recording.";
      phase = LessonPhase.error;
      notifyListeners();
    }
  }

  Future<void> stopEchoAndGrade(String? token) async {
    final item = currentItem;
    await _recorder.stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _recTimer?.cancel();
    await _recSub?.cancel();
    final pcm = _recChunks?.takeBytes() ?? Uint8List(0);
    _recChunks = null;

    if (pcm.isEmpty) {
      lastCorrect = false;
      lastFeedback = 'Recording was too short — try again.';
      phase = LessonPhase.itemFeedback;
      _recordOutcome(item.itemRef, false);
      notifyListeners();
      return;
    }
    if (token == null || token.isEmpty) {
      lastCorrect = false;
      lastFeedback = 'Please log in again.';
      phase = LessonPhase.itemFeedback;
      _recordOutcome(item.itemRef, false);
      notifyListeners();
      return;
    }

    phase = LessonPhase.grading;
    notifyListeners();
    try {
      final wav = RecitationController.buildWav(pcm);
      final result = await SpeechGradeService.grade(
        wav: wav,
        tier: item.gradingTier == 2 ? 2 : 1,
        referenceText: item.referenceText ?? '',
        itemRef: item.itemRef,
        token: token,
      );
      lastCorrect = result.passed;
      lastFeedback = result.passed
          ? null
          : (result.phonemeIssues.isNotEmpty
                ? result.phonemeIssues.first.feedbackKey.replaceAll('_', ' ')
                : 'Not quite — try again.');
      _recordOutcome(item.itemRef, result.passed);
    } catch (_) {
      lastCorrect = false;
      lastFeedback = "Couldn't reach the grading service.";
      _recordOutcome(item.itemRef, false);
    }
    phase = LessonPhase.itemFeedback;
    notifyListeners();
  }

  void retryItem() {
    phase = LessonPhase.exercise;
    notifyListeners();
  }

  void next() {
    if (isLastItem) {
      phase = LessonPhase.summary;
    } else {
      itemIndex++;
      phase = LessonPhase.exercise;
    }
    notifyListeners();
  }

  void _recordOutcome(String itemRef, bool correct) {
    final firstTry = !_attempted.contains(itemRef);
    _attempted.add(itemRef);
    // Keep only the latest outcome per item (retries overwrite, first-try flag preserved).
    _outcomes.removeWhere((o) => o.itemRef == itemRef);
    _outcomes.add(_ItemOutcome(itemRef, correct, firstTry));
  }

  Future<LearnHeader> submit(String token) async {
    final total = lesson!.items.length;
    final score = total == 0 ? 1.0 : correctCount / total;
    return LearnRepository.complete(
      token,
      lessonId: lesson!.lessonId,
      score: score,
      itemResults: _outcomes
          .map(
            (o) => {
              'item_ref': o.itemRef,
              'correct': o.correct,
              'first_try': o.firstTry,
            },
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _recSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
