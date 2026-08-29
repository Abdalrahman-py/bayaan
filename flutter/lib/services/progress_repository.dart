import 'dart:convert';

import 'package:http/http.dart' as http;

import 'quran_text.dart';

/// Client for the backend's /progress routes — GET summary and GET sessions.
/// Same auth pattern as [LearnRepository]: Bearer user JWT + anon apikey.
class ProgressRepository {
  static Uri _uri(String sub) => Uri.parse('$kBackendUrl/progress$sub');

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'apikey': kAnonKey,
    'Content-Type': 'application/json',
  };

  static Future<ProgressSummary> summary(String token) async {
    final res = await http
        .get(_uri(''), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    _checkOk(res);
    return ProgressSummary.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Newest first. `limit` is capped at 100 by the function.
  static Future<List<RecitationSession>> sessions(
    String token, {
    int limit = 100,
  }) async {
    final res = await http
        .get(_uri('/sessions?limit=$limit'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    _checkOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['sessions'] as List<dynamic>)
        .map((e) => RecitationSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('progress function ${res.statusCode}: ${res.body}');
    }
  }
}

class ProgressSummary {
  final int totalSessions;
  final int perfectSessions;

  /// Share of sessions recited with no mistake at all, 0..1.
  final double overallAccuracy;
  final int totalMistakes;

  /// Tajweed rule name (English) → times missed.
  final Map<String, int> mistakeBreakdown;

  /// Sifah name → times missed.
  final Map<String, int> sifatBreakdown;

  const ProgressSummary({
    required this.totalSessions,
    required this.perfectSessions,
    required this.overallAccuracy,
    required this.totalMistakes,
    required this.mistakeBreakdown,
    required this.sifatBreakdown,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> j) => ProgressSummary(
    totalSessions: (j['total_sessions'] as num?)?.toInt() ?? 0,
    perfectSessions: (j['perfect_sessions'] as num?)?.toInt() ?? 0,
    overallAccuracy: (j['overall_accuracy'] as num?)?.toDouble() ?? 0,
    totalMistakes: (j['total_mistakes'] as num?)?.toInt() ?? 0,
    mistakeBreakdown: _counts(j['mistake_breakdown']),
    sifatBreakdown: _counts(j['sifat_breakdown']),
  );

  static Map<String, int> _counts(dynamic raw) => {
    if (raw is Map<String, dynamic>)
      for (final e in raw.entries) e.key: (e.value as num).toInt(),
  };
}

class RecitationSession {
  final String sessionId;
  final int sura;
  final int aya;
  final bool allCorrect;
  final int mistakesCount;
  final DateTime createdAt;

  const RecitationSession({
    required this.sessionId,
    required this.sura,
    required this.aya,
    required this.allCorrect,
    required this.mistakesCount,
    required this.createdAt,
  });

  factory RecitationSession.fromJson(Map<String, dynamic> j) =>
      RecitationSession(
        sessionId: j['session_id'] as String,
        sura: (j['sura'] as num).toInt(),
        aya: (j['aya'] as num).toInt(),
        allCorrect: j['all_correct'] as bool? ?? false,
        mistakesCount: (j['mistakes_count'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
