import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../models/models.dart';
import 'app_settings.dart';
import 'quran_text.dart';

/// Backend = the Ktor service on Render. Multipart contract: audio file +
/// sura/aya form fields + the learner's madd lengths, engine JSON passed
/// through unchanged so character offsets stay aligned to the engine's own
/// reference text.
String get kAnalyzeUrl => '$kBackendUrl/audio/analyze';

/// One active recording session — everything needed to tear it down cleanly.
class _ActiveRecording {
  final Stream<Uint8List> stream;
  final StreamSubscription<Uint8List> subscription;
  final BytesBuilder chunks;
  final Timer timer;
  int elapsedSec = 0;

  _ActiveRecording(this.stream, this.subscription, this.chunks, this.timer);
}

/// Ported from android RecitationViewModel: 16kHz mono PCM → WAV in memory,
/// multipart upload to /audio/analyze, response mapped to UI states.
class RecitationController extends ChangeNotifier {
  static const _sampleRate = 16000;

  final Map<String, RecitationUiState> _states = {};

  // The most recent recording, kept so the compare screen can play it back
  // against the qari. One slot only: the bytes are ~320KB for a ten-second
  // ayah and nothing needs an older take.
  String? _recordingKey;
  Uint8List? _recording;

  /// The user's last recording of this ayah, or null if they haven't recited
  /// it (or recited something else since).
  Uint8List? recordingFor(int sura, int aya) =>
      _recordingKey == '$sura:$aya' ? _recording : null;
  final Map<String, _ActiveRecording> _active = {};
  // Lazy: the platform recorder is only reachable once recording starts, so
  // constructing this controller stays safe on hosts without the plugin.
  AudioRecorder? _recorderOrNull;
  AudioRecorder get _recorder => _recorderOrNull ??= AudioRecorder();

  bool get isRecording => _active.isNotEmpty;

  RecitationUiState stateFor(int sura, int aya) => _states.putIfAbsent(
    '$sura:$aya',
    () => Ready(QuranText.verseFor(sura, aya)),
  );

  void _set(String key, RecitationUiState s) {
    _states[key] = s;
    notifyListeners();
  }

  Future<void> start(int sura, int aya) async {
    final key = '$sura:$aya';
    final verse = QuranText.verseFor(sura, aya);
    // One mic, one recording — the UI can't reach this state, but guard anyway.
    if (_active.isNotEmpty) return;

    try {
      // Flip to Recording(00:00) INSTANTLY — permission + mic startup take
      // a beat, and the button must respond on tap, not after setup.
      _set(key, Recording(verse, 0));
      if (!await _recorder.hasPermission()) {
        _set(
          key,
          ErrorState(
            verse,
            'Microphone permission is needed to record your recitation.',
          ),
        );
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      final chunks = BytesBuilder(copy: true);
      late final _ActiveRecording active;
      final subscription = stream.listen(
        chunks.add,
        onError: (Object e) {
          _teardown(key);
          _set(key, ErrorState(verse, "Recording failed. Try again."));
        },
      );
      // Ticking timer drives the visible count-up; cancelled in _teardown().
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final a = _active[key];
        if (a == null) return;
        a.elapsedSec++;
        _set(key, Recording(verse, a.elapsedSec));
      });
      active = _ActiveRecording(stream, subscription, chunks, timer);
      _active[key] = active;
    } catch (_) {
      _set(key, ErrorState(verse, "Couldn't start recording. Try again."));
    }
  }

  void _teardown(String key) {
    final a = _active.remove(key);
    if (a == null) return;
    a.timer.cancel();
    a.subscription.cancel();
  }

  /// Stops the mic FIRST so in-flight audio still lands in the stream while
  /// its subscription is alive, gives it a beat, then cancels the
  /// subscription. Wrong order (cancel first) silently drops the tail.
  Future<void> _closeMic(_ActiveRecording a) async {
    try {
      await _recorder.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 150));
    a.timer.cancel();
    await a.subscription.cancel();
  }

  /// Back-press / abandon: tear down and throw away the audio. Never uploads,
  /// never touches the network. Resets the verse state so re-opening the same
  /// verse doesn't surface a zombie "Recording" UI.
  Future<void> discard(int sura, int aya) async {
    final key = '$sura:$aya';
    final a = _active[key];
    if (a == null) return;
    await _closeMic(a);
    _active.remove(key);
    _set(key, Ready(QuranText.verseFor(sura, aya)));
  }

  Future<void> stop(int sura, int aya, String? token) async {
    final key = '$sura:$aya';
    final verse = QuranText.verseFor(sura, aya);
    final a = _active[key];
    if (a == null) return; // not recording — ignore double-taps
    await _closeMic(a);
    _active.remove(key);

    final pcm = a.chunks.takeBytes();
    if (pcm.isEmpty) {
      _set(key, ErrorState(verse, 'Recording was too short. Try again.'));
      return;
    }
    _set(key, Uploading(verse));
    final wav = buildWav(pcm);
    _recordingKey = key;
    _recording = wav;
    final result = await _analyze(wav, sura, aya, verse, token);
    _set(key, result);
  }

  Future<RecitationUiState> _analyze(
    Uint8List wav,
    int sura,
    int aya,
    Verse verse,
    String? token,
  ) async {
    if (token == null || token.isEmpty) {
      return ErrorState(verse, 'Please log in again.');
    }
    try {
      final req = http.MultipartRequest('POST', Uri.parse(kAnalyzeUrl))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['apikey'] = kAnonKey
        ..files.add(
          http.MultipartFile.fromBytes(
            'audio',
            wav,
            filename: 'recitation.wav',
          ),
        )
        ..fields['sura'] = '$sura'
        ..fields['aya'] = '$aya'
        // The learner's madd lengths. The edge function validates these and
        // forwards them to the engine; omitted or invalid, the engine falls
        // back to its own Hafs defaults.
        ..fields.addAll(AppSettings.instance.maddStyle.fields);
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      // The read needs its own timeout — a stalled edge function response
      // must not hang the spinner forever.
      final body = await streamed.stream.bytesToString().timeout(
        const Duration(seconds: 30),
      );
      return parseResponse(body, streamed.statusCode, verse);
    } on FormatException {
      return ErrorState(
        verse,
        'The recitation coach sent an unexpected response. Try again.',
      );
    } catch (_) {
      return ErrorState(
        verse,
        "Couldn't reach the coach. Check your connection and try again.",
      );
    }
  }

  /// Pure response→state mapping (static so it's unit-testable). Throws
  /// [FormatException] on contract violations so callers can distinguish a
  /// broken backend from a network failure.
  static RecitationUiState parseResponse(String text, int status, Verse verse) {
    if (status < 200 || status >= 300) {
      String? message;
      try {
        message = (jsonDecode(text) as Map)['message'] as String?;
      } catch (_) {}
      return ErrorState(
        verse,
        (message != null && message.isNotEmpty)
            ? message
            : "The recitation coach couldn't process that. Try again.",
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('unexpected payload');
    }
    final mistakes = (decoded['errors'] as List<dynamic>? ?? [])
        .map((e) => _toMistake(e as Map<String, dynamic>))
        .toList();
    final rawSifat = ((decoded['sifat_errors'] as List<dynamic>?) ?? [])
        .map((e) => _toSifat(e as Map<String, dynamic>))
        .toList();
    // Filter out padding / CTC blank artifacts so they never surface as phantom mistakes
    final sifat = rawSifat
        .where((s) => !const ['[pad]', '<pad>', 'pad', 'none', ''].contains(s.predicted.trim().toLowerCase()))
        .toList();
    // Every char offset in `errors` indexes the engine's OWN reference text, so
    // the screen must paint that exact string. Falling back to the bundled asset
    // text would silently shift every mark by whatever the two spellings differ
    // by, and mark letters the reciter got right. Without it, refuse the payload
    // rather than draw a plausible lie.
    final engineUthmani = decoded['uthmani'] as String?;
    if ((engineUthmani == null || engineUthmani.isEmpty) && mistakes.isNotEmpty) {
      throw const FormatException('missing uthmani');
    }
    final resolved = (engineUthmani != null && engineUthmani.isNotEmpty)
        ? verse.copyWith(uthmani: engineUthmani)
        : verse;
    final allCorrect = decoded['all_correct'];
    if (allCorrect is! bool) {
      throw const FormatException('missing all_correct');
    }
    return ResultState(resolved, mistakes, sifat, allCorrect && sifat.isEmpty);
  }

  static Mistake _toMistake(Map<String, dynamic> e) {
    final posList = (e['uthmani_pos'] as List<dynamic>? ?? const []);
    if (posList.length < 2 || posList.any((n) => n is! num)) {
      throw const FormatException('missing uthmani_pos');
    }
    final pos = posList.map((n) => (n as num).toInt()).toList();
    Map<String, dynamic>? rule;
    final rules = e['ref_tajweed_rules'] as List<dynamic>?;
    if (rules != null && rules.isNotEmpty) {
      final r0 = rules.first as Map<String, dynamic>;
      rule = r0['name'] as Map<String, dynamic>?;
    }
    final kind = e['speech_error_type'];
    if (kind is! String) {
      throw const FormatException('missing speech_error_type');
    }
    int? intOf(String k) => e[k] is num ? (e[k] as num).toInt() : null;
    return Mistake(
      charRange: CharRange(pos[0], pos[1]),
      isTajweed: e['error_type'] == 'tajweed',
      kind: kind,
      ruleNameEn: rule?['en'] as String?,
      ruleNameAr: rule?['ar'] as String?,
      expectedLen: intOf('expected_len'),
      gotLen: intOf('predicted_len'),
    );
  }

  static SifatError _toSifat(Map<String, dynamic> e) {
    final phonemes = e['phonemes_group'];
    final attribute = e['attribute'];
    final predicted = e['predicted'];
    final expected = e['expected'];
    if (phonemes is! String ||
        attribute is! String ||
        predicted is! String ||
        expected is! String) {
      throw const FormatException('malformed sifat_error');
    }
    return SifatError(
      phonemesGroup: phonemes,
      attribute: attribute,
      predicted: predicted,
      expected: expected,
      confidence: e['confidence'] is num
          ? (e['confidence'] as num).toDouble()
          : null,
    );
  }

  void retry(int sura, int aya) =>
      _set('$sura:$aya', Ready(QuranText.verseFor(sura, aya)));

  void nextAyah(int sura, int aya, void Function(int, int) onNavigate) {
    final count = QuranText.verseCount(sura);
    if (aya < count) {
      onNavigate(sura, aya + 1);
    } else if (sura < 114) {
      onNavigate(sura + 1, 1);
    } else {
      onNavigate(1, 1);
    }
  }

  /// 44-byte RIFF header + PCM, identical layout to the Kotlin buildWav().
  static Uint8List buildWav(Uint8List pcm) {
    final out = BytesBuilder();
    void le32(int v) => out.add([
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ]);
    void le16(int v) => out.add([v & 0xff, (v >> 8) & 0xff]);
    out.add(utf8.encode('RIFF'));
    le32(36 + pcm.length);
    out.add(utf8.encode('WAVE'));
    out.add(utf8.encode('fmt '));
    le32(16);
    le16(1); // PCM
    le16(1); // mono
    le32(_sampleRate);
    le32(_sampleRate * 2);
    le16(2);
    le16(16);
    out.add(utf8.encode('data'));
    le32(pcm.length);
    out.add(pcm);
    return out.toBytes();
  }

  @override
  void dispose() {
    for (final key in List.of(_active.keys)) {
      _teardown(key);
    }
    _recorderOrNull?.dispose();
    super.dispose();
  }
}
