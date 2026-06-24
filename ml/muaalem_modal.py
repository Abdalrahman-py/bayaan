"""
Deployed Modal service for the Bayaan recitation engine (quran-muaalem).

This is the productionised version of spike/modal_muaalem_spike.py. The spike
answered "does it work / how fast" with throwaway `modal run` code that printed
raw phonemes. This file is the real, *deployed* HTTP endpoint the backend calls:

    audio + sura/aya  ->  Muaalem model  ->  structured tajweed error diff (JSON)

The error diff is the same logic the upstream `/correct-recitation` endpoint uses
(quran_transcript.quran_phonetizer + explain_error). We call those two functions
directly instead of importing the upstream FastAPI `app.serve` module, because that
module spins up its own two-server stack (engine on :8000, app on :8001, httpx
between them). We run the model in-process, so we only need the diff functions.

Deploy:   modal deploy ml/muaalem_modal.py
Local:    modal serve  ml/muaalem_modal.py     (hot-reloads, gives a temp URL)
Endpoint: POST {url}/correct   (multipart: audio file + sura + aya + error params)

Cold vs warm (see docs/quran-muaalem-decision.md):
  - Default = scale to zero: $0 idle, but ~24s cold start on the first call.
  - For a live demo, pin one container warm right before going on stage:
      modal deploy ml/muaalem_modal.py     then in the dashboard (or via
      `min_containers=1` below) keep 1 alive, and scale back to 0 after.
  - `scaledown_window` keeps the container alive a few minutes after the last
    request, so back-to-back demo runs all hit the ~1.7s warm path.
"""

import io
import time

import modal
from fastapi import UploadFile

# Mirrors the spike image (that build already succeeded). fastapi[standard] is
# needed for @modal.fastapi_endpoint to accept multipart uploads.
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "libsndfile1")
    .pip_install(
        "quran-muaalem",
        "quran-transcript",
        "librosa",
        "soundfile",
        "numba>=0.61.2",
        "fastapi[standard]",
    )
)

app = modal.App("bayaan-muaalem", image=image)

# Same HF cache Volume as the spike, so the model isn't re-downloaded on cold start.
model_cache = modal.Volume.from_name("hf-cache", create_if_missing=True)
CACHE_DIR = "/cache"


@app.cls(
    gpu="L4",
    volumes={CACHE_DIR: model_cache},
    timeout=600,
    # Keep a hot container for 5 min after the last call: back-to-back demo runs
    # stay on the warm path. For a guaranteed-warm stage demo, also set
    # min_containers=1 (costs continuously while pinned — scale back to 0 after).
    scaledown_window=300,
    # min_containers=1,   # uncomment just before a live demo, re-comment after
)
class Muaalem:
    @modal.enter()
    def load(self):
        """Runs once per cold container — this is the cost a COLD request pays."""
        import os

        os.environ["HF_HOME"] = CACHE_DIR
        from quran_muaalem import Muaalem as _Muaalem

        t0 = time.perf_counter()
        self.model = _Muaalem(device="cuda")
        print(f"[load] muaalem ready in {time.perf_counter() - t0:.1f}s")

    def _correct(self, wav_bytes, sura, aya, madd):
        """Pure logic: audio bytes + ayah -> structured errors. No HTTP here."""
        import dataclasses

        import librosa
        import soundfile as sf
        from quran_transcript import Aya, quran_phonetizer, explain_error
        from quran_transcript.phonetics.moshaf_attributes import MoshafAttributes

        # Decode upload -> 16kHz mono float32 (the model requires 16kHz).
        wave, sr = sf.read(io.BytesIO(wav_bytes), dtype="float32")
        if wave.ndim > 1:
            wave = wave.mean(axis=1)
        if sr != 16000:
            wave = librosa.resample(wave, orig_sr=sr, target_sr=16000)

        # Reference for the target ayah (Hafs). Bismillah counts as aya 1.
        uthmani = Aya(sura, aya).get().uthmani
        moshaf = MoshafAttributes(rewaya="hafs", **madd)
        ref = quran_phonetizer(uthmani, moshaf, remove_spaces=True)

        t0 = time.perf_counter()
        outs = self.model([wave], [ref], sampling_rate=16000)
        infer_secs = time.perf_counter() - t0

        predicted = outs[0].phonemes.text
        errors = explain_error(uthmani, ref.phonemes, predicted, ref.mappings)

        # ReciterError is a dataclass; tajweed-rule fields are sets -> list-ify.
        def _enc(o):
            if isinstance(o, set):
                return sorted(o)
            return str(o)

        import json

        errors_json = json.loads(
            json.dumps([dataclasses.asdict(e) for e in errors], default=_enc)
        )
        return {
            "sura": sura,
            "aya": aya,
            "uthmani": uthmani,
            "errors": errors_json,
            "error_count": len(errors_json),
            "all_correct": len(errors_json) == 0,
            "audio_secs": round(len(wave) / 16000, 2),
            "infer_secs": round(infer_secs, 3),
        }

    @modal.fastapi_endpoint(method="POST", docs=True)
    async def correct(
        self,
        audio: UploadFile,
        sura: int = 1,
        aya: int = 1,
        madd_monfasel_len: int = 2,
        madd_mottasel_len: int = 4,
        madd_mottasel_waqf: int = 4,
        madd_aared_len: int = 4,
    ):
        """POST multipart: `audio` file + sura/aya (+ optional madd lengths)."""
        from fastapi.responses import JSONResponse

        def fail(status, code, msg):
            return JSONResponse(status_code=status, content={"error": code, "message": msg})

        wav_bytes = await audio.read()
        if not wav_bytes:
            return fail(422, "unprocessable_audio", "Empty audio.")
        # Validate sura/aya at the boundary: an out-of-range verse otherwise makes
        # the quran-transcript lookup throw and FastAPI return a 500 + non-JSON body.
        if not (1 <= sura <= 114) or aya < 1:
            return fail(400, "bad_request", f"invalid sura/aya: {sura}:{aya}")
        madd = dict(
            madd_monfasel_len=madd_monfasel_len,
            madd_mottasel_len=madd_mottasel_len,
            madd_mottasel_waqf=madd_mottasel_waqf,
            madd_aared_len=madd_aared_len,
        )
        try:
            return self._correct(wav_bytes, sura, aya, madd)
        except Exception as e:
            # Any failure in the pipeline (aya beyond the surah's verse count ->
            # AssertionError, undecodable audio, model error) becomes a structured
            # 422 instead of a 500 + non-JSON body the caller can't parse.
            return fail(422, "unprocessable_audio", f"{type(e).__name__}: {e}")
