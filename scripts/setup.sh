#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "=== Bayaan Setup ==="
echo ""

if [ ! -f "$REPO_ROOT/.env" ] && [ -f "$REPO_ROOT/.env.example" ]; then
  cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
  echo "[OK] Copied .env.example -> .env — fill in the Supabase keys before running the backend."
else
  echo "[OK] .env already exists or no template found."
fi

echo ""
echo "Pick what you're working on:"
echo "  Android  -> open android/ in Android Studio, read android/AGENTS.md, run ./gradlew build"
echo "  Backend  -> cd backend && ./gradlew run (reads backend/AGENTS.md)"
echo "  ML       -> cd ml && python -m venv .venv && pip install -r requirements.txt (reads ml/AGENTS.md)"
echo ""
echo "Project-wide rules: $REPO_ROOT/AGENTS.md"
echo "Single branch: main. No module branches, no PR requirement."
echo ""
echo "=== Done ==="
echo ""
