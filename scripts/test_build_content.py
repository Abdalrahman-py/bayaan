#!/usr/bin/env python3
"""Runnable check for build_content.py — no test framework, just asserts.

Proves the M1 acceptance: a clean tree passes; a deliberately-broken reference
fails with a specific pointer. Copies content/ to a temp dir so the real tree is
never touched. Run: python scripts/test_build_content.py
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "build_content.py"


def run(content_dir: Path) -> subprocess.CompletedProcess:
    env = {**os.environ, "BAYAAN_CONTENT_DIR": str(content_dir)}
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--out", str(content_dir / "dist")],
        capture_output=True, text=True, env=env,
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        content = Path(tmp) / "content"
        shutil.copytree(ROOT / "content", content)

        # 1. Baseline: the real content passes.
        base = run(content)
        assert base.returncode == 0, f"clean content should pass, got:\n{base.stderr}"
        print("✓ clean content passes (exit 0)")

        # 2. Waqf break: point an ECHO reference at a bare short-vowel final.
        lesson = content / "lessons" / "ar.1.1.json"
        data = json.loads(lesson.read_text(encoding="utf-8"))
        echo = next(i for i in data["items"] if i["type"] == "ECHO")
        echo["reference_text"] = "بَ"  # fatha-final → waqf-unsafe
        lesson.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        broken = run(content)
        assert broken.returncode != 0, "waqf-unsafe reference must fail the build"
        assert echo["item_ref"] in broken.stderr and "waqf" in broken.stderr.lower(), \
            f"failure must point at the item_ref + reason, got:\n{broken.stderr}"
        print(f"✓ waqf-unsafe reference fails with pointer ({echo['item_ref']})")

        # 3. Structural break: answer not among options.
        shutil.rmtree(content)
        shutil.copytree(ROOT / "content", content)
        lesson = content / "lessons" / "ar.1.1.json"
        data = json.loads(lesson.read_text(encoding="utf-8"))
        pick = next(i for i in data["items"] if i["type"] == "LISTEN_PICK")
        pick["answer"] = "ز"  # not in options
        lesson.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        broken = run(content)
        assert broken.returncode != 0, "answer-not-in-options must fail"
        assert pick["item_ref"] in broken.stderr, f"must point at item, got:\n{broken.stderr}"
        print(f"✓ answer-not-in-options fails with pointer ({pick['item_ref']})")

    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
