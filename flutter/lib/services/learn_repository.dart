import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/learn/models/lesson.dart';
import 'quran_text.dart';

/// Client for the `learn` Edge Function — GET path, POST complete/placement,
/// GET/POST reviews. Same auth pattern as RecitationController's `_analyze`:
/// Bearer user JWT + the anon apikey header.
class LearnRepository {
  static Uri _uri(String sub) =>
      Uri.parse('$kSupabaseUrl/functions/v1/learn/$sub');

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'apikey': kAnonKey,
    'Content-Type': 'application/json',
  };

  static Future<LearnPath> path(String token) async {
    final res = await http
        .get(_uri('path'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    _checkOk(res);
    return LearnPath.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<LearnHeader> complete(
    String token, {
    required String lessonId,
    required double score,
    required List<Map<String, dynamic>> itemResults,
  }) async {
    final res = await http
        .post(
          _uri('complete'),
          headers: _headers(token),
          body: jsonEncode({
            'lesson_id': lessonId,
            'score': score,
            'item_results': itemResults,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _checkOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return LearnHeader.fromJson(body['header'] as Map<String, dynamic>);
  }

  static Future<int> submitPlacement(
    String token,
    List<Map<String, dynamic>> itemResults,
  ) async {
    final res = await http
        .post(
          _uri('placement'),
          headers: _headers(token),
          body: jsonEncode({'item_results': itemResults}),
        )
        .timeout(const Duration(seconds: 15));
    _checkOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['arabic_level'] as int;
  }

  static void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('learn function ${res.statusCode}: ${res.body}');
    }
  }
}
