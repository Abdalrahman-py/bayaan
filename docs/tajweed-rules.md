# Tajweed Rules

Bayaan's MVP focuses on two Tajweed rules: **Ghunnah** and **Madd**. These were chosen because they are common, clearly audible, and can be reliably classified by a binary ML model without needing multi-word context.

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

**What the model detects:**
- Input: audio segment around a noon/meem with shadda
- Output: binary — Ghunnah correctly applied (true) or violated (false)
- Confidence threshold: ≥ 0.75 F1 on test set

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

**What the model detects:**
- Input: audio segment containing a Madd letter
- Output: binary — elongation is within acceptable range (true) or violated (false)
- Duration is measured from the raw audio waveform; confidence threshold ≥ 0.75 F1

---

## Stretch Goal Rules (Post-MVP)

These were descoped from MVP because they require context from surrounding words, making binary classification harder.

| Rule | Arabic | Why Descoped |
|------|--------|-------------|
| Ikhfaa | إخفاء | Requires detecting the consonant that follows noon/tanween — contextual |
| Idgham | إدغام | Merging of noon sakinah/tanween into the next letter — needs phoneme sequence |
| Qalb | قلب | Noon sakinah/tanween before ب converts to meem — contextual |

---

## Surah Coverage

MVP is restricted to **Surah Al-Fatihah** (7 verses). Every Muslim recites it in every prayer, making it the highest-value target for a learning tool.

| Verse | Arabic text |
|-------|------------|
| 1 | بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ |
| 2 | الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ |
| 3 | الرَّحْمَٰنِ الرَّحِيمِ |
| 4 | مَالِكِ يَوْمِ الدِّينِ |
| 5 | إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ |
| 6 | اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ |
| 7 | صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ |

---

## Evaluation Targets

The ML classifier must meet these targets before the backend integrates it:

| Metric | Target | Notes |
|--------|--------|-------|
| F1 score per rule | ≥ 0.75 | Measured on held-out test split |
| Inference latency | ≤ 800ms | 20-trial average on Railway free tier |
| Model format | ONNX | Required for embedding outside PyTorch |

---

## Dataset

**QDAT (Quran Dataset for Arabic Tajweed)** — labeled audio segments with rule annotations. Training uses wav2vec2 transfer learning (pre-trained on Arabic speech). One binary classifier is trained per rule.

Training runs on Kaggle free GPU (T4 / P100). Expected training time: 2–4 hours per rule.
