import 'package:audioplayers/audioplayers.dart';

import 'app_settings.dart';
import 'learn_content.dart';

/// `quran/{sura}_{aya}.ogg` prompts — the ayah-length items in units 7-8.
/// Nothing under assets/content/audio/quran/ was ever recorded, so those
/// prompts were silent taps. The id already carries sura and aya, so the
/// learner's chosen reciter can stream the real ayah instead, exactly as the
/// recitation screen does.
final _quranPrompt = RegExp(r'^quran/(\d+)_(\d+)\.ogg$');

Uri? reciterUrlForPrompt(String promptAsset) {
  final m = _quranPrompt.firstMatch(promptAsset);
  if (m == null) return null;
  return AppSettings.instance.reciter.urlFor(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
  );
}

/// Wraps AudioPlayer with a preload-then-resume pattern.
///
/// audioplayers' `play()` awaits an asset fetch before calling the browser's
/// play — on web that gap breaks the "must be a direct user gesture" autoplay
/// rule, so a freshly-tapped clip silently fails to play. Preloading the
/// source ahead of the tap (as soon as an item becomes current) means the tap
/// handler only needs `resume()`, which has no await before the platform
/// call, keeping it inside the gesture.
class LessonAudioPlayer {
  final _player = AudioPlayer();
  String? _preloadedAsset;

  Source _source(String promptAsset) {
    final url = reciterUrlForPrompt(promptAsset);
    return url != null
        ? UrlSource(url.toString())
        : AssetSource(_path(promptAsset));
  }

  Future<void> preload(String promptAsset) async {
    if (_preloadedAsset == promptAsset) return;
    await _player.setSource(_source(promptAsset));
    _preloadedAsset = promptAsset;
  }

  Future<void> play(String promptAsset) async {
    if (_preloadedAsset == promptAsset) {
      await _player.resume();
    } else {
      await _player.play(_source(promptAsset));
      _preloadedAsset = promptAsset;
    }
  }

  String _path(String promptAsset) =>
      LearnContent.audioAssetPath(promptAsset).replaceFirst('assets/', '');

  void dispose() => _player.dispose();
}
