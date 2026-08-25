import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../features/learn/models/lesson.dart';

/// Bundled curriculum content (assets/content/) — the same content pack the
/// backend's `learn` function and the content pipeline agree on. Loaded once,
/// cached in memory; never a network dependency.
class LearnContent {
  static List<CurriculumUnit>? _units;
  static final Map<String, LessonContent> _lessons = {};

  static Future<List<CurriculumUnit>> units() async {
    if (_units != null) return _units!;
    final raw = await rootBundle.loadString('assets/content/curriculum.json');
    final obj = jsonDecode(raw) as Map<String, dynamic>;
    _units = (obj['units'] as List<dynamic>)
        .map((e) => CurriculumUnit.fromJson(e as Map<String, dynamic>))
        .toList();
    return _units!;
  }

  static Future<LessonContent> lesson(String lessonId) async {
    final cached = _lessons[lessonId];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(
      'assets/content/lessons/$lessonId.json',
    );
    final content = LessonContent.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _lessons[lessonId] = content;
    return content;
  }

  /// Checkpoint lessons across all authored (non-stub) units — the item bank
  /// the placement test draws from (PRODUCTION_PLAN.md §4.0).
  static Future<List<LessonItem>> placementItemBank() async {
    final all = await units();
    final items = <LessonItem>[];
    for (final unit in all) {
      for (final meta in unit.lessons.where((l) => l.isCheckpoint)) {
        try {
          final content = await lesson(meta.lessonId);
          if (!content.stub) items.addAll(content.items);
        } catch (_) {
          // Unauthored/stub unit — skip, not a placement source yet.
        }
      }
    }
    return items;
  }

  static String audioAssetPath(String promptAsset) =>
      'assets/content/audio/$promptAsset';
}
