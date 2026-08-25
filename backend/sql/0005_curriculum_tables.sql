-- Edge Functions migration — curriculum moves from a hand-copied JSON file
-- (backend/src/main/resources/curriculum.json, content/curriculum.json) into
-- the DB, closing the hand-copy debt noted in Curriculum.kt for good instead of
-- just relocating it into the Edge Function bundle.
--
-- `position` encodes both the unit order and, within a unit, the lesson order —
-- the /learn/path gating logic (a lesson unlocks once the immediately-preceding
-- lesson, across the WHOLE curriculum, is completed) depends on this global
-- order exactly like the old array-order JSON did.

create table if not exists curriculum_units (
  unit_id    text primary key,
  track      text not null,
  title_en   text not null,
  title_ar   text not null,
  position   int  not null
);

create table if not exists curriculum_lessons (
  lesson_id     text primary key,
  unit_id       text not null references curriculum_units(unit_id) on delete cascade,
  title_en      text not null,
  title_ar      text not null,
  is_checkpoint boolean not null default false,
  position      int not null
);

create index if not exists idx_curriculum_lessons_unit on curriculum_lessons(unit_id, position);

-- RLS: same posture as the learn_* tables (0001) — content is read by the
-- `learn` Edge Function via service-role, never directly by a client.
alter table curriculum_units   enable row level security;
alter table curriculum_lessons enable row level security;

-- Seed data, ported 1:1 from content/curriculum.json (version 1).
insert into curriculum_units (unit_id, track, title_en, title_ar, position) values
  ('ar.1', 'arabic',  'The Letters',              'الحروف',                    1),
  ('ar.2', 'arabic',  'Hearing the difference',   'تمييز الأصوات',              2),
  ('ar.3', 'arabic',  'Short vowels',              'الحركات',                    3),
  ('ar.4', 'arabic',  'Letters join up',           'اتصال الحروف',               4),
  ('ar.5', 'arabic',  'Sukoon, shadda, tanween',   'السكون والشدة والتنوين',      5),
  ('ar.6', 'arabic',  'Long vowels',                'حروف المد',                  6),
  ('ar.7', 'arabic',  'Reading real words',         'قراءة الكلمات',              7),
  ('ar.8', 'arabic',  'First ayat',                 'أول الآيات',                 8),
  ('tj.ghunnah',  'tajweed', 'Ghunnah',   'الغُنّة',   9),
  ('tj.qalqalah', 'tajweed', 'Qalqalah',  'القَلقَلة', 10),
  ('tj.madd',     'tajweed', 'Madd',      'المَدّ',    11)
on conflict (unit_id) do nothing;

insert into curriculum_lessons (lesson_id, unit_id, title_en, title_ar, is_checkpoint, position) values
  ('ar.1.1', 'ar.1', 'Dotted family',              'ب ت ث ن ي',           false, 1),
  ('ar.1.2', 'ar.1', 'Throat letters',              'ج ح خ',               false, 2),
  ('ar.1.3', 'ar.1', 'Non-connectors',              'د ذ ر ز و',           false, 3),
  ('ar.1.4', 'ar.1', 'Whistling & heavy',           'س ش ص ض',             false, 4),
  ('ar.1.5', 'ar.1', 'Deep-throat & heavy',         'ط ظ ع غ ف ق',         false, 5),
  ('ar.1.6', 'ar.1', 'Hamza & checkpoint',          'ك ل م هـ ء أ',        true,  6),

  ('ar.2.1', 'ar.2', 'ه / ح / خ',                    'ه ح خ',               false, 1),
  ('ar.2.2', 'ar.2', 'س/ص، ت/ط، د/ض',                'س ص ت ط د ض',         false, 2),
  ('ar.2.3', 'ar.2', 'ذ/ظ/ز، ث/س',                    'ذ ظ ز ث س',           false, 3),
  ('ar.2.4', 'ar.2', 'ك/ق، أ/ع',                      'ك q أ ع',             false, 4),
  ('ar.2.5', 'ar.2', 'Mixed gauntlet & checkpoint',   'مراجعة',              true,  5),

  ('ar.3.1', 'ar.3', 'Fatha',                        'الفتحة',              false, 1),
  ('ar.3.2', 'ar.3', 'Kasra',                        'الكسرة',              false, 2),
  ('ar.3.3', 'ar.3', 'Damma',                        'الضمة',               false, 3),
  ('ar.3.4', 'ar.3', 'Mixed CV drills',              'تدريبات مختلطة',       false, 4),
  ('ar.3.5', 'ar.3', 'Two-syllable chains',          'مقاطع مزدوجة',         false, 5),
  ('ar.3.6', 'ar.3', 'Checkpoint: read aloud',       'اختبار القراءة',       true,  6),

  ('ar.4.1', 'ar.4', 'Letter forms',                 'أشكال الحروف',        false, 1),
  ('ar.4.2', 'ar.4', 'Two-letter joins',             'وصل حرفين',           false, 2),
  ('ar.4.3', 'ar.4', 'Three-letter words',           'كلمات ثلاثية',        false, 3),
  ('ar.4.4', 'ar.4', 'Non-connectors in words',      'الحروف المنفصلة',      false, 4),
  ('ar.4.5', 'ar.4', 'Checkpoint: joined reading',   'اختبار الوصل',        true,  5),

  ('ar.5.1', 'ar.5', 'Sukoon',                       'السكون',              false, 1),
  ('ar.5.2', 'ar.5', 'Shadda',                       'الشدة',               false, 2),
  ('ar.5.3', 'ar.5', 'Tanween',                      'التنوين',             false, 3),
  ('ar.5.4', 'ar.5', 'Checkpoint: vowelled words',   'اختبار الكلمات',       true,  4),

  ('ar.6.1', 'ar.6', 'Alif madd',                    'مد الألف',            false, 1),
  ('ar.6.2', 'ar.6', 'Ya & Waw madd',                'مد الياء والواو',      false, 2),
  ('ar.6.3', 'ar.6', 'Long vs short',                'الطويل والقصير',       false, 3),
  ('ar.6.4', 'ar.6', 'Checkpoint: rhythm',           'اختبار الإيقاع',       true,  4),

  ('ar.7.1', 'ar.7', 'Sacred words',                 'كلمات مباركة',        false, 1),
  ('ar.7.2', 'ar.7', 'The article al-',              'أل التعريف',          false, 2),
  ('ar.7.3', 'ar.7', 'Special endings',              'نهايات خاصة',         false, 3),
  ('ar.7.4', 'ar.7', 'Hamzat al-wasl',               'همزة الوصل',          false, 4),
  ('ar.7.5', 'ar.7', 'Uthmani script',               'الرسم العثماني',       false, 5),
  ('ar.7.6', 'ar.7', 'Checkpoint: real words',       'اختبار الكلمات',       true,  6),

  ('ar.8.1', 'ar.8', 'Al-Ikhlas',                    'الإخلاص',             false, 1),
  ('ar.8.2', 'ar.8', 'Al-Kawthar',                   'الكوثر',              false, 2),
  ('ar.8.3', 'ar.8', 'An-Nas',                       'الناس',               false, 3),
  ('ar.8.4', 'ar.8', 'Al-Falaq',                     'الفلق',               false, 4),
  ('ar.8.5', 'ar.8', 'Al-Fatihah — graduation',      'الفاتحة',             true,  5),

  ('tj.ghunnah.1',  'tj.ghunnah',  'The nasal sound', 'الغُنّة',   false, 1),
  ('tj.qalqalah.1', 'tj.qalqalah', 'The bounce',      'القَلقَلة', false, 1),
  ('tj.madd.1',     'tj.madd',     'Lengthening',     'المَدّ',    false, 1)
on conflict (lesson_id) do nothing;
