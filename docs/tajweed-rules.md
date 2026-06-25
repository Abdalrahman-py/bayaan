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

## Other rules (not the demo's focus)

These aren't specifically called out in the demo flow, but the recitation engine isn't limited to Ghunnah and Madd — it's worth knowing them if you're checking results by ear.

| Rule | Arabic | Why Descoped |
|------|--------|-------------|
| Ikhfaa | إخفاء | Requires detecting the consonant that follows noon/tanween — contextual |
| Idgham | إدغام | Merging of noon sakinah/tanween into the next letter — needs phoneme sequence |
| Qalb | قلب | Noon sakinah/tanween before ب converts to meem — contextual |

---

## Surah Coverage

The app currently covers **Al-Fatihah** (7 verses) and **Al-Bayyinah** (8 verses). Al-Fatihah is recited in every prayer, making it the highest-value target for a learning tool.

| Verse | Arabic text |
|-------|------------|
| 1 | بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ |
| 2 | الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ |
| 3 | الرَّحْمَٰنِ الرَّحِيمِ |
| 4 | مَالِكِ يَوْمِ الدِّينِ |
| 5 | إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ |
| 6 | اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ |
| 7 | صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ |
