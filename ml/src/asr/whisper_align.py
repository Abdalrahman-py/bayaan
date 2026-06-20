"""Quran-fine-tuned Whisper transcription with word-level timestamps.

Principle: Whisper is the ONLY aligner. Word-level timestamps are sufficient
for both Class A (transcript comparison) and Class B (clip extraction).

Default backend = Groq API (fast). Set GROQ_API_KEY in the environment.
Returns: {"text": str, "words": [{"word": str, "start": float, "end": float}, ...]}
"""
from __future__ import annotations

import os
from pathlib import Path


def transcribe_words(
    audio_path: str | Path,
    model: str = "whisper-large-v3",
    language: str = "ar",
    api_key: str | None = None,
) -> dict:
    """Transcribe via Groq Whisper and return word-level timestamps."""
    from groq import Groq

    key = api_key or os.environ.get("GROQ_API_KEY")
    if not key:
        raise RuntimeError(
            "GROQ_API_KEY not set. Export it, or pass api_key=..., "
            "or use a local HF model instead."
        )
    client = Groq(api_key=key)
    with open(audio_path, "rb") as f:
        resp = client.audio.transcriptions.create(
            file=(Path(audio_path).name, f.read()),
            model=model,
            language=language,
            response_format="verbose_json",
            timestamp_granularities=["word"],
        )
    words = [
        {"word": w["word"], "start": float(w["start"]), "end": float(w["end"])}
        for w in (getattr(resp, "words", None) or [])
    ]
    return {"text": getattr(resp, "text", ""), "words": words}


_LOCAL_PIPE = None


def transcribe_words_local(
    audio,
    model: str = "openai/whisper-small",
    language: str = "arabic",
    device: str | None = None,
):
    """Local Whisper transcription (no API key / ffmpeg needed).

    `audio` is a 16 kHz mono float32 numpy array (or a path). Returns the same
    shape as transcribe_words: {"text", "words":[{word,start,end}]}.
    The pipeline is cached across calls so the model loads once.
    """
    global _LOCAL_PIPE
    import numpy as np
    import torch
    from transformers import pipeline

    if _LOCAL_PIPE is None:
        dev = 0 if (device != "cpu" and torch.cuda.is_available()) else -1
        _LOCAL_PIPE = pipeline(
            "automatic-speech-recognition", model=model, device=dev,
            return_timestamps="word",
        )
    inp = audio if isinstance(audio, str) else {
        "raw": np.asarray(audio, dtype=np.float32), "sampling_rate": 16_000,
    }
    out = _LOCAL_PIPE(inp, generate_kwargs={"language": language, "task": "transcribe"})
    words = []
    for ch in out.get("chunks", []) or []:
        ts = ch.get("timestamp") or (None, None)
        words.append({"word": (ch.get("text") or "").strip(),
                      "start": ts[0], "end": ts[1]})
    return {"text": (out.get("text") or "").strip(), "words": words}


def clip_for_position(
    waveform, start_ms: int | None, end_ms: int | None, sample_rate: int = 16_000,
    pad_ms: int = 100,
):
    """Slice a waveform around a word's timing for a Class B classifier.

    Falls back to the whole clip when timing is missing.
    """
    import numpy as np

    if start_ms is None or end_ms is None:
        return waveform
    a = max(0, int((start_ms - pad_ms) / 1000 * sample_rate))
    b = min(len(waveform), int((end_ms + pad_ms) / 1000 * sample_rate))
    seg = waveform[a:b]
    return seg if len(seg) > 0 else np.asarray(waveform)
