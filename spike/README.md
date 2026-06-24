# Modal de-risk spike — quran-muaalem

Throwaway experiment to answer two questions **before** building the app around the engine:

1. **Does it work?** muaalem on a Modal GPU, on a *real phone-recorded* ayah.
2. **How fast?** COLD (first call after idle) vs WARM (repeat call) latency.

These numbers drive the whole backend architecture (scale-to-zero vs warm pool, request/response vs streaming, what UX is needed to hide latency).

## Prerequisites (one-time)

```bash
pip install modal
modal token new      # opens browser, free account
```

## Get a test clip

Record **one ayah of Al-Fatihah** on a phone, save as 16 kHz mono WAV at `spike/fatiha_ayah1.wav`.
Any recorder works; convert to 16 kHz mono if needed:

```bash
ffmpeg -i your_recording.m4a -ar 16000 -ac 1 spike/fatiha_ayah1.wav
```

(Use real phone-mic audio, not a studio recording — the point is to test realistic conditions.)

## Run

```bash
modal run spike/modal_muaalem_spike.py --audio spike/fatiha_ayah1.wav
# other ayah:  --audio clip.wav --sura 98 --aya 1   (Al-Bayyinah)
```

## What to look at

- **WARM end-to-end** — the latency a user feels once the GPU is hot. Want sub-second-ish.
- **COLD end-to-end** — the penalty on the first request after idle. If this is 20–30s, scale-to-zero is unusable as-is and we need a warm pool or a UX trick.
- **predicted vs reference phonemes** — for a clean recitation they should roughly match. If they're garbage on phone audio, that's the real finding.

## Cost

Minutes of L4 GPU time = cents, inside Modal's free credits. Scale-to-zero = nothing while idle. Don't pin a GPU warm and it stays ~free.

## Notes / first-run gotchas

- First image build is slow (installs torch etc.) and is where any missing dependency surfaces — add it to the `image` in `modal_muaalem_spike.py`.
- The HF model is cached in a Modal Volume so COLD measures container spin-up + model load, not a re-download.
- `quran-transcript`'s exact "whole-ayah uthmani" call is marked `TODO(first-run)` in the script — confirm against the installed package on the first run.
- This is a spike: once we have the numbers, the real backend uses the documented `/correct-recitation` flow (full structured error diff), not this minimal phoneme path.
