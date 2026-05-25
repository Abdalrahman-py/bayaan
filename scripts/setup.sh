#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Require interactive terminal — this script prompts for role
[ -t 0 ] || { echo "[ERROR] This script requires an interactive terminal. Run it directly, not piped."; exit 1; }

echo ""
echo "=== Bayaan Setup ==="
echo ""

# Copy .env.example → .env if not already present
if [ ! -f "$REPO_ROOT/.env" ]; then
  if [ -f "$REPO_ROOT/.env.example" ]; then
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    echo "[OK] Copied .env.example → .env"
    echo "     Fill in your API keys before running the app."
  else
    echo "[WARN] No .env.example found. Create .env manually."
  fi
else
  echo "[OK] .env already exists."
fi

echo ""
echo "Which role are you? (enter number)"
echo "  1) Android — Issa or Osama"
echo "  2) Backend — Ramzi"
echo "  3) AI & Backend Lead — Abdalrahman"
echo "  4) ML only"
read -r -t 60 role || { echo "[ERROR] No input received within 60 seconds."; exit 1; }

echo ""
case "$role" in
  1)
    echo "=== Android Setup ==="
    echo "Open your module in Claude Code:"
    echo "  claude $REPO_ROOT/android"
    echo ""
    echo "Useful commands once inside:"
    echo "  ./gradlew build"
    echo "  ./gradlew assembleDebug"
    ;;
  2)
    echo "=== Backend Setup ==="
    echo "Open your module in Claude Code:"
    echo "  claude $REPO_ROOT/backend"
    echo ""
    echo "Useful commands once inside:"
    echo "  npm install && npm run dev"
    ;;
  3)
    echo "=== AI & Backend Lead Setup ==="
    echo "You have access to backend and ML modules."
    echo ""
    echo "Open backend:"
    echo "  claude $REPO_ROOT/backend"
    echo ""
    echo "Open ML:"
    echo "  claude $REPO_ROOT/ml"
    echo ""
    echo "ML setup:"
    echo "  cd $REPO_ROOT/ml && pip install -r requirements.txt"
    ;;
  4)
    echo "=== ML Setup ==="
    echo "Open your module in Claude Code:"
    echo "  claude $REPO_ROOT/ml"
    echo ""
    echo "Install dependencies:"
    echo "  pip install -r requirements.txt"
    ;;
  *)
    echo "[WARN] Unknown role. Open the module dir in Claude Code manually."
    ;;
esac

echo ""
echo "=== Done ==="
echo "Branch off dev before starting work:"
echo "  git checkout dev && git pull && git checkout -b <module>/<your-feature>"
echo ""
