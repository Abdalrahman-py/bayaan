#!/usr/bin/env python3
"""Ayah → tajweed-rule tag generator (PRODUCTION_PLAN Workstream C, M1 PRD §5).

Deterministically tags curated ayat with the tajweed rules they exercise, so M7's
adaptive lesson selection has a stable contract to read from. Output:
`content/ayah_rule_tags.json`.

Real tagging calls `quranic_phonemizer` (a SEPARATE package from the `quran_transcript`
phonetizer used for grading — same-sounding names, don't conflate, per §5):

    from quranic_phonemizer import Phonemizer
    rules = Phonemizer().phonemize(uthmani_text).tajweed_mappings()   # -> [TajweedRule, ...]

That package is a heavyish ML dep and isn't required to be installed for the rest of
M1. When it's absent, `--dry-run` still emits the output *structure* (rules left empty,
`_pending: true`) so the format is concrete and M2/M7 can build the reader against it.
Run the real pass on Modal / a machine with the package before M7 (this laptop is not
the place — see the hardware constraint). No fabricated tags: dry-run never invents rules.

Output contract:
    { "version": 1,
      "generator": "quranic_phonemizer" | "dry-run-scaffold",
      "ayat": { "112:1": { "text": "...", "rules": ["MADD_TABEE", ...], "sifat": ["itbaq", ...] } } }

Usage:
    python scripts/generate_ayah_tags.py            # real run (needs quranic_phonemizer)
    python scripts/generate_ayah_tags.py --dry-run   # emit scaffold without the package
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "content" / "ayah_rule_tags.json"

# Curated seed: front-loaded ayat for Unit 7 (real Quranic words) + Unit 8 short surahs.
# Extend as those units are authored (M6). Text is Uthmani.
CURATED: dict[str, str] = {
    "112:1": "قُلْ هُوَ ٱللَّهُ أَحَدٌ",
    "112:2": "ٱللَّهُ ٱلصَّمَدُ",
    "112:3": "لَمْ يَلِدْ وَلَمْ يُولَدْ",
    "112:4": "وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ",
    "1:1": "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
}

# Sifat attributes not modeled as TajweedRule enums — static lookup (§5). The engine's
# sifat heads report these at grade time; here they document which letters carry them.
SIFAT_STATIC: dict[str, str] = {
    "ص": "itbaq", "ض": "itbaq", "ط": "itbaq", "ظ": "itbaq",  # heavy/covered
    "س": "safeer", "ز": "safeer",                              # whistling
    "ر": "tikraar",                                            # trill
    "ش": "tafashie",                                           # spreading
}


def sifat_for(text: str) -> list[str]:
    found = {SIFAT_STATIC[ch] for ch in text if ch in SIFAT_STATIC}
    return sorted(found)


def real_tagger():
    """Return a fn text -> [rule names], or None if the package isn't available."""
    try:
        from quranic_phonemizer import Phonemizer  # type: ignore
    except Exception:
        return None
    phon = Phonemizer()

    def tag(text: str) -> list[str]:
        mappings = phon.phonemize(text).tajweed_mappings()
        # tajweed_mappings() yields TajweedRule enum members; take their names, unique+sorted.
        return sorted({getattr(r, "name", str(r)) for r in mappings})

    return tag


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Generate ayah -> tajweed-rule tags.")
    ap.add_argument("--dry-run", action="store_true",
                    help="emit the scaffold (empty rules) without quranic_phonemizer")
    args = ap.parse_args(argv)

    tag = real_tagger()
    if tag is None and not args.dry_run:
        print("quranic_phonemizer not installed. Install it, or run with --dry-run to "
              "emit the scaffold. (Heavy dep — prefer Modal over this laptop.)",
              file=sys.stderr)
        return 2

    generator = "quranic_phonemizer" if tag else "dry-run-scaffold"
    ayat = {}
    for key, text in CURATED.items():
        ayat[key] = {
            "text": text,
            "rules": tag(text) if tag else [],
            "sifat": sifat_for(text),
            **({} if tag else {"_pending": True}),
        }

    OUT.write_text(
        json.dumps({"version": 1, "generator": generator, "ayat": ayat},
                   ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)} ({generator}, {len(ayat)} ayat).")
    if not tag:
        print("  ⚠ scaffold only — rules are empty pending a real quranic_phonemizer run.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
