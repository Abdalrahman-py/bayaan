# Bayaan

Bayaan listens to a Quran recitation and flags Tajweed and pronunciation mistakes on the spot, so a student can correct them without a teacher in the room.

**Status: working prototype.** One loop is fully built end to end — pick an ayah, record it, get mistakes highlighted on the script, try again. Accounts, progress tracking, and broader Quran coverage are deliberately out of scope for now; see [Roadmap](#roadmap).

---

## How it works

1. Pick a verse from Al-Fatihah or Al-Bayyinah.
2. Tap record and recite it.
3. The app uploads the recording to the backend.
4. The backend converts it and forwards it to a recitation-analysis engine, which returns a structured list of mistakes (mispronunciations and Tajweed-rule violations, each tied to a position in the verse).
5. The app highlights the mistaken text and shows what went wrong — which rule, what was expected, what was recited.
6. Try again, or move to the next ayah.

No sign-in, no stored history — every attempt is self-contained.

## Architecture

```
Android app  --(record + upload)-->  Ktor backend  --(audio)-->  Recitation engine
   (Compose)                         (thin proxy,                (pretrained model,
                                       ffmpeg conversion)          serverless GPU)
```

The backend doesn't run its own model — it converts the uploaded audio to the format the engine expects and relays the result. There's no database and no auth layer in the current build. Full breakdown: [`docs/architecture.md`](docs/architecture.md).

## Tech stack

| Layer | Technology |
|---|---|
| Android | Kotlin, Jetpack Compose, Material 3 |
| Backend | Kotlin, Ktor |
| Audio conversion | ffmpeg |
| Recitation analysis | Pretrained model, deployed on a serverless GPU |
| Backend hosting | Render |

## Getting started

### Prerequisites

- Android Studio (Ladybug or later) — for the app
- JDK 21 — for the backend
- ffmpeg installed locally if you want to run the backend outside Docker

No API keys or `.env` values are required to run either side — the backend talks to a working default recitation-engine URL out of the box, and the Android app points at the deployed backend by default.

### Run it

```bash
git clone https://github.com/Abdalrahman-py/bayaan.git
cd bayaan
bash scripts/setup.sh
```

- **Android:** open `android/` in Android Studio, run on a device or emulator.
- **Backend:** `cd backend && ./gradlew run` (serves on `localhost:8080`).

### Project layout

```
bayaan/
├── android/   Jetpack Compose app
├── backend/   Ktor API (audio proxy)
├── ml/        Deployment script for the recitation engine
├── design/    UI/UX assets
├── docs/      Architecture, API spec, Tajweed reference
└── scripts/   Dev tooling
```

## Documentation

| Doc | What's in it |
|---|---|
| [Architecture](docs/architecture.md) | System design, data flow, what's deferred |
| [API Spec](docs/api-spec.md) | The backend's two endpoints, request/response shapes |
| [Tajweed Rules](docs/tajweed-rules.md) | The rules covered in the demo, with examples |
| [AGENTS.md](AGENTS.md) | Contributing rules, commit format (also read by AI coding agents) |

## Roadmap

The current build is deliberately a single, well-tested loop rather than a broad feature set. Next, in rough order:

- Wider Quran coverage beyond the two demo surahs
- An Arabic-proficiency placement step ahead of recitation practice
- Accounts and per-user progress tracking
- Spoken (TTS) feedback instead of text-only (later)

