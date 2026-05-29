#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -t 0 ] || { echo "[ERROR] This script requires an interactive terminal. Run it directly, not piped."; exit 1; }

echo ""
echo "=== Bayaan Setup ==="
echo ""

# Copy .env.example -> .env if not already present
if [ ! -f "$REPO_ROOT/.env" ]; then
  if [ -f "$REPO_ROOT/.env.example" ]; then
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    echo "[OK] Copied .env.example -> .env"
    echo "     Fill in your API keys before running the app."
  else
    echo "[WARN] No .env.example found. Create .env manually."
  fi
else
  echo "[OK] .env already exists."
fi

echo ""
echo "Which module are you working in? (enter number)"
echo "  1) Android (Issa, Osama)"
echo "  2) Backend (Ramzi, Abdalrahman)"
echo "  3) ML (Abdalrahman)"
echo "  4) Multiple / lead (Abdalrahman)"
read -r -t 60 role || { echo "[ERROR] No input received within 60 seconds."; exit 1; }

MODULE_DIR=""
BRANCH=""

echo ""
case "$role" in
  1)
    MODULE_DIR="$REPO_ROOT/android"
    BRANCH="android"
    echo "=== Android setup ==="
    echo ""
    echo "1. Open this folder in your IDE or AI agent:"
    echo "     $MODULE_DIR"
    echo ""
    echo "   Recommended IDE: Android Studio (Ladybug or later)."
    echo "   With an AI agent: open $MODULE_DIR in Cursor / Claude Code / Codex / etc."
    echo "   The agent will read android/AGENTS.md automatically."
    echo ""
    echo "2. Useful commands once inside the folder:"
    echo "     ./gradlew build"
    echo "     ./gradlew assembleDebug"
    ;;
  2)
    MODULE_DIR="$REPO_ROOT/backend"
    BRANCH="backend"
    echo "=== Backend setup ==="
    echo ""
    echo "1. Open this folder in your IDE or AI agent:"
    echo "     $MODULE_DIR"
    echo ""
    echo "   Recommended IDE: IntelliJ IDEA (best Ktor support)."
    echo ""
    echo "2. Useful commands once inside the folder:"
    echo "     ./gradlew build"
    echo "     ./gradlew run"
    ;;
  3)
    MODULE_DIR="$REPO_ROOT/ml"
    BRANCH="ml"
    echo "=== ML setup ==="
    echo ""
    echo "1. Open this folder in your IDE or AI agent:"
    echo "     $MODULE_DIR"
    echo ""
    echo "2. Set up the Python environment:"
    echo "     cd $MODULE_DIR"
    echo "     python -m venv .venv"
    echo "     source .venv/bin/activate   # Windows: .venv\\Scripts\\activate"
    echo "     pip install -r requirements.txt"
    echo ""
    echo "   For training: use the shared Kaggle workspace (P100 GPU)."
    ;;
  4)
    echo "=== Lead setup (multi-module) ==="
    echo ""
    echo "You have access to backend and ML. Open each module folder separately"
    echo "in your IDE/agent so module boundaries stay clean."
    echo ""
    echo "  Backend: $REPO_ROOT/backend"
    echo "  ML:      $REPO_ROOT/ml"
    ;;
  *)
    echo "[WARN] Unknown choice. Open your module folder manually."
    ;;
esac

echo ""
echo "=== Branch ==="
if [ -n "$BRANCH" ]; then
  echo "Your team's long-lived branch is: $BRANCH"
  echo ""
  echo "Switch to it before working:"
  echo "  git checkout $BRANCH"
  echo "  git pull origin $BRANCH"
  echo ""
  echo "Commit and push to that branch directly. When ready to integrate"
  echo "with other modules, open a PR from $BRANCH -> dev. Never PR to main directly."
else
  echo "Module branches: android, backend, ml. Pick the one matching your work."
fi

echo ""
echo "=== Read AGENTS.md ==="
echo "Project-wide rules:  $REPO_ROOT/AGENTS.md"
if [ -n "$MODULE_DIR" ]; then
  echo "Module-specific:     $MODULE_DIR/AGENTS.md"
fi
echo ""
echo "=== Done ==="
echo ""
