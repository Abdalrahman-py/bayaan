# API Specification

This documents the backend exactly as implemented in `backend/src/main/kotlin/com/bayaan/Routing.kt`. There are two endpoints. No authentication, no other resources — accounts, progress tracking, and surah listing endpoints described in earlier drafts of this doc were never built.

Base URL: see `BACKEND_URL` in the Android app's build config for the current deployed URL. Local default: `http://localhost:8080`.

---

## GET /health

Liveness check.

**Response 200:**
```json
{ "status": "ok" }
```

---

## POST /audio/analyze

Uploads a recitation recording for one ayah and returns the recitation engine's mistake analysis.

**Request:** `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `audio` | file | Yes | Any audio format ffmpeg can decode (the Android app sends M4A/AAC) |
| `sura` | string (int) | No | Surah number. Defaults to `1` if missing or not a valid int. |
| `aya` | string (int) | No | Ayah number. Defaults to `1` if missing or not a valid int. |

**Response 200:** the recitation engine's response, passed through unchanged. Shape consumed by the Android app (`RecitationViewModel.parseResponse`):

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
  ]
}
```

- `uthmani_pos` — half-open `[start, end)` character range into the ayah's Uthmani text.
- `error_type` — `"tajweed"` for a rule violation; anything else is treated as a plain mispronunciation.
- `speech_error_type` — `"replace"` | `"insert"` | `"delete"`.
- `ref_tajweed_rules[0].name` — Arabic/English rule name. Omitted (or empty) for plain mispronunciations.
- `expected_len` / `predicted_len` — elongation count comparison, present for length-based rules (e.g. Madd), otherwise absent.

If `all_correct` is `true`, `errors` is empty.

**Error responses** (backend's own validation, before the audio reaches the engine):

| Status | `error` code | Meaning |
|---|---|---|
| 400 | `bad_request` | No `audio` field in the multipart body |
| 413 | `payload_too_large` | Audio exceeds 10MB |
| 422 | `unprocessable_audio` | ffmpeg could not decode the uploaded audio |
| 503 | `ml_unavailable` | The recitation engine didn't respond (unreachable or timed out — its serverless GPU can take a while to cold-start) |

Error body shape:
```json
{ "error": "bad_request", "message": "missing audio field" }
```

Any other status code is whatever the recitation engine itself returned, passed through as-is.
