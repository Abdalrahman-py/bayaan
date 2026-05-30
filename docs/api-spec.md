# API Specification

Base URL: `https://bayaan.up.railway.app` (production) · `http://localhost:8080` (local)

All protected endpoints require `Authorization: Bearer <supabase-jwt>` header.

---

## Authentication

### POST /auth/sync

Syncs a Supabase Auth user into the `public.users` table. Call this once after the user's first sign-in on Android.

**Auth required:** Yes

**Request body:** none (user identity comes from the JWT)

**Response 200:**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "created": true
}
```

`created: true` = new user row was inserted. `created: false` = user already existed.

**Response 401:** Invalid or expired Supabase JWT.

---

## Audio Analysis

### POST /audio/analyze

Sends a recitation audio clip to the backend. The backend forwards it to the ML classifier and returns a list of Tajweed violations.

**Auth required:** Yes

**Request:** multipart/form-data

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `audio` | file | Yes | Audio recording (.wav or .m4a, max 10MB) |
| `surah` | string | Yes | Surah identifier, e.g. `"al-fatihah"` |
| `verse` | integer | Yes | Verse number (1-indexed) |

**Response 200:**
```json
{
  "session_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "surah": "al-fatihah",
  "verse": 1,
  "violations": [
    {
      "rule": "ghunnah",
      "word_index": 3,
      "word_text": "الرَّحِيمِ",
      "confidence": 0.87,
      "correct": false,
      "feedback": "Apply 2-count nasal sound on the meem with shadda."
    }
  ],
  "violations_count": 1,
  "overall_correct": false
}
```

If no violations are detected, `violations` is an empty array and `overall_correct` is `true`.

**Response 400:** Missing or malformed fields.
**Response 401:** Invalid JWT.
**Response 422:** Audio could not be processed (too short, too noisy, unsupported format).
**Response 503:** ML service unavailable.

---

## Progress

### GET /progress

Returns the user's overall progress stats across all sessions.

**Auth required:** Yes

**Response 200:**
```json
{
  "total_sessions": 14,
  "total_violations": 23,
  "rules": {
    "ghunnah": {
      "total_attempts": 42,
      "correct": 35,
      "accuracy": 0.833
    },
    "madd": {
      "total_attempts": 38,
      "correct": 28,
      "accuracy": 0.737
    }
  }
}
```

---

### GET /progress/sessions

Returns a list of past recitation sessions, newest first.

**Auth required:** Yes

**Query params:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | integer | 20 | Max sessions to return |
| `offset` | integer | 0 | Pagination offset |

**Response 200:**
```json
{
  "sessions": [
    {
      "session_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "surah": "al-fatihah",
      "verse": 1,
      "violations_count": 1,
      "overall_correct": false,
      "created_at": "2026-05-29T14:32:00Z"
    }
  ],
  "total": 14,
  "limit": 20,
  "offset": 0
}
```

---

### GET /progress/sessions/{session_id}

Returns full detail for a single session including all violations.

**Auth required:** Yes

**Response 200:**
```json
{
  "session_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "surah": "al-fatihah",
  "verse": 1,
  "created_at": "2026-05-29T14:32:00Z",
  "violations": [
    {
      "rule": "ghunnah",
      "word_index": 3,
      "word_text": "الرَّحِيمِ",
      "confidence": 0.87,
      "correct": false,
      "feedback": "Apply 2-count nasal sound on the meem with shadda."
    }
  ]
}
```

**Response 404:** Session not found or belongs to a different user.

---

## Content

### GET /surahs

Returns the list of surahs available for practice. MVP returns only Al-Fatihah.

**Auth required:** No

**Response 200:**
```json
{
  "surahs": [
    {
      "id": "al-fatihah",
      "name_arabic": "الفاتحة",
      "name_english": "Al-Fatihah",
      "verse_count": 7,
      "available": true
    }
  ]
}
```

---

## Health

### GET /health

Liveness check. Used by Railway to confirm the server is up.

**Auth required:** No

**Response 200:**
```json
{ "status": "ok" }
```

---

## Error Format

All error responses follow this shape:

```json
{
  "error": "short_snake_case_code",
  "message": "Human-readable description of what went wrong."
}
```

Common error codes:

| Code | HTTP status | Meaning |
|------|-------------|---------|
| `unauthorized` | 401 | Missing or invalid Firebase JWT |
| `bad_request` | 400 | Malformed request body or missing required fields |
| `not_found` | 404 | Resource does not exist or belongs to another user |
| `unprocessable_audio` | 422 | Audio file could not be analyzed |
| `ml_unavailable` | 503 | ML service is down or timed out |
