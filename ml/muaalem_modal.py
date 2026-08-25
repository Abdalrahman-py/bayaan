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
Endpoints:
  POST {url}/correct     (multipart: audio + sura + aya + optional madd lengths)
  POST {url}/grade-text  (multipart: audio + reference_text + optional madd lengths)

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

from fastapi import Form, UploadFile

# Mirrors the spike image (that build already succeeded). fastapi[standard] is
# needed for @modal.fastapi_endpoint to accept multipart uploads.
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "libsndfile1")
    .pip_install(
        # Pinned deliberately: quran-muaalem/quran-transcript are single-maintainer
        # and define the error/sifat schema the backend parser depends on — an
        # unpinned upstream release could silently change it on the next cold build.
        # diff-match-patch is used directly (see _correct) but only ships transitively
        # via quran-muaalem, so pin it explicitly. Bump these deliberately, re-verify
        # the /correct response shape, then update. (S1/M1: docs/decisions/grading-tiers.md)
        "quran-muaalem==0.1.0",
        "quran-transcript==0.5.2",
        "diff-match-patch==20241021",
        "librosa==0.11.0",
        "soundfile==0.14.0",
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

        # Upstream bug (quran-muaalem 0.1.0, decode.py align_predicted_sequence):
        # the m == 0 branch returns ONE list instead of a (ids, mask) tuple, so the
        # caller's 2-target unpack raises "ValueError: too many values to unpack".
        # Fires when a sifat level decodes to an empty sequence — data-dependent,
        # which is why the spike clips never hit it. Patch: return the aligned
        # placeholder list plus an all-False mask (nothing predicted = nothing
        # matches), matching the shape of every other return path.
        import quran_muaalem.decode as _decode_mod

        _orig_align = _decode_mod.align_predicted_sequence

        def _align_predicted_sequence_fixed(ref, predicted, missing_placeholder=-100):
            n, m = len(ref), len(predicted)
            if n == m:
                return predicted, [True] * n
            if m == 0:
                return [missing_placeholder] * n, [False] * n
            return _orig_align(ref, predicted, missing_placeholder)

        _decode_mod.align_predicted_sequence = _align_predicted_sequence_fixed
        # Only call site is decode.py:506, which resolves via module globals —
        # patching the module attribute is sufficient.

        t0 = time.perf_counter()
        self.model = _Muaalem(device="cuda")
        print(f"[load] muaalem ready in {time.perf_counter() - t0:.1f}s")

    def _decode_wave(self, wav_bytes):
        """Decode upload -> 16kHz mono float32 (model requirement)."""
        import librosa
        import soundfile as sf

        wave, sr = sf.read(io.BytesIO(wav_bytes), dtype="float32")
        if wave.ndim > 1:
            wave = wave.mean(axis=1)
        if sr != 16000:
            wave = librosa.resample(wave, orig_sr=sr, target_sr=16000)
        return wave

    def _sifat_errors(self, outs0, ref, predicted):
        """Letter-characteristic mismatches vs reference (same shape as /correct)."""
        import diff_match_patch as dmp_module
        from quran_muaalem.explain import expalin_sifat

        _dmp = dmp_module.diff_match_patch()
        _diffs = _dmp.diff_main(ref.phonemes, predicted)
        _sifat_table = expalin_sifat(outs0.sifat, ref.sifat, _diffs)
        _pred_by_group = {s.phonemes_group: s for s in outs0.sifat}
        _SIFAT_KEYS = (
            "hams_or_jahr", "shidda_or_rakhawa", "tafkheem_or_taqeeq",
            "itbaq", "safeer", "qalqla", "tikraar", "tafashie", "istitala", "ghonna",
        )

        def _sifa_str(v):
            if v is None:
                return None
            return v.value if hasattr(v, "value") else str(v)

        sifat_errors = []
        for row in _sifat_table:
            if row.get("tag") == "insert":
                continue
            ph = row["phonemes"]
            pred_obj = _pred_by_group.get(ph)
            for key in _SIFAT_KEYS:
                pred_val = row.get(key)
                exp_val = _sifa_str(row.get(f"exp_{key}"))
                if not pred_val or pred_val == "None" or exp_val is None:
                    continue
                if pred_val == exp_val:
                    continue
                confidence = None
                if pred_obj:
                    unit = getattr(pred_obj, key, None)
                    if unit is not None:
                        confidence = round(float(unit.prob), 3)
                sifat_errors.append({
                    "phonemes_group": ph,
                    "attribute": key,
                    "predicted": pred_val,
                    "expected": exp_val,
                    "confidence": confidence,
                })
        return sifat_errors

    def _grade_against_text(self, wav_bytes, uthmani, madd):
        """Core Path-A grading: arbitrary Uthmani reference (ayah or syllable/word).

        Same phonetizer + explain_error + sifat heads as /correct. Used by both the
        ayah endpoint and /grade-text (M3 echo exercises — see Spike S1 / Path A).
        """
        import dataclasses
        import json

        from quran_transcript import quran_phonetizer, explain_error
        from quran_transcript.phonetics.moshaf_attributes import MoshafAttributes

        wave = self._decode_wave(wav_bytes)
        moshaf = MoshafAttributes(rewaya="hafs", **madd)
        ref = quran_phonetizer(uthmani, moshaf, remove_spaces=True)

        t0 = time.perf_counter()
        outs = self.model([wave], [ref], sampling_rate=16000)
        infer_secs = time.perf_counter() - t0

        predicted = outs[0].phonemes.text
        errors = explain_error(uthmani, ref.phonemes, predicted, ref.mappings)

        def _enc(o):
            if isinstance(o, set):
                return sorted(o)
            return str(o)

        errors_json = json.loads(
            json.dumps([dataclasses.asdict(e) for e in errors], default=_enc)
        )
        sifat_errors = self._sifat_errors(outs[0], ref, predicted)

        return {
            "reference_text": uthmani,
            "reference_phonemes": ref.phonemes,
            "predicted_phonemes": predicted,
            "errors": errors_json,
            "sifat_errors": sifat_errors,
            "error_count": len(errors_json),
            "sifat_error_count": len(sifat_errors),
            "all_correct": len(errors_json) == 0 and len(sifat_errors) == 0,
            "audio_secs": round(len(wave) / 16000, 2),
            "infer_secs": round(infer_secs, 3),
        }

    def _correct(self, wav_bytes, sura, aya, madd):
        """Pure logic: audio bytes + ayah -> structured errors. No HTTP here."""
        from quran_transcript import Aya

        # Reference for the target ayah (Hafs). Bismillah counts as aya 1.
        uthmani = Aya(sura, aya).get().uthmani
        result = self._grade_against_text(wav_bytes, uthmani, madd)
        # Keep the /correct response shape (sura/aya/uthmani fields) the backend
        # parser already depends on; grade-text returns reference_text instead.
        return {
            "sura": sura,
            "aya": aya,
            "uthmani": uthmani,
            "errors": result["errors"],
            "sifat_errors": result["sifat_errors"],
            "error_count": result["error_count"],
            "all_correct": len(result["errors"]) == 0,
            "audio_secs": result["audio_secs"],
            "infer_secs": result["infer_secs"],
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

    @modal.fastapi_endpoint(method="POST", docs=True)
    async def grade_text(
        self,
        audio: UploadFile,
        reference_text: str = Form(""),
        madd_monfasel_len: int = Form(2),
        madd_mottasel_len: int = Form(4),
        madd_mottasel_waqf: int = Form(4),
        madd_aared_len: int = Form(4),
    ):
        """POST multipart: `audio` + `reference_text` (arbitrary Uthmani).

        M3 Path A endpoint for echo / syllable grading. Production of Ktor's
        POST /speech/grade. Content pipeline enforces madd-/sukoon-final targets
        (see docs/decisions/grading-tiers.md) — this endpoint does not re-validate.

        Decode crashes (multilevel_greedy_decode RuntimeError on rare short clips)
        return a structured body so the backend can map them to verdict=retry,
        never a 500.
        """
        from fastapi.responses import JSONResponse

        def fail(status, code, msg):
            return JSONResponse(status_code=status, content={"error": code, "message": msg})

        wav_bytes = await audio.read()
        if not wav_bytes:
            return fail(422, "unprocessable_audio", "Empty audio.")
        text = (reference_text or "").strip()
        if not text:
            return fail(400, "bad_request", "missing reference_text")
        # Hard length guard for lesson clips — backend also caps upload size.
        if len(text) > 64:
            return fail(400, "bad_request", "reference_text too long for grade-text")

        madd = dict(
            madd_monfasel_len=madd_monfasel_len,
            madd_mottasel_len=madd_mottasel_len,
            madd_mottasel_waqf=madd_mottasel_waqf,
            madd_aared_len=madd_aared_len,
        )
        try:
            return self._grade_against_text(wav_bytes, text, madd)
        except RuntimeError as e:
            # Known upstream decode bug on some short clips (Spike S1 1/43). Ktor maps
            # decode_failed -> verdict:retry rather than surfacing a 5xx.
            return fail(422, "decode_failed", f"RuntimeError: {e}")
        except Exception as e:
            return fail(422, "unprocessable_audio", f"{type(e).__name__}: {e}")
