# API Specification

Current backend as implemented in `backend/src/main/kotlin/com/bayaan/`.

Base URL: see `BACKEND_URL` in the Android app's build config. Local default: `http://localhost:8080`.

**Auth:** all endpoints except `/health` and `/surahs` require `Authorization: Bearer <supabase-jwt>`. Missing or invalid token → 401.

---

## GET /health

Liveness check. No auth required.

**Response 200:**
```json
{ "status": "ok" }
```

---

## GET /surahs

Returns the list of available surahs. No auth required.

**Response 200:**
```json
{
  "surahs": [
    { "number": 1,  "name_arabic": "الفاتحة", "name_english": "Al-Fatihah",  "verse_count": 7, "available": true },
    { "number": 98, "name_arabic": "البينة",  "name_english": "Al-Bayyinah", "verse_count": 8, "available": true }
  ]
}
```

---

## POST /auth/sync

Upserts the authenticated user into the `users` table. Call once after login to ensure a DB row exists before any other request.

**Auth required.** No request body.

**Response 200:**
```json
{ "user_id": "<uuid>", "created": true }
```

`created` is `false` if the user already existed.

---

## POST /audio/analyze

Uploads a recitation recording for one ayah and returns the engine's mistake analysis.

**Auth required.**

**Request:** `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `audio` | file | Yes | 16kHz mono WAV — the Android app encodes this directly, no server-side conversion |
| `sura` | string (int) | No | Surah number. Defaults to `1`. |
| `aya` | string (int) | No | Ayah number. Defaults to `1`. |

**Response 200:** the engine's response, passed through unchanged. Shape consumed by the Android app:

```json
{
  "all_correct": false,
  "uthmani": "مَٰلِكِ يَوْمِ ٱلدِّينِ",
  "errors": [
    {
      "uthmani_pos": [10, 14],
      "error_type": "tajweed",
      "speech_error_type": "replace",
      "ref_tajweed_rules": [
        { "name": { "en": "Aared Madd", "ar": "المد العارض للسكون" } }
      ],
      "expected_len": 4,
      "predicted_len": 2
    }
  ],
  "sifat_errors": [
    {
      "phonemes_group": "قَ",
      "attribute": "qalqla",
      "predicted": "not_moqalqal",
      "expected": "moqalqal",
      "confidence": 0.94
    }
  ]
}
```

- `uthmani` — the engine's own reference text for the ayah, the string every `uthmani_pos` indexes into. **Required whenever `errors` is non-empty**: the client renders this exact string and refuses the payload otherwise, because painting the offsets onto its own bundled copy would shift every mark by whatever the two spellings differ by.
- `errors` — phoneme-level mistakes. `uthmani_pos` is `[start, end)` into `uthmani` (above). A zero-width range (`[n, n]`) is an insertion — the gap the extra sound went into, not a letter. `error_type` is `"tajweed"`, `"tashkeel"` (vowel-mark slip) or `"normal"`; only `"tajweed"` renders as a rule violation. `error_type` is `"tajweed"` for a rule violation; anything else is a plain mispronunciation. `ref_tajweed_rules[0].name` omitted for plain mispronunciations.
- `sifat_errors` — letter-characteristic mistakes from Muaalem's attribute heads. See [`tajweed-rules.md`](./tajweed-rules.md) for attribute keys.

**Error responses:**

| Status | `error` code | Meaning |
|---|---|---|
| 400 | `bad_request` | No `audio` field |
| 413 | `payload_too_large` | Audio exceeds 10 MB |
| 503 | `ml_unavailable` | Engine unreachable, timed out, or returned an unparseable response |
| 500 | `persistence_error` | Engine call succeeded but saving the session/mistakes failed |

```json
{ "error": "bad_request", "message": "missing audio field" }
```

Any other status is the engine's own response, passed through as-is.

---

## POST /speech/grade — **Implemented (M3)**

Grades a learner's spoken echo/read-aloud attempt against arbitrary Uthmani reference
text (not necessarily a full ayah) and returns a normalized verdict. Powers `ECHO`,
`READ_ALOUD_SYLLABLE`, and `LENGTH_JUDGE` exercises in the Arabic-track lesson player.
Path A: backend forwards to Modal `POST /grade-text` on the deployed Muaalem app
(`ml/muaalem_modal.py`), then applies the grading policy below. Contract frozen —
client and server share this shape (`docs/TEAM_PLAN.md` "contract 2").

**Auth required.**

**Request:** `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `audio` | file | Yes | 16kHz mono WAV, ≤4s (trim client-side before upload — see latency budget, `PRODUCTION_PLAN.md` §3.4). |
| `tier` | string (int) | Yes | `1` = Tier-1 echo (arbitrary syllable/word, Path A per `decisions/grading-tiers.md`). `2` = Tier-2 read-aloud (real Quran text, existing `/audio/analyze` pipeline). |
| `reference_text` | string | Yes | Uthmani-script text the learner was asked to say — a syllable, word, or short phrase. Must be madd- or sukoon-final per the grading-tiers.md waqf convention; the content pipeline's validator enforces this at build time, this endpoint does not re-validate it. |
| `item_ref` | string | Yes | Stable exercise identifier, e.g. `"ar.3.2.echo.ba_kasra"` — echoed back unchanged, used by the client to route the verdict to the right UI element and by `lesson_attempts`/`review_items` for persistence. Opaque string to this endpoint; not parsed. |

**Response 200:**

```json
{
  "verdict": "retry",
  "score": 0.62,
  "phoneme_issues": [
    {
      "uthmani_pos": [0, 1],
      "issue_type": "consonant_swap",
      "expected_phoneme": "صَ",
      "predicted_phoneme": "سَ",
      "feedback_key": "swap_sad_seen"
    }
  ],
  "item_ref": "ar.3.2.echo.ba_kasra"
}
```

- `verdict` — one of `pass` (≥80% accuracy, no more than one minor issue — see grading policy below), `retry` (recoverable: single minor error, or an engine decode crash), `fail` (multiple or major errors). Client shows retry/pass/fail UI directly off this field; it never re-derives a verdict from `phoneme_issues`.
- `score` — `0.0`–`1.0`, informational (drives the wrap-screen score ring); not authoritative for pass/fail, `verdict` is.
- `phoneme_issues[]` — same vocabulary as `/audio/analyze`'s `errors[]` (§ above), reshaped for arbitrary reference text instead of ayah position:
  - `uthmani_pos` — `[start, end)` into `reference_text` (not a full ayah — `reference_text` is usually one syllable/word, so this is almost always `[0, N]`).
  - `issue_type` — one of `consonant_swap`, `vowel_swap`, `length_short` (elongation cut short), `length_long` (elongation held too long), `missing_ghunnah`, `missing_qalqalah`.
  - `expected_phoneme` / `predicted_phoneme` — Uthmani-script phoneme-group strings, same format as `/audio/analyze`'s `phonemes_group`.
  - `feedback_key` — a stable string identifying the specific mistake, for client-side copy lookup and for the M5 tutor prompt (`PRODUCTION_PLAN.md` §4.x "dynamic tutor moments" reads this, not raw phoneme data). Enum, grounded in the confusion pairs `decisions/grading-tiers.md`'s Spike S1 actually tested:
    - `swap_sad_seen`, `swap_taa_ta`, `swap_haa_ha`, `swap_qaf_kaf` (the four minimal pairs tested in S1)
    - `swap_consonant_other` (any other consonant confusion)
    - `vowel_mismatch`
    - `length_short`, `length_long`
    - `light_lam` (tafkheem-of-lam — flag only, per grading-tiers.md's note that this one is not cleanly isolable in Tier 1 yet, don't build a lesson that depends on a clean isolated signal here)
    - `pass` (used when `verdict: pass` and `phoneme_issues` is empty)
- `item_ref` — echoed back unchanged from the request.

**Grading policy** (from `decisions/grading-tiers.md` — decided, do not re-litigate; if you're changing this behavior, that file needs updating first):

- `insert`-type errors positioned at the start or end of `reference_text` are dropped before scoring (breath/noise artifacts at clip boundaries) — they never appear in `phoneme_issues` and never affect `verdict`.
- Exactly one minor issue (a single `phoneme_issues` entry, not `length_long`/`length_short` on a madd-critical position) → `verdict: retry`, never `fail`. Two or more issues, or one major issue → `fail`.
- If the engine's decode step crashes (`multilevel_greedy_decode` `RuntimeError`, seen in Spike S1 on 1/43 clips) → catch it server-side, return `verdict: retry`, `score: 0`, `phoneme_issues: []` — never a 500.
- **Beginner-retest prerequisite (hard M3 gate):** the policy above is tuned against Spike S1's data, which used two native-Arabic speakers. `decisions/grading-tiers.md`'s open items call out that a genuine non-native beginner retest must run before M3 ships — the tolerances above may need adjusting once that data exists. See `docs/workstreams/ws-learn-backend.md` task list.

**Error responses:** same envelope as `/audio/analyze` (`{"error": "...", "message": "..."}`); reuses its `400`/`413`/`503` codes for the same conditions (missing audio, oversize audio, engine unreachable). No new error codes — a decode crash is *not* an error response, it's a `200` with `verdict: retry` (see grading policy above).

---

## Learn endpoints — M4, implemented

The lesson/XP/SRS surface for the Learn tab. All five require auth. Backing tables:
`profiles`, `xp_events`, `placement_results`, `lesson_progress`, `lesson_attempts`,
`review_items` (migration `0001_mvp_learn_tables.sql`). The curriculum tree itself
(units → lessons) is static, served from `backend/src/main/resources/curriculum.json`
via `Curriculum.kt`; the DB only stores per-user *progress* over that tree.

A user's `profiles` row is created lazily on first touch of any Learn endpoint
(`ProfileRepository.ensure`), with defaults `arabic_level=0`, `xp=0`, `streak_count=0`,
`daily_goal_minutes` (schema default). No separate "create profile" call.

### GET /learn/path

The learner's full curriculum tree with per-lesson status overlaid — the Learn tab's
main payload.

**Auth required.**

**Response 200:**

```json
{
  "header": {
    "arabic_level": 0,
    "xp": 240,
    "streak_count": 3,
    "daily_goal_minutes": 10,
    "reviews_due": 6
  },
  "units": [
    {
      "unit_id": "ar.1",
      "track": "arabic",
      "title_en": "The Letters",
      "title_ar": "الحروف",
      "lessons": [
        {
          "lesson_id": "ar.1.1",
          "title_en": "Dotted family",
          "title_ar": "ب ت ث ن ي",
          "is_checkpoint": false,
          "status": "completed",
          "best_score": 0.92,
          "attempts": 2
        }
      ]
    }
  ]
}
```

- `header` — from the user's `profiles` row; `reviews_due` = count of `review_items` with `due_on ≤ today` (UTC).
- `units` / `lessons` — mirror `curriculum.json` order verbatim. `track` is `"arabic"` or `"tajweed"`.
- `best_score` (0.0–1.0) / `attempts` — from the user's `lesson_progress` row (`0.0` / `0` if never attempted).
- `status` — one of `completed`, `in_progress`, `available`, `locked`. Derived server-side per request, not stored:
  - **Single global chain in curriculum file order.** A lesson is `available` when the immediately-preceding lesson (across the whole file, not just its unit) is `completed`; the very first lesson is always `available`; everything after the frontier is `locked`. Because the tajweed units follow the Arabic units in the file, this gates the Tajweed track behind the final Arabic lesson — **graduation unlocks tajweed**.
  - `completed` / `in_progress` come from the user's `lesson_progress` row.

### POST /learn/complete

Records a finished lesson attempt, awards XP, advances the streak, and seeds SRS review
items for missed content. Idempotent-ish: a checkpoint/lesson only flips to `completed`
once; re-completing the same lesson the same day does not double-bump the streak.

**Auth required.**

**Request:** `application/json`

```json
{
  "lesson_id": "ar.1.1",
  "score": 0.9,
  "is_checkpoint": false,
  "item_results": [
    { "item_ref": "ar.1.1.listen.ba", "correct": true, "first_try": true },
    { "item_ref": "ar.1.1.echo.ta", "correct": false, "first_try": false }
  ]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `lesson_id` | string | Yes | Must exist in `curriculum.json` — unknown id → `404`. |
| `score` | number | Yes | `0.0`–`1.0`. Coerced into range server-side. |
| `is_checkpoint` | bool | No | Informational only — the server uses `curriculum.json`'s `is_checkpoint` for the lesson, never the client's value. |
| `item_results` | array | Yes | Per-exercise results `{item_ref, correct, first_try}`; stored in `lesson_attempts`. Drives XP and review seeding (below). |

**Response 200:**

```json
{
  "header": { "arabic_level": 0, "xp": 350, "streak_count": 4, "daily_goal_minutes": 10, "reviews_due": 7 }
}
```

- `header` — the updated snapshot, same shape as `/learn/path`'s `header`.
- **XP** = base + `2 ×` (items answered `correct` on the `first_try`); base is `10` for a lesson, `20` for a checkpoint (fixed constants in `LearnRoutes.kt`, owner retunes). Logged to `xp_events` with reason `lesson_complete` / `checkpoint_complete`.
- **Pass** = `score ≥ 0.80` (lesson) / `0.85` (checkpoint) → `lesson_progress.status = completed`, else `in_progress`. `best_score`/`attempts` update every call.
- **Streak** — updated once per **UTC** day on any `/learn/complete` call: a call today keeps it, a call the day after the last bumps `+1`, a longer gap resets to `1`.
- **Reviews** — every `item_results` entry with `correct: false` is seeded into `review_items` (interval 1 day, due tomorrow) unless already queued (queued items keep their ladder position).

**Errors:** `404 {"error":"not_found","message":"Unknown lesson_id"}`.

### GET /learn/reviews

Due spaced-repetition items for the learner (SM-2-lite ladder `[1, 3, 7, 21]` days,
`PRODUCTION_PLAN.md` §4.x).

**Auth required.**

**Query params:**

| Param | Default | Range |
|---|---|---|
| `limit` | 20 | 1–100 |

**Response 200:**

```json
{
  "reviews": [
    { "review_id": "<uuid>", "item_ref": "ar.1.1.echo.ba", "due_on": "2026-07-11" }
  ]
}
```

- Returns items whose `due_on` is on or before today (UTC), soonest-due first (`limit` applies).

### POST /learn/reviews/{id}/result

Grades one review and re-schedules it on the ladder.

**Auth required.** `{id}` is the review item's UUID.

**Request:** `application/json`

```json
{ "correct": true }
```

**Response 200:**

```json
{ "next_due_on": "2026-07-18", "reviews_due": 5 }
```

- `correct: true` → advance one rung on `[1, 3, 7, 21]` (caps at 21), `lapses` unchanged; `next_due_on = today + new interval`.
- `correct: false` → interval resets to `1`, `lapses` +1, `next_due_on` = tomorrow.
- `reviews_due` — updated count of items now due (`due_on ≤ today`).

**Errors:** `404 {"error":"not_found","message":"Review item not found"}` — malformed UUID, or the item doesn't exist / belongs to another user (not `403`, matching `/progress/sessions/{id}`).

### POST /learn/placement

Records a placement-test result and sets the learner's starting Arabic level.

**Auth required.**

**Request:** `application/json`

```json
{
  "item_results": [
    { "item_ref": "ar.3.2.echo.min", "difficulty": 3, "correct": true }
  ]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `item_results` | array | Yes | `{item_ref, difficulty, correct}` **in presentation order**; stored in `placement_results`. |

The server computes the level **deterministically** — the client is not trusted to report it. Start at level 3; walk the results in order tracking consecutive hits/misses: 2 consecutive misses drop a level (min 0), 3 consecutive hits raise one (max 8). The final level is written to `profiles.arabic_level`.

**Response 200:**

```json
{ "arabic_level": 4, "placement_message_key": "placement.level.4" }
```

- `placement_message_key` — a copy key the client renders; no user-facing prose lives in the backend.

---

## GET /progress

Returns a summary of the authenticated user's recitation history.

**Auth required.**

**Response 200:**
```json
{
  "total_sessions": 12,
  "perfect_sessions": 3,
  "overall_accuracy": 0.25,
  "total_mistakes": 47,
  "mistake_breakdown": {
    "Aared Madd": 12,
    "Ghunnah": 8,
    "Other": 27
  }
}
```

- `overall_accuracy` = `perfect_sessions / total_sessions` (0.0 if no sessions).
- `mistake_breakdown` keys are Tajweed rule names in English; `"Other"` covers plain mispronunciations (no named rule).

---

## GET /progress/sessions

Paginated list of the authenticated user's sessions, most-recent first.

**Auth required.**

**Query params:**

| Param | Default | Range |
|---|---|---|
| `limit` | 20 | 1–100 |
| `offset` | 0 | ≥ 0 |

**Response 200:**
```json
{
  "sessions": [
    {
      "session_id": "<uuid>",
      "sura": 1,
      "aya": 1,
      "all_correct": false,
      "mistakes_count": 4,
      "created_at": "2026-06-30T12:34:56Z"
    }
  ],
  "total": 12,
  "limit": 20,
  "offset": 0
}
```

---

## GET /progress/sessions/{session_id}

Full detail for one session, including every recorded mistake.

**Auth required.** Returns 404 (not 403) if the session belongs to a different user or doesn't exist. Malformed UUID also returns 404.

**Response 200:**
```json
{
  "session_id": "<uuid>",
  "sura": 1,
  "aya": 1,
  "all_correct": false,
  "created_at": "2026-06-30T12:34:56Z",
  "mistakes": [
    {
      "id": "<uuid>",
      "char_start": 10,
      "char_end": 14,
      "error_type": "tajweed",
      "speech_error_type": "replace",
      "rule_name_en": "Aared Madd",
      "rule_name_ar": "المد العارض للسكون",
      "expected_len": 4,
      "predicted_len": 2
    }
  ]
}
```
