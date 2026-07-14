# S4 — TTS bake-off: provider pick + makharij gate

Resolves wayfinder ticket *Tutor-voice TTS provider*
(`.scratch/mvp-tracks/issues/04-tts-provider-decision.md`).

**Two verdicts to deliver:**
1. **Provider + voice** for tutor narration (the ~95% of scripted lines shipped as
   bundled assets).
2. **Pass/fail on isolated-letter makharij** — the gate from ticket *Letter-audio
   sourcing policy*: can non-Qur'anic Arabic-track teaching audio (letters, harakat,
   syllables) be TTS at all, or do those clips need a human speaker? **Qur'anic
   recitation audio is NOT in this test** — that's a licensed reciter recording.

**Candidates (plan §3.2):** ElevenLabs multilingual v2 vs Azure Neural `ar-*`
(try `ar-EG` and `ar-SA` voices). A native Arabic speaker judges by ear.

Keep spend trivial — ~36 short clips per provider, one generation pass, no batch job.

---

## Battery A — isolated letters / harakat (the makharij gate)

Generate each on **both** providers. These are the sounds TTS most often mangles;
if it blurs them, a beginner learns the wrong makhraj — so this battery decides
verdict 2. Judge each: **is the makhraj correct and unconfusable to a learner?**

**Throat / pharyngeal (hardest):** ءَ · هَ · عَ · حَ · غَ · خَ

**Emphatic vs light contrasts (must stay distinct):**
- صَ vs سَ
- ضَ vs دَ
- طَ vs تَ
- ظَ vs ذَ vs زَ
- قَ vs كَ

**Harakat + madd (on a neutral letter):** بَ · بِ · بُ · بَا · بِي · بُو

**Lam of Allah (heaviness):** ٱللَّه

**Verdict-2 rule:** PASS only if every emphatic stays clearly distinct from its light
pair (ص≠س, ط≠ت, ض≠د, ظ≠ذ≠ز, ق≠ك) **and** the throat letters are unambiguous. Any
blurred emphatic or vowel-like ع/ح = **FAIL** → those clips move to human recording.

## Battery B — tutor narration (the provider pick)

20 real lines the app will speak. Generate on both providers; score verdict 1.

| # | Line (with tashkeel) | English gloss | Kind |
|---|---|---|---|
| 1 | اِستَمِع جَيِّدًا. | Listen carefully. | instruction |
| 2 | اِضغَط على الحَرف الذي سَمِعتَه. | Tap the letter you heard. | instruction |
| 3 | كَرِّر بَعدي. | Repeat after me. | instruction |
| 4 | اِقرَأ هذه الكَلِمة بِصَوتٍ عالٍ. | Read this word aloud. | instruction |
| 5 | سَجِّل صَوتَك الآن. | Record your voice now. | instruction |
| 6 | أَحسَنت! | Excellent! | feedback |
| 7 | قَريب جِدًّا. | Very close. | feedback |
| 8 | اِجعَل الصّاد أَثقَل. | Make the ṣād heavier. | feedback |
| 9 | الحَرف كان خَفيفًا، حاوِل مَرّة أُخرى. | The letter was light — try again. | feedback |
| 10 | اِنتَبِه لِطولِ المَدّ. | Watch the length of the madd. | feedback |
| 11 | رائِع، نُطقُك صَحيح. | Great, your pronunciation is correct. | feedback |
| 12 | الغُنّة صَوتٌ يَخرُج مِن الأَنف. | Ghunnah is a sound from the nose. | teaching |
| 13 | القَلقَلة اهتِزازٌ في الحَرفِ السّاكِن. | Qalqalah is a bounce on the sukoon letter. | teaching |
| 14 | المَدّ هو إِطالةُ الصَّوت. | Madd is lengthening the sound. | teaching |
| 15 | أَكمَلتَ الدَّرس! | You finished the lesson! | wrap |
| 16 | سِلسِلَتُك الآن سَبعَةُ أَيّام. | Your streak is now seven days. | wrap |
| 17 | اِستَمِرّ، أَنتَ تَتَقَدَّم. | Keep going — you're improving. | wrap |
| 18 | Great! Now say صَا. | (code-switch) | mixed |
| 19 | Nice work! حاوِل الكَلِمة التّالية. | Nice work! Try the next word. | mixed |
| 20 | Your ع needs work — تَذَكَّر، مِن الحَلق. | ...remember, from the throat. | mixed |

Lines 8, 12–14, 18–20 double as stress tests: correct pronunciation of the emphatic
letter names, tajweed terms, and clean Arabic⇄English code-switching.

## Generate

- ElevenLabs: multilingual v2, one clear voice; API or web UI, export WAV/MP3.
- Azure: Speech Studio / TTS REST, `ar-EG-SalmaNeural` + `ar-SA-HamedNeural` (or the
  current neural `ar-*` voices), export WAV.
- Same text to both. Name files `A_<letter>_<provider>` / `B_<n>_<provider>` so the
  judge can A/B blind if desired.

## License gate (hard — a great voice we can't ship is worthless)

Read the provider ToS and answer explicitly:
- [ ] Does it permit **bundling / redistributing generated audio as static files in a
      shipped app** (not just real-time streaming playback)?
- [ ] One-time generation cost, or an ongoing per-asset / per-play fee?
- [ ] Attribution required?
- [ ] Any per-voice redistribution restriction (some premium voices differ from the base ToS)?

A provider that fails the bundling clause is out regardless of voice quality.

## Judge & record

- **Battery A:** per letter, per provider → PASS/FAIL. Apply the verdict-2 rule above.
- **Battery B:** per line, per provider → 1–5 on {naturalness, clarity, learner pace,
  correct tashkeel, code-switch}. Higher aggregate + acceptable floor wins.
- Write both verdicts + the license finding to `docs/decisions/tts-provider.md`, then
  resolve ticket *Tutor-voice TTS provider*. If verdict 2 is FAIL, note that
  Arabic-track letter/harakat clips need a human speaker (feeds the content-schema fog).
