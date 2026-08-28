import 'package:bayaan/core/theme/app_fonts.dart';
import 'package:bayaan/features/learn/lesson_controller.dart';
import 'package:bayaan/services/app_settings.dart';
import 'package:bayaan/services/lesson_audio_player.dart';
import 'package:bayaan/services/reciter_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a missed item', () {
    // ar.1.1 is the first authored lesson; its items are answered locally, so
    // the controller needs no network here.
    late LessonController c;

    setUp(() async {
      c = LessonController();
      await c.load('ar.1.1');
      c.beginExercises();
    });

    tearDown(() => c.dispose());

    test('does not open the way forward until it is earned', () {
      final wrong = c.currentItem.options.firstWhere(
        (o) => o != c.currentItem.answer,
      );
      c.answerChoice(wrong);

      expect(c.lastCorrect, isFalse);
      expect(c.answerRevealed, isFalse, reason: 'the answer must stay hidden');
      expect(c.canAdvance, isFalse, reason: 'one miss is not a way past');

      // A second miss unblocks Continue so nobody gets stuck on one item.
      c.retryItem();
      c.answerChoice(wrong);
      expect(c.attempts, 2);
      expect(c.canAdvance, isTrue);
      expect(c.answerRevealed, isFalse);
    });

    test('asking to see it reveals and unblocks immediately', () {
      c.answerChoice(
        c.currentItem.options.firstWhere((o) => o != c.currentItem.answer),
      );
      c.revealAnswer();
      expect(c.answerRevealed, isTrue);
      expect(c.canAdvance, isTrue);
    });

    test('a hint strikes out a wrong option, never the answer', () {
      final item = c.currentItem;
      c.requestHint();
      expect(c.eliminated, hasLength(1));
      expect(c.eliminated.contains(item.answer), isFalse);
    });

    test('moving on clears the hint state', () {
      c.requestHint();
      c.answerChoice(c.currentItem.answer!);
      c.next();
      expect(c.eliminated, isEmpty);
      expect(c.attempts, 0);
      expect(c.answerRevealed, isFalse);
      expect(c.lastCorrect, isNull);
    });
  });

  test('ayah prompts stream from the chosen reciter, letters stay local',
      () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();

    // assets/content/audio/quran/ was never populated, so these 31 prompts
    // were silent taps before they were routed to everyayah.
    expect(
      reciterUrlForPrompt('quran/113_1.ogg').toString(),
      Reciter.fallback.urlFor(113, 1).toString(),
    );
    expect(reciterUrlForPrompt('letters/alif.ogg'), isNull);
    expect(reciterUrlForPrompt('words/allah.ogg'), isNull);
  });

  test('Arabic runs in an English sentence are isolated for bidi', () {
    // The teach narration mixes the two; without isolates the trailing comma
    // and the phrase order jump sides.
    final out = bidi('قَمَر keeps its ل, شَمس swallows it.');
    expect(out, contains('\u2068قَمَر\u2069'));
    expect(out, contains('\u2068ل\u2069'));
    expect(
      out.replaceAll(RegExp('[\u2068\u2069]'), ''),
      'قَمَر keeps its ل, شَمس swallows it.',
    );
  });
}
