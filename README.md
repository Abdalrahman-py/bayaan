# Bayaan

An AI-powered Quran recitation coach. A student records an ayah, and Bayaan flags Tajweed and pronunciation mistakes directly on the Arabic script — no teacher required to catch what went wrong.

**Status: working prototype, one full loop built end to end** — sign in, pick an ayah, record it, get mistakes highlighted, try again. Three services, each with a distinct job:

## What's built

### Android — Kotlin, Jetpack Compose, Material 3
A two-screen RTL-first app: a verse picker (Al-Fatihah, Al-Bayyinah) and a recitation screen driven by a single UI state machine (`Ready → Recording → Uploading → Result/Error`). Records 16kHz mono PCM directly via `AudioRecord`, wraps it as WAV in-memory, and renders per-character mistake highlighting over Uthmani script using `AnnotatedString`.

### Backend — Kotlin, Ktor
Verifies Supabase JWTs locally (HS256, no round-trip per request), forwards audio to the recitation engine, and persists every session and mistake to Postgres. Six endpoints — auth sync, analyze, and paginated progress history. Deployed on Render from a single Dockerfile.

### ML — pretrained model on serverless GPU
Runs `obadx/quran-muaalem`, a third-party recitation-analysis model, on Modal. Returns phoneme-level mistakes (`errors`) tied to character ranges in the verse, plus 10 letter-characteristic attributes (`sifat_errors` — qalqalah, ghunnah, tafkheem, etc.) classified directly from the audio waveform. No training happens in this repo; a de-risking spike ([`spike/`](spike/)) validated latency and accuracy before the backend was built around it.

---

## How it works

1. Sign in (Supabase Auth).
2. Pick a verse from Al-Fatihah or Al-Bayyinah.
3. Tap record and recite it.
4. The app uploads the recording; the backend forwards it to the recitation engine and gets back a structured list of mistakes.
5. The backend persists the session and its mistakes, then the app highlights the mistaken text and explains what went wrong — which rule, what was expected, what was recited.
6. Try again, or move to the next ayah. `GET /progress` shows aggregate stats across past sessions.

## Architecture

```
Android app  --(JWT + audio)-->  Ktor backend  --(audio)-->  Recitation engine
   (Compose)                     (auth, persist,             (pretrained model,
                                   thin proxy)                 serverless GPU)
                                        |
                                        v
                                Supabase Postgres
```

Full breakdown: [`docs/architecture.md`](docs/architecture.md).

## Documentation

| Doc | What's in it |
|---|---|
| [Architecture](docs/architecture.md) | System design, data flow, what's deferred |
| [API Spec](docs/api-spec.md) | Every endpoint, request/response shapes, error codes |
| [Tajweed Rules](docs/tajweed-rules.md) | The rules covered in the demo, with examples |
| [AGENTS.md](AGENTS.md) | Contributing rules, commit format (also read by AI coding agents) |

## Roadmap

The current build is deliberately a single, well-tested loop rather than a broad feature set. Next, in rough order:

- Wider Quran coverage beyond the two demo surahs
- An Arabic-proficiency placement step ahead of recitation practice
- Spoken (TTS) feedback instead of text-only (later)
