"""
Modal de-risk spike for quran-muaalem.

GOAL: answer two questions before we build the app around this engine —
  1. Does muaalem run on a Modal GPU and return sensible output on a REAL
     phone-recorded ayah (not just clean studio audio)?
  2. What is the latency? We need two numbers:
       - COLD: first call after the container was asleep (model load + container spin-up)
       - WARM: a repeat call while the container is still alive (pure inference)

This is THROWAWAY code. It tests the risky part (GPU model + Modal cold-start),
not the product. We deliberately use the `Muaalem` Python class for inference and
print predicted-vs-reference phonemes to eyeball correctness.

ponytail: we do NOT reproduce the full `/correct-recitation` structured-error diff
here. That diff is deterministic CPU post-processing on top of the phoneme output —
low risk, fast, and not what we're de-risking. Wire it in later when building the
real backend, using their `app` package or the documented /correct-recitation endpoint.

Targets modal ~0.63+. Run with:   modal run spike/modal_muaalem_spike.py --audio spike/fatiha_ayah1.wav
Prereqs: `pip install modal` and `modal token new` (free account). See spike/README.md.
"""

import io
import time

import modal

# System deps (ffmpeg/libsndfile1) + the engine. quran-muaalem pulls torch/transformers.
# NOTE: if the image build fails on a missing dep, add it here — first build is the
# place we discover the exact dependency set. soundfile is for decoding uploaded bytes.
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "libsndfile1")
    .pip_install(
        "quran-muaalem",
        "quran-transcript",
        "librosa",
        "soundfile",
        "numba>=0.61.2",
    )
)

app = modal.App("muaalem-spike", image=image)

# Cache the HF model between cold starts so we measure container spin-up + model load,
# not a re-download every time (a re-download would make "cold" misleadingly huge).
model_cache = modal.Volume.from_name("hf-cache", create_if_missing=True)
CACHE_DIR = "/cache"


@app.cls(gpu="L4", volumes={CACHE_DIR: model_cache}, timeout=600)
class MuaalemSpike:
    @modal.enter()
    def load(self):
        """Runs once per cold container. This is the cost a COLD request pays."""
        import os

        os.environ["HF_HOME"] = CACHE_DIR  # pin model cache to the Volume
        from quran_muaalem import Muaalem  # noqa: F401 (import timed below)

        t0 = time.perf_counter()
        # Defaults to obadx/muaalem-model-v3_2 (the version we pinned in our research).
        self.muaalem = Muaalem(device="cuda")
        self.load_secs = time.perf_counter() - t0
        print(f"[load] model ready in {self.load_secs:.1f}s")

    @modal.method()
    def predict(self, wav_bytes: bytes, sura: int, aya: int) -> dict:
        import soundfile as sf
        import librosa
        from quran_transcript import quran_phonetizer, Aya, MoshafAttributes

        # Decode uploaded audio -> 16kHz mono float (muaalem requires 16kHz).
        wave, sr = sf.read(io.BytesIO(wav_bytes), dtype="float32")
        if wave.ndim > 1:
            wave = wave.mean(axis=1)
        if sr != 16000:
            wave = librosa.resample(wave, orig_sr=sr, target_sr=16000)

        # Reference phonemes for the target ayah (standard Hafs).
        # API confirmed by introspecting installed quran-transcript 0.5.2:
        #   whole-ayah uthmani = Aya(sura, aya).get().uthmani  (Bismillah counts as aya 1)
        #   MoshafAttributes has 5 required fields (the madd lengths below).
        uthmani_ref = Aya(sura, aya).get().uthmani
        moshaf = MoshafAttributes(
            rewaya="hafs",
            madd_monfasel_len=2,
            madd_mottasel_len=4,
            madd_mottasel_waqf=4,
            madd_aared_len=4,
        )
        ref = quran_phonetizer(uthmani_ref, moshaf, remove_spaces=True)

        t0 = time.perf_counter()
        outs = self.muaalem([wave], [ref], sampling_rate=16000)
        infer_secs = time.perf_counter() - t0

        return {
            "predicted_phonemes": outs[0].phonemes.text,
            "reference_phonemes": ref.phonemes,
            "uthmani": uthmani_ref,
            "audio_secs": round(len(wave) / 16000, 2),
            "infer_secs": round(infer_secs, 3),
            "model_load_secs": round(self.load_secs, 1),
        }


@app.local_entrypoint()
def main(audio: str, sura: int = 1, aya: int = 1):
    """Send the clip twice: first call = COLD (spins up container), second = WARM."""
    with open(audio, "rb") as f:
        wav = f.read()

    spike = MuaalemSpike()

    print("\n=== COLD call (container spin-up + model load + inference) ===")
    t0 = time.perf_counter()
    cold = spike.predict.remote(wav, sura, aya)
    cold_total = time.perf_counter() - t0

    print("\n=== WARM call (container alive, pure inference) ===")
    t0 = time.perf_counter()
    warm = spike.predict.remote(wav, sura, aya)
    warm_total = time.perf_counter() - t0

    print("\n=========== RESULTS ===========")
    print(f"audio length:        {cold['audio_secs']}s")
    print(f"model load (cold):   {cold['model_load_secs']}s")
    print(f"COLD end-to-end:     {cold_total:.2f}s   (inference {cold['infer_secs']}s)")
    print(f"WARM end-to-end:     {warm_total:.2f}s   (inference {warm['infer_secs']}s)")
    print("\n--- predicted phonemes ---")
    print(cold["predicted_phonemes"])
    print("\n--- reference phonemes ---")
    print(cold["reference_phonemes"])
    print("\n--- uthmani ---")
    print(cold["uthmani"])
    print("\nEyeball: do predicted and reference phonemes roughly match for a clean recite?")
    print("If yes -> engine works on phone audio. Note the COLD vs WARM gap -> drives architecture.")
