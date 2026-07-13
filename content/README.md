# Bayaan content pack

Versioned, bundled curriculum for the Arabic track (and, later, the Tajweed track).
This directory **is the contract** between content authoring and the app — if the app
needs a field that isn't here, that's a schema change (edit this file + the schemas +
`scripts/build_content.py`), not a client-side workaround.

Ships as app assets; the DB stores only per-user state keyed by the stable
`lesson_id` / `item_ref` strings defined here (`PRODUCTION_PLAN.md` §8).

## Layout

```
content/
├── curriculum.json          Roadmap: units → lesson list (order = array order).
├── lessons/{lesson_id}.json One file per lesson: teach segment + exercise items.
├── audio/
│   ├── letters/*.ogg         Human-recorded letter/haraka clips (see checklist).
│   └── tts/{hash}.ogg        Pre-generated tutor lines, keyed by content hash.
├── schema/*.json             JSON Schema for the two file kinds (human contract).
└── dist/                     Build output (git-ignored) — the packed asset bundle.
```

`schema/*.json` documents the shape; **`scripts/build_content.py` is the enforcer** and
checks things JSON Schema can't (waqf-safety, answer∈options, curriculum↔lesson
agreement, dangling assets). Run it before every content commit:

```bash
python scripts/build_content.py            # validate + pack (pending audio ok)
python scripts/build_content.py --strict   # pending audio becomes a hard error (CI)
python scripts/build_content.py --list-assets
python scripts/test_build_content.py       # the pipeline's own self-check
```

## `curriculum.json`

```jsonc
{
  "version": 1,
  "units": [
    { "unit_id": "ar.1", "track": "arabic",         // track: "arabic" | "tajweed"
      "title_en": "The Letters", "title_ar": "الحروف",
      "lessons": [
        { "lesson_id": "ar.1.1", "title_en": "…", "title_ar": "…", "is_checkpoint": false }
      ] }
  ]
}
```

The backend `/learn/path` reads **only** this file's `version`, `units[].{unit_id,
track, title_en, title_ar}`, and `lessons[].{lesson_id, title_en, title_ar,
is_checkpoint}`. Unlock order is array order, per track.

## Lesson file — `lessons/{lesson_id}.json`

```jsonc
{
  "lesson_id": "ar.1.1",          // must equal the file stem and the curriculum id
  "unit_id": "ar.1",
  "title_en": "Dotted family", "title_ar": "ب ت ث ن ي",
  "is_checkpoint": false,         // must match curriculum
  "teach": {
    "narration_en": "…",           // the tutor line → TTS (tts_manifest)
    "glyphs": ["ب", "ت"],          // what's taught/shown
    "focus_en": "one-line concept" // optional
  },
  "items": [ … ]                   // >= 1 authored item (see below)
}
```

A **stub** lesson (Units 4–8, tajweed — not yet authored) instead carries
`"stub": true` and `"items": []`. The build treats stubs as valid and reports them
separately from authored lessons.

### Exercise items

Every item: `item_ref` (unique, prefixed with the lesson id), `type`, `grading_tier`.

| `type` | tier | Required fields | Meaning |
|---|---|---|---|
| `LISTEN_PICK` | 0 | `prompt_asset`, `answer`, `options[≥2]` | hear a sound → tap the letter/vowel |
| `READ_PICK` | 0 | `prompt_text_ar`, `answer`, `options[≥2]` (audio) | see a letter → tap the matching sound |
| `DISCRIMINATE` | 0 | `prompt_asset`, `answer`, `options[≥2]` | hear one of a pair → which was it |
| `ODD_ONE_OUT` | 0 | `answer`, `options[≥3]` | tap the one that doesn't belong |
| `ECHO` | 1 | `reference_text` (+ optional `prompt_asset`) | repeat a syllable/word into the mic |
| `READ_ALOUD_SYLLABLE` | 1 | `reference_text` | read the shown syllable aloud |

- `answer` must appear in `options` (pick / discriminate / odd-one-out).
- Recognition types (`*_PICK`, `DISCRIMINATE`, `ODD_ONE_OUT`) are always `grading_tier: 0`
  (no mic). Spoken types (`ECHO`, `READ_ALOUD_SYLLABLE`) are tier 1 (or 2 later).

### Waqf rule (enforced) — the one non-obvious constraint

Every `reference_text` on a spoken item **must be madd- or sukoon-final** — never end in
a bare short vowel (fatha/kasra/damma) or tanween. Muaalem's phonetizer applies stop
rules word-finally, so a `بَ`-style target false-flags a correct learner
(`docs/decisions/grading-tiers.md` §1). The build **fails** on a violation. In practice:
teach a short vowel on the *first* letter and close the syllable with sukoon (`كَمْ`,
`مِنْ`, `كُلْ`) or extend with madd (`بَا`).

## Audio asset naming

`audio/letters/{key}_{haraka}.ogg` — `key` is the letter's latin key (see
`docs/content/letter-audio-checklist.md` for the full 28-letter map), `haraka` ∈
`{fatha, kasra, damma, sukoon, madd}`. Referenced clips that don't exist yet are
"pending" (letter clips are a human recording dependency; TTS awaits the S4 voice
pick) — a warning by default, an error under `--strict`. `--list-assets` prints
exactly what the authored lessons currently require.
