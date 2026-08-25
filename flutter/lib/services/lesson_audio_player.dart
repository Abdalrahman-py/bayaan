import 'package:audioplayers/audioplayers.dart';

import 'learn_content.dart';

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

  Future<void> preload(String promptAsset) async {
    if (_preloadedAsset == promptAsset) return;
    await _player.setSource(AssetSource(_path(promptAsset)));
    _preloadedAsset = promptAsset;
  }

  Future<void> play(String promptAsset) async {
    if (_preloadedAsset == promptAsset) {
      await _player.resume();
    } else {
      await _player.play(AssetSource(_path(promptAsset)));
      _preloadedAsset = promptAsset;
    }
  }

  String _path(String promptAsset) =>
      LearnContent.audioAssetPath(promptAsset).replaceFirst('assets/', '');

  void dispose() => _player.dispose();
}
