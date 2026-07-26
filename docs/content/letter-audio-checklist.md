# Letter-audio recording checklist

The Arabic track's pedagogical core: makhraj-correct letter and syllable clips. TTS
**cannot** be trusted for isolated phonemes (`PRODUCTION_PLAN.md` §3.2), so these are
human-recorded by a qari/teacher, once. This checklist is complete enough to record
from without a follow-up question.

## Recording spec

- **Format:** 16-bit PCM, **44.1 kHz**, mono. Master as WAV, export to **`.ogg`** (Vorbis) for the app.
- **Level:** normalize to −1 dBFS peak; trim leading/trailing silence; ~0.6–1.2 s per clip.
- **Voice:** one reciter throughout (consistency matters more than variety). Clear, unhurried, Hafs.
- **No processing** beyond trim + normalize (no reverb/EQ). Record in a quiet room.

## Naming convention

`content/audio/letters/{key}_{form}.ogg` — `{key}` from the table below, `{form}` one of:

| form | what to say | example (for ب) | filename |
|---|---|---|---|
| `isolated` | the letter's plain sound, no vowel | "b" (sukoon-like) | `ba_isolated.ogg` |
| `fatha` | letter + short **a** | بَ | `ba_fatha.ogg` |
| `kasra` | letter + short **i** | بِ | `ba_kasra.ogg` |
| `damma` | letter + short **u** | بُ | `ba_damma.ogg` |
| `sukoon` | letter closed, in a syllable (e.g. aC) | ـبْ | `ba_sukoon.ogg` |
| `madd` | letter + long **aa** (fatha + alif) | بَا | `ba_madd.ogg` |

6 forms × 28 letters = **168 core clips**. (Unit 6 later adds `madd_ya` بِي / `madd_waw` بُو
per letter, ~+56, toward the ~250 in §3.2 — not needed until Unit 6 is authored.)

> **Priority:** record the clips Units 1–3 already reference **first** — get the exact
> list with `python scripts/build_content.py --list-assets` (49 clips today). The rest
> of the matrix backs Units 4–6.

## The 28 letters

| # | Letter | key | Name | # | Letter | key | Name |
|---|---|---|---|---|---|---|---|
| 1 | ء | `hamza` | hamza | 15 | ض | `dad` | daad |
| 2 | ب | `ba` | ba | 16 | ط | `taa` | taa (heavy) |
| 3 | ت | `ta` | ta | 17 | ظ | `zaa` | zaa (heavy) |
| 4 | ث | `tha` | tha | 18 | ع | `ayn` | ayn |
| 5 | ج | `jim` | jim | 19 | غ | `ghayn` | ghayn |
| 6 | ح | `hha` | haa (throat) | 20 | ف | `fa` | fa |
| 7 | خ | `kha` | kha | 21 | ق | `qaf` | qaf |
| 8 | د | `dal` | dal | 22 | ك | `kaf` | kaf |
| 9 | ذ | `dhal` | dhal | 23 | ل | `lam` | lam |
| 10 | ر | `ra` | ra | 24 | م | `mim` | mim |
| 11 | ز | `zay` | zay | 25 | ن | `nun` | nun |
| 12 | س | `sin` | seen | 26 | ه | `ha` | ha (soft) |
| 13 | ش | `shin` | sheen | 27 | و | `waw` | waw |
| 14 | ص | `sad` | saad | 28 | ي | `ya` | ya |

## Word-level clips (Unit 7+)

A few sacred/high-frequency words aren't decomposable into the letter matrix above —
same human reciter, same recording spec. `content/audio/words/{name}.ogg`:

| word | filename |
|---|---|
| اللَّهْ (Allah, pause form) | `allah.ogg` |
| رَبّْ (Rabb, pause form) | `rabb.ogg` |
| بِسْمِ اللَّهِ (Bismillah) | `bismillah.ogg` |
| القَمَرْ (al-qamar, the moon — moon letter) | `al_qamar.ogg` |
| الشَّمْسْ (ash-shams, the sun — sun letter) | `al_shams.ogg` |
| رَحْمَة (rahma, mercy — taa marbuta) | `rahma.ogg` |
| مُوسَى (Musa — alif maqsura) | `musa.ogg` |
| آدَمْ (Adam — alif madda) | `adam.ogg` |
| ٱبْنْ (ibn, son — hamzat al-wasl) | `ibn.ogg` |

## Tutor narration (TTS, not human)

Teach-segment lines (`teach.narration_en` in each lesson) are pre-generated TTS, **not**
on this checklist — `build_content.py` collects them into `content/dist/tts_manifest.json`
keyed by content hash. Voice provider is Spike S4 (`docs/decisions/tts-provider.md`,
pending); until then they pack as `pending` and the app degrades gracefully.
