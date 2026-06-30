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
| `audio` | file | Yes | Any audio format ffmpeg can decode (Android sends M4A/AAC) |
| `sura` | string (int) | No | Surah number. Defaults to `1`. |
| `aya` | string (int) | No | Ayah number. Defaults to `1`. |

**Response 200:** the engine's response, passed through unchanged. Shape consumed by the Android app:

```json
{
  "all_correct": false,
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

- `errors` — phoneme-level mistakes. `uthmani_pos` is `[start, end)` into the ayah's Uthmani text. `error_type` is `"tajweed"` for a rule violation; anything else is a plain mispronunciation. `ref_tajweed_rules[0].name` omitted for plain mispronunciations.
- `sifat_errors` — letter-characteristic mistakes from Muaalem's attribute heads. See [`tajweed-rules.md`](./tajweed-rules.md) for attribute keys.

**Error responses (backend validation, before the engine is called):**

| Status | `error` code | Meaning |
|---|---|---|
| 400 | `bad_request` | No `audio` field |
| 413 | `payload_too_large` | Audio exceeds 10 MB |
| 422 | `unprocessable_audio` | ffmpeg could not decode the audio |
| 503 | `ml_unavailable` | Engine unreachable or timed out |

```json
{ "error": "bad_request", "message": "missing audio field" }
```

Any other status is the engine's own response, passed through as-is.

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
