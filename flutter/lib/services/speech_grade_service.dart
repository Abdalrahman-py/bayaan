import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'quran_text.dart';

class PhonemeIssue {
  final List<int> uthmaniPos;
  final String issueType;
  final String expectedPhoneme;
  final String predictedPhoneme;
  final String feedbackKey;

  const PhonemeIssue({
    required this.uthmaniPos,
    required this.issueType,
    required this.expectedPhoneme,
    required this.predictedPhoneme,
    required this.feedbackKey,
  });

  factory PhonemeIssue.fromJson(Map<String, dynamic> j) => PhonemeIssue(
    uthmaniPos: (j['uthmani_pos'] as List<dynamic>)
        .map((e) => e as int)
        .toList(),
    issueType: j['issue_type'] as String,
    expectedPhoneme: j['expected_phoneme'] as String,
    predictedPhoneme: j['predicted_phoneme'] as String,
    feedbackKey: j['feedback_key'] as String,
  );
}

class SpeechGradeResult {
  final String verdict; // pass | retry | fail
  final double score;
  final List<PhonemeIssue> phonemeIssues;

  const SpeechGradeResult({
    required this.verdict,
    required this.score,
    required this.phonemeIssues,
  });

  bool get passed => verdict == 'pass';

  factory SpeechGradeResult.fromJson(Map<String, dynamic> j) =>
      SpeechGradeResult(
        verdict: j['verdict'] as String,
        score: (j['score'] as num).toDouble(),
        phonemeIssues: (j['phoneme_issues'] as List<dynamic>? ?? [])
            .map((e) => PhonemeIssue.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Client for the `speech-grade` Edge Function — Tier 1/2 ECHO grading.
/// Contract: multipart {audio, tier, reference_text, item_ref} ->
/// {verdict, score, phoneme_issues[], item_ref}.
class SpeechGradeService {
  static Future<SpeechGradeResult> grade({
    required Uint8List wav,
    required int tier,
    required String referenceText,
    required String itemRef,
    required String token,
  }) async {
    final req =
        http.MultipartRequest(
            'POST',
            Uri.parse('$kBackendUrl/speech/grade'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['apikey'] = kAnonKey
          ..files.add(
            http.MultipartFile.fromBytes('audio', wav, filename: 'echo.wav'),
          )
          ..fields['tier'] = '$tier'
          ..fields['reference_text'] = referenceText
          ..fields['item_ref'] = itemRef;
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString().timeout(
      const Duration(seconds: 30),
    );
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('speech-grade ${streamed.statusCode}: $body');
    }
    return SpeechGradeResult.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
