/// Content-pack models — mirrors content/schema/{curriculum,lesson}.schema.json.
/// Ported 1:1 from the JSON contract the `learn` Edge Function and the content
/// pipeline already agree on; see content/README.md.
library;

enum ExerciseType {
  listenPick,
  readPick,
  discriminate,
  oddOneOut,
  echo,
  readAloudSyllable;

  static ExerciseType fromJson(String s) => switch (s) {
    'LISTEN_PICK' => listenPick,
    'READ_PICK' => readPick,
    'DISCRIMINATE' => discriminate,
    'ODD_ONE_OUT' => oddOneOut,
    'ECHO' => echo,
    'READ_ALOUD_SYLLABLE' => readAloudSyllable,
    _ => throw FormatException('unknown exercise type: $s'),
  };

  /// The instruction line an exercise renders above its prompt/options — some
  /// item types (ODD_ONE_OUT) carry no prompt_asset/prompt_text_ar at all, so
  /// this is the only thing telling the learner what to do.
  String get instruction => switch (this) {
    listenPick => 'Tap the letter you hear',
    readPick => 'Tap the sound that matches',
    discriminate => 'Which one did you hear?',
    oddOneOut => "Which one doesn't belong?",
    echo || readAloudSyllable => 'Repeat what you hear',
  };
}

class LessonItem {
  final String itemRef;
  final ExerciseType type;
  final int gradingTier; // 0 = local match, 1/2 = speech-grade
  final String? promptAsset; // audio/letters/{file}.ogg, relative to content/
  final String? promptTextAr;
  final String? answer;
  final List<String> options;
  final String? referenceText; // ECHO/READ_ALOUD_SYLLABLE grading target

  const LessonItem({
    required this.itemRef,
    required this.type,
    required this.gradingTier,
    this.promptAsset,
    this.promptTextAr,
    this.answer,
    this.options = const [],
    this.referenceText,
  });

  factory LessonItem.fromJson(Map<String, dynamic> j) => LessonItem(
    itemRef: j['item_ref'] as String,
    type: ExerciseType.fromJson(j['type'] as String),
    gradingTier: j['grading_tier'] as int,
    promptAsset: j['prompt_asset'] as String?,
    promptTextAr: j['prompt_text_ar'] as String?,
    answer: j['answer'] as String?,
    options: (j['options'] as List<dynamic>?)?.cast<String>() ?? const [],
    referenceText: j['reference_text'] as String?,
  );
}

class TeachSegment {
  final String narrationEn;
  final List<String> glyphs;
  final String? focusEn;

  const TeachSegment({
    required this.narrationEn,
    this.glyphs = const [],
    this.focusEn,
  });

  factory TeachSegment.fromJson(Map<String, dynamic> j) => TeachSegment(
    narrationEn: j['narration_en'] as String,
    glyphs: (j['glyphs'] as List<dynamic>?)?.cast<String>() ?? const [],
    focusEn: j['focus_en'] as String?,
  );
}

class LessonContent {
  final String lessonId;
  final String unitId;
  final String titleEn;
  final String titleAr;
  final bool isCheckpoint;
  final bool stub;
  final TeachSegment? teach;
  final List<LessonItem> items;

  const LessonContent({
    required this.lessonId,
    required this.unitId,
    required this.titleEn,
    required this.titleAr,
    required this.isCheckpoint,
    required this.stub,
    this.teach,
    this.items = const [],
  });

  factory LessonContent.fromJson(Map<String, dynamic> j) => LessonContent(
    lessonId: j['lesson_id'] as String,
    unitId: j['unit_id'] as String,
    titleEn: j['title_en'] as String,
    titleAr: j['title_ar'] as String,
    isCheckpoint: j['is_checkpoint'] as bool? ?? false,
    stub: j['stub'] as bool? ?? false,
    teach: j['teach'] != null
        ? TeachSegment.fromJson(j['teach'] as Map<String, dynamic>)
        : null,
    items:
        (j['items'] as List<dynamic>?)
            ?.map((e) => LessonItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class CurriculumLessonMeta {
  final String lessonId;
  final String titleEn;
  final String titleAr;
  final bool isCheckpoint;

  const CurriculumLessonMeta({
    required this.lessonId,
    required this.titleEn,
    required this.titleAr,
    required this.isCheckpoint,
  });

  factory CurriculumLessonMeta.fromJson(Map<String, dynamic> j) =>
      CurriculumLessonMeta(
        lessonId: j['lesson_id'] as String,
        titleEn: j['title_en'] as String,
        titleAr: j['title_ar'] as String,
        isCheckpoint: j['is_checkpoint'] as bool? ?? false,
      );
}

class CurriculumUnit {
  final String unitId;
  final String track;
  final String titleEn;
  final String titleAr;
  final List<CurriculumLessonMeta> lessons;

  const CurriculumUnit({
    required this.unitId,
    required this.track,
    required this.titleEn,
    required this.titleAr,
    required this.lessons,
  });

  factory CurriculumUnit.fromJson(Map<String, dynamic> j) => CurriculumUnit(
    unitId: j['unit_id'] as String,
    track: j['track'] as String,
    titleEn: j['title_en'] as String,
    titleAr: j['title_ar'] as String,
    lessons: (j['lessons'] as List<dynamic>)
        .map((e) => CurriculumLessonMeta.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Per-user lesson state, as returned by GET /learn/path (not local content).
enum LessonStatus { locked, available, inProgress, completed }

class RoadmapLesson {
  final CurriculumLessonMeta meta;
  final LessonStatus status;
  final double bestScore;
  final int attempts;

  const RoadmapLesson({
    required this.meta,
    required this.status,
    required this.bestScore,
    required this.attempts,
  });

  factory RoadmapLesson.fromJson(Map<String, dynamic> j) => RoadmapLesson(
    meta: CurriculumLessonMeta(
      lessonId: j['lesson_id'] as String,
      titleEn: j['title_en'] as String,
      titleAr: j['title_ar'] as String,
      isCheckpoint: j['is_checkpoint'] as bool? ?? false,
    ),
    status: switch (j['status']) {
      'completed' => LessonStatus.completed,
      'in_progress' => LessonStatus.inProgress,
      'available' => LessonStatus.available,
      _ => LessonStatus.locked,
    },
    bestScore: (j['best_score'] as num?)?.toDouble() ?? 0,
    attempts: j['attempts'] as int? ?? 0,
  );
}

class RoadmapUnit {
  final String unitId;
  final String track;
  final String titleEn;
  final String titleAr;
  final List<RoadmapLesson> lessons;

  const RoadmapUnit({
    required this.unitId,
    required this.track,
    required this.titleEn,
    required this.titleAr,
    required this.lessons,
  });

  factory RoadmapUnit.fromJson(Map<String, dynamic> j) => RoadmapUnit(
    unitId: j['unit_id'] as String,
    track: j['track'] as String,
    titleEn: j['title_en'] as String,
    titleAr: j['title_ar'] as String,
    lessons: (j['lessons'] as List<dynamic>)
        .map((e) => RoadmapLesson.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class LearnHeader {
  final int arabicLevel;
  final int xp;
  final int streakCount;
  final int dailyGoalMinutes;
  final int reviewsDue;

  const LearnHeader({
    required this.arabicLevel,
    required this.xp,
    required this.streakCount,
    required this.dailyGoalMinutes,
    required this.reviewsDue,
  });

  factory LearnHeader.fromJson(Map<String, dynamic> j) => LearnHeader(
    arabicLevel: j['arabic_level'] as int? ?? 0,
    xp: j['xp'] as int? ?? 0,
    streakCount: j['streak_count'] as int? ?? 0,
    dailyGoalMinutes: j['daily_goal_minutes'] as int? ?? 10,
    reviewsDue: j['reviews_due'] as int? ?? 0,
  );
}

class LearnPath {
  final LearnHeader header;
  final List<RoadmapUnit> units;

  const LearnPath({required this.header, required this.units});

  factory LearnPath.fromJson(Map<String, dynamic> j) => LearnPath(
    header: LearnHeader.fromJson(j['header'] as Map<String, dynamic>),
    units: (j['units'] as List<dynamic>)
        .map((e) => RoadmapUnit.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
