# Tajweed Rules

Domain reference for the two rules most worth knowing while testing the app. The recitation engine itself detects far more than these two — this page exists so the explanations and examples below are easy to check against what you hear, not because the engine is limited to them.

Bayaan's demo focuses attention on two Tajweed rules: **Ghunnah** and **Madd**. They're common, clearly audible, and easy to verify by ear against the examples below.

---

## MVP Rules

### 1. Ghunnah (غنة) — Nasalization

**What it is:** A nasal humming sound produced from the nose, lasting approximately 2 counts (2 harakat). It is mandatory on:
- Noon with shadda (نّ)
- Meem with shadda (مّ)

**How it sounds:** The speaker should keep their mouth partially closed and let the sound resonate through the nasal passage for 2 beats.

**Common mistake:** Skipping the nasal resonance entirely, or not holding it long enough.

**Examples in Al-Fatihah:**
- `الرَّحْمَٰنِ` — the meem here does NOT have shadda, so no Ghunnah applies
- Look for نّ / مّ patterns across recitation for clear Ghunnah cases

---

### 2. Madd (مد) — Elongation

**What it is:** Prolonging a vowel sound beyond its natural length. There are several types; MVP targets the most common.

**Types included in MVP:**

| Type | Arabic | Description | Duration |
|------|--------|-------------|----------|
| Madd Asli (Natural/Original) | مد أصلي | The base elongation on ا / و / ي when no hamza or sukoon follows | 2 counts |
| Madd Wajib Muttasil | مد واجب متصل | Madd letter followed by hamza in the same word | 4–5 counts |
| Madd Ja'iz Munfasil | مد جائز منفصل | Madd letter at end of word, hamza starts the next word | 4–5 counts (reciter's choice) |

**Common mistake:** Shortening an elongation (cutting a 4-count Madd to 2 counts), or extending a natural Madd beyond 2 counts.

**Examples in Al-Fatihah:**
- `بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ` — the `ي` in `الرَّحِيمِ` is a Madd Asli (2 counts)
- `مَالِكِ يَوْمِ الدِّينِ` — the `ا` in `مَالِكِ` is Madd Asli (2 counts)

---

## Sifat (letter characteristics) — full attribute set

The recitation engine predicts 10 letter-characteristic attributes directly from audio for each phoneme group. These appear in the `sifat_errors` array of the API response and are shown to the user as a separate "Letter Characteristics" section in the result screen.

| Attribute key | English name | Arabic | What it checks |
|---|---|---|---|
| `qalqla` | Qalqalah | قلقلة | Echo-bounce on sukoon letters (ق ط ب ج د) |
| `ghonna` | Ghunnah | غنة | Nasal resonance on noon/meem (2 counts) |
| `tafkheem_or_taqeeq` | Heavy/Light | تفخيم أو ترقيق | Whether the letter was pronounced heavy (mofakham) or light (moraqaq) |
| `hams_or_jahr` | Breath | همس أو جهر | Voiced (jahr) vs. unvoiced/breathy (hams) |
| `shidda_or_rakhawa` | Strength | شدة أو رخاوة | Plosive-strong (shadeed) vs. flowing (rikhw) vs. between |
| `itbaq` | Elevation | إطباق | Tongue raised toward palate (motbaq) vs. open (monfateh) |
| `safeer` | Whistle | صفير | Whistling quality on ص ز س |
| `tikraar` | Repetition | تكرار | Vibration/trill on ر |
| `tafashie` | Spreading | تفشي | Air spreading broadly for ش |
| `istitala` | Elongation | استطالة | Tongue pressing along the upper molars for ض |

Unlike Madd and Ghunnah (which are detected by counting phoneme repetitions in the output), Sifat attributes are classified directly from the audio waveform by Muaalem's multi-level CTC heads. This means the engine can flag that Qalqalah was absent even if the phoneme itself was recognised correctly.

## Other rules (not surfaced yet)

These are contextual rules that depend on what follows a phoneme — the engine's phoneme-diff handles some of them implicitly, but they don't appear as named attributes in the current output.

| Rule | Arabic | Notes |
|------|--------|-------|
| Ikhfaa | إخفاء | Nasal concealment of noon/tanween before 15 letters |
| Idgham | إدغام | Merging of noon sakinah/tanween into the next letter |
| Qalb | قلب | Noon sakinah/tanween before ب converts to meem |

---

## Surah Coverage

The app's mushaf browser and full Uthmani text cover all 114 surahs. Al-Fatihah remains the
highest-value example below since it's recited in every prayer.

| Verse | Arabic text |
|-------|------------|
| 1 | بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ |
| 2 | الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ |
| 3 | الرَّحْمَٰنِ الرَّحِيمِ |
| 4 | مَالِكِ يَوْمِ الدِّينِ |
| 5 | إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ |
| 6 | اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ |
| 7 | صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ |
