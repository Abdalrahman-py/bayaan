import 'package:shared_preferences/shared_preferences.dart';

import 'reciter_audio.dart';

/// A set of madd (vowel-lengthening) durations, in harakāt — counts, never
/// seconds. The grading engine takes these four numbers and marks a madd
/// wrong when the recitation doesn't hold it for that many harakāt, so they
/// are the one knob that changes what counts as a mistake.
///
/// The engine's own defaults are [hafs]; sending nothing gets that. The other
/// two are the durations a reciter following Hafs may legitimately choose
/// between, not "strictness levels" — there is no strictness dial in the
/// engine, and pretending otherwise would mislabel a qirāʾah choice.
class MaddStyle {
  final String id;

  /// Shown on the settings toggle.
  final String name;

  /// Munfasil — the separated madd, two words.
  final int monfasel;

  /// Muttasil — the joined madd, one word.
  final int mottasel;

  /// Muttasil when stopping on it.
  final int mottaselWaqf;

  /// ʿĀriḍ lis-sukūn — the madd created by stopping.
  final int aared;

  const MaddStyle({
    required this.id,
    required this.name,
    required this.monfasel,
    required this.mottasel,
    required this.mottaselWaqf,
    required this.aared,
  });

  /// Matches the engine defaults in `ml/muaalem_modal.py`.
  static const hafs = MaddStyle(
    id: 'hafs',
    name: 'Standard',
    monfasel: 2,
    mottasel: 4,
    mottaselWaqf: 4,
    aared: 4,
  );
  static const qasr = MaddStyle(
    id: 'qasr',
    name: 'Short',
    monfasel: 2,
    mottasel: 4,
    mottaselWaqf: 4,
    aared: 2,
  );
  static const ishbaa = MaddStyle(
    id: 'ishbaa',
    name: 'Long',
    monfasel: 4,
    mottasel: 5,
    mottaselWaqf: 6,
    aared: 6,
  );

  static const all = [qasr, hafs, ishbaa];
  static const fallback = hafs;

  static MaddStyle byId(String? id) =>
      all.firstWhere((m) => m.id == id, orElse: () => fallback);

  /// The counts, as the summary line under the toggle: "2 · 4 · 4".
  String get summary => '$monfasel · $mottasel · $aared harakāt';

  /// Multipart fields for /audio-analyze, which forwards them to the engine.
  Map<String, String> get fields => {
    'madd_monfasel_len': '$monfasel',
    'madd_mottasel_len': '$mottasel',
    'madd_mottasel_waqf': '$mottaselWaqf',
    'madd_aared_len': '$aared',
  };
}

/// Every user preference the app actually honours, in one place.
///
/// Read synchronously off [instance] wherever a setting is needed — [load]
/// runs once before `runApp`, so a screen never has to wait for prefs. Writes
/// apply in memory immediately and persist in the background; nothing here
/// throws, because a settings store that is unavailable should cost the user
/// their preference, not the screen.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // Key kept from when the reciter lived in Reciter itself, so an existing
  // install doesn't lose its pick.
  static const _kReciter = 'reference_reciter';
  static const _kMadd = 'madd_style';
  static const _kAutoPlay = 'auto_play_reference';
  static const _kTranslation = 'show_translation';
  static const _kGoal = 'daily_goal_minutes';

  Reciter reciter = Reciter.fallback;
  MaddStyle maddStyle = MaddStyle.fallback;
  bool autoPlayReference = true;
  bool showTranslation = true;
  int dailyGoalMinutes = 10;

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Reads every setting, replacing whatever is in memory — an empty store
  /// resets to the defaults, which is what a test wants between cases.
  Future<void> load() async {
    final p = await _prefs();
    if (p == null) return;
    reciter = Reciter.byId(p.getString(_kReciter));
    maddStyle = MaddStyle.byId(p.getString(_kMadd));
    autoPlayReference = p.getBool(_kAutoPlay) ?? true;
    showTranslation = p.getBool(_kTranslation) ?? true;
    dailyGoalMinutes = p.getInt(_kGoal) ?? 10;
  }

  Future<void> setReciter(Reciter v) async {
    reciter = v;
    await (await _prefs())?.setString(_kReciter, v.id);
  }

  Future<void> setMaddStyle(MaddStyle v) async {
    maddStyle = v;
    await (await _prefs())?.setString(_kMadd, v.id);
  }

  Future<void> setAutoPlayReference(bool v) async {
    autoPlayReference = v;
    await (await _prefs())?.setBool(_kAutoPlay, v);
  }

  Future<void> setShowTranslation(bool v) async {
    showTranslation = v;
    await (await _prefs())?.setBool(_kTranslation, v);
  }

  Future<void> setDailyGoalMinutes(int v) async {
    dailyGoalMinutes = v;
    await (await _prefs())?.setInt(_kGoal, v);
  }
}
