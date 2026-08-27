import 'dart:convert';

import 'package:bayaan/services/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the progress function summary payload', () {
    // Shape produced by supabase/functions/progress -> progress_summary RPC.
    final json = jsonDecode('''
      {"total_sessions": 12, "perfect_sessions": 9, "overall_accuracy": 0.75,
       "total_mistakes": 5, "mistake_breakdown": {"Ghunnah": 3, "Qalqalah": 2},
       "sifat_breakdown": {}}
    ''') as Map<String, dynamic>;

    final s = ProgressSummary.fromJson(json);
    expect(s.totalSessions, 12);
    expect(s.perfectSessions, 9);
    expect(s.overallAccuracy, 0.75);
    expect(s.totalMistakes, 5);
    expect(s.mistakeBreakdown, {'Ghunnah': 3, 'Qalqalah': 2});
    expect(s.sifatBreakdown, isEmpty);
  });

  test('an empty account parses as all zeros, not nulls', () {
    final s = ProgressSummary.fromJson(
      jsonDecode('''
        {"total_sessions": 0, "perfect_sessions": 0, "overall_accuracy": 0,
         "total_mistakes": 0, "mistake_breakdown": {}, "sifat_breakdown": {}}
      ''') as Map<String, dynamic>,
    );
    expect(s.totalSessions, 0);
    expect(s.overallAccuracy, 0.0);
    expect(s.mistakeBreakdown, isEmpty);
  });

  test('parses a session row and localises created_at', () {
    final s = RecitationSession.fromJson(
      jsonDecode('''
        {"session_id": "9d1e6b7a-0000-4000-8000-000000000001", "sura": 112,
         "aya": 3, "all_correct": false, "mistakes_count": 2,
         "created_at": "2026-08-20T10:24:00+00:00"}
      ''') as Map<String, dynamic>,
    );
    expect(s.sura, 112);
    expect(s.aya, 3);
    expect(s.allCorrect, isFalse);
    expect(s.mistakesCount, 2);
    expect(s.createdAt.isUtc, isFalse);
    expect(
      s.createdAt.toUtc(),
      DateTime.utc(2026, 8, 20, 10, 24),
    );
  });
}
