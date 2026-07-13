#!/usr/bin/env python3
"""Bayaan content pipeline — validate, asset-check, and pack the Arabic-track content.

M1 (docs/specs/m1-content-pipeline.md). Zero third-party deps: a bad lesson file
fails *here*, on your machine, with a precise pointer — never a silent gap on-device.

What it does:
  1. Validates content/curriculum.json + every referenced lessons/*.json against the
     schema (schema/*.json is the human contract; the checks below are the enforcer).
  2. Enforces the waqf convention from docs/decisions/grading-tiers.md: every ECHO /
     READ_ALOUD_SYLLABLE reference_text must be madd- or sukoon-final (never a bare
     short vowel), because Muaalem's phonetizer applies stop rules word-finally.
  3. Walks every audio reference. A missing *lesson file* is always a hard failure
     (real dangling ref). A missing *audio asset* is "pending" (letter clips are a
     human recording dependency, TTS awaits the S4 voice pick) — a warning by
     default, a hard failure under --strict (for CI once audio lands).
  4. Emits the Android asset pack (--out, default content/dist/) + tts_manifest.json.
     Deterministic: unchanged content re-packs to an identical build_manifest hash.

Usage:
  python scripts/build_content.py                 # validate + pack (pending audio ok)
  python scripts/build_content.py --strict         # dangling audio is a hard failure
  python scripts/build_content.py --list-assets     # print every required audio clip
  python scripts/build_content.py --out <dir>       # pack destination
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Content root is overridable (BAYAAN_CONTENT_DIR) so the test harness can validate a
# deliberately-broken copy without touching the real tree.
CONTENT = Path(os.environ.get("BAYAAN_CONTENT_DIR", ROOT / "content"))
AUDIO_ROOT = CONTENT / "audio"

RECOGNITION_TYPES = {"LISTEN_PICK", "READ_PICK", "DISCRIMINATE", "ODD_ONE_OUT"}
ECHO_TYPES = {"ECHO", "READ_ALOUD_SYLLABLE"}
ALL_TYPES = RECOGNITION_TYPES | ECHO_TYPES

# Bare short-vowel / tanween / shadda finals — the waqf-unsafe endings. A reference
# ending in any of these gets its final vowel dropped by the phonetizer and would
# false-flag a correct learner (grading-tiers.md §"Reference convention mismatch").
UNSAFE_FINAL = {
    "ً",  # fathatan
    "ٌ",  # dammatan
    "ٍ",  # kasratan
    "َ",  # fatha
    "ُ",  # damma
    "ِ",  # kasra
    "ّ",  # shadda
}


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    authored: list[str] = field(default_factory=list)
    stubs: list[str] = field(default_factory=list)
    assets_needed: set[str] = field(default_factory=set)
    assets_pending: set[str] = field(default_factory=set)
    narrations: dict[str, str] = field(default_factory=dict)  # sha1 -> text

    def err(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")


def _rel(path: Path) -> str:
    """Path shown in errors — relative to the content root's parent, temp-copy safe."""
    try:
        return str(path.relative_to(CONTENT.parent))
    except ValueError:
        return str(path)


def load_json(path: Path, rep: Report) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        rep.err(_rel(path), "file not found")
    except json.JSONDecodeError as e:
        rep.err(f"{_rel(path)}:{e.lineno}", f"invalid JSON: {e.msg}")
    return None


def waqf_safe(reference_text: str) -> bool:
    """True unless the reference ends in a bare short vowel / tanween / shadda."""
    s = reference_text.strip()
    if not s:
        return False
    return s[-1] not in UNSAFE_FINAL


def validate_item(item: dict, lesson_id: str, seen_refs: set[str], rep: Report) -> None:
    where = lesson_id
    ref = item.get("item_ref")
    if not ref or not isinstance(ref, str):
        rep.err(where, "item missing string 'item_ref'")
        return
    where = ref
    if not ref.startswith(lesson_id + "."):
        rep.err(where, f"item_ref must be prefixed with '{lesson_id}.'")
    if ref in seen_refs:
        rep.err(where, "duplicate item_ref")
    seen_refs.add(ref)

    itype = item.get("type")
    if itype not in ALL_TYPES:
        rep.err(where, f"unknown type {itype!r}; expected one of {sorted(ALL_TYPES)}")
        return

    tier = item.get("grading_tier")
    if tier not in (0, 1, 2):
        rep.err(where, f"grading_tier must be 0|1|2, got {tier!r}")
    if itype in RECOGNITION_TYPES and tier != 0:
        rep.err(where, f"{itype} is recognition-only; grading_tier must be 0")
    if itype in ECHO_TYPES and tier not in (1, 2):
        rep.err(where, f"{itype} is a spoken item; grading_tier must be 1 or 2")

    # Audio prompt (optional for echo, required for the recognition types that play a sound).
    prompt_asset = item.get("prompt_asset")
    if itype in {"LISTEN_PICK", "DISCRIMINATE"} and not prompt_asset:
        rep.err(where, f"{itype} requires a 'prompt_asset' (the sound to identify)")
    if prompt_asset is not None:
        _register_asset(prompt_asset, where, rep)

    if itype in RECOGNITION_TYPES:
        options = item.get("options")
        answer = item.get("answer")
        if not isinstance(options, list) or len(options) < 2:
            rep.err(where, "recognition item needs 'options' (>= 2)")
        elif answer is None or answer == "":
            rep.err(where, "recognition item needs a non-empty 'answer'")
        elif answer not in options:
            rep.err(where, f"'answer' {answer!r} is not among 'options'")
        if itype == "READ_PICK":
            # options are audio clips the learner chooses between
            for opt in options or []:
                _register_asset(opt, where, rep)
            if not item.get("prompt_text_ar"):
                rep.err(where, "READ_PICK requires 'prompt_text_ar' (the letter shown)")

    if itype in ECHO_TYPES:
        rt = item.get("reference_text")
        if not rt or not isinstance(rt, str):
            rep.err(where, f"{itype} requires a non-empty 'reference_text'")
        elif not waqf_safe(rt):
            rep.err(where, f"reference_text {rt!r} is waqf-unsafe (bare short-vowel final); "
                           "use a madd- or sukoon-final target (grading-tiers.md §1)")


def _register_asset(asset: str, where: str, rep: Report) -> None:
    if not isinstance(asset, str) or not asset or asset.startswith("/") or ".." in asset:
        rep.err(where, f"bad asset path {asset!r}")
        return
    if not asset.endswith(".ogg"):
        rep.err(where, f"asset {asset!r} must be a .ogg under content/audio/")
        return
    rep.assets_needed.add(asset)


def validate_lesson(path: Path, expected: dict, rep: Report) -> None:
    data = load_json(path, rep)
    if data is None:
        return
    where = _rel(path)
    lid = data.get("lesson_id")
    if lid != expected["lesson_id"]:
        rep.err(where, f"lesson_id {lid!r} != curriculum id {expected['lesson_id']!r}")
        lid = expected["lesson_id"]
    if data.get("is_checkpoint") != expected["is_checkpoint"]:
        rep.err(where, f"is_checkpoint disagrees with curriculum ({expected['is_checkpoint']})")
    for f in ("unit_id", "title_en", "title_ar"):
        if not data.get(f):
            rep.err(where, f"missing '{f}'")

    items = data.get("items")
    is_stub = bool(data.get("stub"))
    if is_stub:
        rep.stubs.append(lid)
        if items:
            rep.err(where, "stub lesson must have zero items")
        return

    if not isinstance(items, list) or len(items) == 0:
        rep.err(where, "authored lesson needs a non-empty 'items' array (or mark \"stub\": true)")
        return

    teach = data.get("teach")
    if not isinstance(teach, dict) or not teach.get("narration_en"):
        rep.err(where, "authored lesson needs teach.narration_en (the tutor line)")
    elif teach.get("narration_en"):
        text = teach["narration_en"].strip()
        rep.narrations[hashlib.sha1(text.encode()).hexdigest()[:16]] = text

    seen: set[str] = set()
    for item in items:
        validate_item(item, lid, seen, rep)
    rep.authored.append(lid)


def validate_curriculum(rep: Report) -> list[dict]:
    """Returns the flat list of {lesson_id, is_checkpoint, path} to validate."""
    cur = load_json(CONTENT / "curriculum.json", rep)
    if cur is None:
        return []
    if cur.get("version") != 1:
        rep.err("curriculum.json", f"unexpected version {cur.get('version')!r}")
    lessons: list[dict] = []
    seen_units, seen_lessons = set(), set()
    for unit in cur.get("units", []):
        uid = unit.get("unit_id")
        if not uid or uid in seen_units:
            rep.err("curriculum.json", f"missing/duplicate unit_id {uid!r}")
        seen_units.add(uid)
        if unit.get("track") not in ("arabic", "tajweed"):
            rep.err("curriculum.json", f"{uid}: track must be arabic|tajweed")
        for lesson in unit.get("lessons", []):
            lid = lesson.get("lesson_id")
            if not lid or lid in seen_lessons:
                rep.err("curriculum.json", f"missing/duplicate lesson_id {lid!r}")
            seen_lessons.add(lid)
            lessons.append({
                "lesson_id": lid,
                "is_checkpoint": bool(lesson.get("is_checkpoint")),
                "path": CONTENT / "lessons" / f"{lid}.json",
            })
    return lessons


def check_assets(rep: Report, strict: bool) -> None:
    for asset in sorted(rep.assets_needed):
        if not (AUDIO_ROOT / asset).exists():
            rep.assets_pending.add(asset)
    if rep.assets_pending:
        msg = (f"{len(rep.assets_pending)} audio asset(s) not yet recorded/generated "
               f"(see docs/content/letter-audio-checklist.md)")
        if strict:
            for a in sorted(rep.assets_pending):
                rep.err("audio", f"missing asset: {a}")
        else:
            rep.warnings.append(msg)


def pack(rep: Report, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "lessons").mkdir(exist_ok=True)
    shutil.copy2(CONTENT / "curriculum.json", out_dir / "curriculum.json")
    for lid in sorted(rep.authored + rep.stubs):
        src = CONTENT / "lessons" / f"{lid}.json"
        if src.exists():
            shutil.copy2(src, out_dir / "lessons" / f"{lid}.json")

    # TTS manifest: teach lines keyed by content hash (sha stem). status = present|pending.
    tts = {
        h: {
            "text": text,
            "asset": f"tts/{h}.ogg",
            "status": "present" if (AUDIO_ROOT / f"tts/{h}.ogg").exists() else "pending",
        }
        for h, text in sorted(rep.narrations.items())
    }
    (out_dir / "tts_manifest.json").write_text(
        json.dumps(tts, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")

    # Deterministic build hash over the packed content (idempotency check).
    hasher = hashlib.sha256()
    for f in sorted(out_dir.rglob("*.json")):
        if f.name == "build_manifest.json":
            continue
        hasher.update(f.read_bytes())
    manifest = {
        "content_version": 1,
        "authored_lessons": sorted(rep.authored),
        "stub_lessons": sorted(rep.stubs),
        "assets_required": sorted(rep.assets_needed),
        "assets_pending": sorted(rep.assets_pending),
        "build_hash": hasher.hexdigest(),
    }
    (out_dir / "build_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Validate + pack Bayaan content.")
    ap.add_argument("--strict", action="store_true", help="treat pending audio as an error")
    ap.add_argument("--list-assets", action="store_true", help="print required audio clips and exit")
    ap.add_argument("--out", default=str(CONTENT / "dist"), help="pack destination")
    args = ap.parse_args(argv)

    rep = Report()
    lessons = validate_curriculum(rep)
    for entry in lessons:
        validate_lesson(entry["path"], entry, rep)
    check_assets(rep, strict=args.strict)

    if args.list_assets:
        for a in sorted(rep.assets_needed):
            print(a)
        return 0

    if rep.errors:
        print(f"FAIL — {len(rep.errors)} error(s):", file=sys.stderr)
        for e in rep.errors:
            print(f"  ✗ {e}", file=sys.stderr)
        return 1

    pack(rep, Path(args.out))
    print(f"OK — {len(rep.authored)} authored lesson(s), {len(rep.stubs)} stub(s), "
          f"{len(rep.assets_needed)} asset(s) required "
          f"({len(rep.assets_pending)} pending).")
    for w in rep.warnings:
        print(f"  ⚠ {w}")
    print(f"Packed → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
