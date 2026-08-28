import 'package:bayaan/services/app_settings.dart';
import 'package:bayaan/services/reciter_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final settings = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  test('an empty store gives the documented defaults', () {
    expect(settings.reciter, Reciter.fallback);
    expect(settings.maddStyle, MaddStyle.hafs);
    expect(settings.autoPlayReference, isTrue);
    expect(settings.showTranslation, isTrue);
    expect(settings.dailyGoalMinutes, 10);
  });

  test('every setting survives a round trip through prefs', () async {
    await settings.setReciter(Reciter.abdulBasit);
    await settings.setMaddStyle(MaddStyle.ishbaa);
    await settings.setAutoPlayReference(false);
    await settings.setShowTranslation(false);
    await settings.setDailyGoalMinutes(30);

    await settings.load();

    expect(settings.reciter, Reciter.abdulBasit);
    expect(settings.maddStyle, MaddStyle.ishbaa);
    expect(settings.autoPlayReference, isFalse);
    expect(settings.showTranslation, isFalse);
    expect(settings.dailyGoalMinutes, 30);
  });

  test('a write is visible before it has been persisted', () {
    settings.setDailyGoalMinutes(5);
    expect(settings.dailyGoalMinutes, 5);
  });

  test('an unknown madd style falls back to the engine defaults', () {
    expect(MaddStyle.byId(null), MaddStyle.hafs);
    expect(MaddStyle.byId('nonsense'), MaddStyle.hafs);
    // Matches ml/muaalem_modal.py's own defaults, so sending them is a no-op.
    expect(MaddStyle.hafs.fields, {
      'madd_monfasel_len': '2',
      'madd_mottasel_len': '4',
      'madd_mottasel_waqf': '4',
      'madd_aared_len': '4',
    });
  });

  test('every madd style stays inside the range the backend accepts', () {
    for (final style in MaddStyle.all) {
      for (final value in style.fields.values) {
        expect(int.parse(value), inInclusiveRange(2, 6), reason: style.id);
      }
    }
    expect(MaddStyle.all.map((m) => m.id).toSet(), hasLength(MaddStyle.all.length));
  });
}
