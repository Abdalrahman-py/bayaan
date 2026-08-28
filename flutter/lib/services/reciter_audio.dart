import 'package:flutter/foundation.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reference reciter, and the everyayah.com folder holding their per-ayah
/// recordings. everyayah serves the whole Quran as one MP3 per ayah at a
/// predictable URL, with `Access-Control-Allow-Origin: *` and range requests,
/// so streaming works on web and mobile alike with no API key and no backend.
class Reciter {
  final String id;

  /// Full name, as shown in the settings dropdown.
  final String name;

  /// Short name for tight spots — the Listen button, the compare card.
  final String shortName;

  /// Folder under everyayah.com/data/.
  final String folder;

  const Reciter({
    required this.id,
    required this.name,
    required this.shortName,
    required this.folder,
  });

  /// The Mu'allim (teacher) recording is deliberately slow and articulated —
  /// the right default for a learner trying to copy what they hear.
  static const husary = Reciter(
    id: 'husary',
    name: 'Sheikh Mahmoud Khalil Al-Husary',
    shortName: 'Al-Husary',
    folder: 'Husary_Muallim_128kbps',
  );
  static const alafasy = Reciter(
    id: 'alafasy',
    name: 'Sheikh Mishary Rashid Alafasy',
    shortName: 'Mishary Alafasy',
    folder: 'Alafasy_128kbps',
  );
  static const abdulBasit = Reciter(
    id: 'abdul_basit',
    name: 'Sheikh Abdul Basit Abdul Samad',
    shortName: 'Abdul Basit',
    folder: 'Abdul_Basit_Mujawwad_128kbps',
  );

  static const all = [husary, alafasy, abdulBasit];
  static const fallback = husary;

  static Reciter byId(String? id) =>
      all.firstWhere((r) => r.id == id, orElse: () => fallback);

  /// everyayah pads sura and aya to three digits each: 2:255 → 002255.mp3.
  Uri urlFor(int sura, int aya) => Uri.parse(
    'https://everyayah.com/data/$folder/'
    '${sura.toString().padLeft(3, '0')}'
    '${aya.toString().padLeft(3, '0')}.mp3',
  );

  static const prefsKey = 'reference_reciter';

  /// Never throws: a screen asking which reciter to use should fall back to
  /// the default rather than fail to build if the prefs store is unavailable.
  static Future<Reciter> selected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return byId(prefs.getString(prefsKey));
    } catch (_) {
      return fallback;
    }
  }

  /// Returns whether the choice was persisted.
  static Future<bool> select(Reciter reciter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(prefsKey, reciter.id);
    } catch (_) {
      return false;
    }
  }
}

/// Streams one reciter's ayah recording.
///
/// Same preload-then-resume dance as [LessonAudioPlayer], for the same reason:
/// `play()` awaits the fetch before reaching the browser's play call, and that
/// await costs the user-gesture exemption, so a freshly-tapped clip silently
/// does nothing on web. Preloading when the ayah is known leaves the tap
/// handler with only `resume()`.
class ReciterPlayer {
  final AudioPlayer _player = AudioPlayer();
  String? _preloaded;

  Stream<void> get onComplete => _player.onPlayerComplete;
  Stream<Duration> get onPosition => _player.onPositionChanged;
  Stream<Duration> get onDuration => _player.onDurationChanged;

  Future<void> preload(Uri url) async {
    if (_preloaded == url.toString()) return;
    await _player.setSourceUrl(url.toString());
    _preloaded = url.toString();
  }

  Future<void> play(Uri url) async {
    if (_preloaded == url.toString()) {
      await _player.resume();
    } else {
      await _player.play(UrlSource(url.toString()));
      _preloaded = url.toString();
    }
  }

  /// Plays audio already in memory — the user's own recording, which is never
  /// uploaded anywhere it could be streamed back from.
  Future<void> playBytes(Uint8List bytes) async {
    await _player.play(BytesSource(bytes));
    _preloaded = null;
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    // stop() unloads the source on some platforms; force the next play to
    // re-set it rather than resuming a player with nothing loaded.
    _preloaded = null;
  }

  void dispose() => _player.dispose();
}
