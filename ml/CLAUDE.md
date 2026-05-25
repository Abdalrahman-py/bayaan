# ML Module — AI Context

## What This Module Is

The Bayaan Tajweed classification pipeline. Takes phoneme sequences extracted from user recitation audio and outputs Tajweed rule violations (Madd, Ghunnah, Qalqalah, Ikhfa, etc.) with per-rule confidence scores. Built on wav2vec2 (HuggingFace) fine-tuned on labelled Arabic recitation audio.

---

## Owner

| Name | Role |
|------|------|
| Abdalrahman | AI & Backend Lead |

---

## Tech Stack

- **Language:** Python 3.11+
- **Framework:** PyTorch
- **Model base:** wav2vec2 (HuggingFace `transformers`)
- **Dependencies:** `requirements.txt` is the single source of truth — always install from it
- **Data:** training/validation audio datasets (gitignored if large; see Data Policy below)

---

## Directory Structure

```
ml/
├── data/          — Training and validation data (gitignored if >50MB)
├── requirements.txt
└── CLAUDE.md      — This file
```

---

## Skills to Invoke

When working in this module, invoke these skills via the Skill tool if available:
- `everything-claude-code:pytorch-patterns` — PyTorch training and inference patterns

If the skill is not available, follow PyTorch best practices manually:
- Use `DataLoader` with `num_workers` for training data
- Avoid in-place operations on tensors that require grad
- Pin model to device explicitly: `model.to(device)`
- Use `torch.no_grad()` for inference
- Save checkpoints with `torch.save(model.state_dict(), path)`, not the full model object

---

## Safe Commands

These commands are auto-approved by the team's `.claude/settings.json`:

```bash
pip install -r requirements.txt
python -m pytest
python train.py
```

---

## Data Policy

- Datasets larger than 50MB must **not** be committed to git.
- Use `.gitignore` entries or Git LFS for large data files.
- Document dataset location, version, and download instructions in `data/README.md`.
- Never commit audio recordings of real users.

---

## Branch Convention

- Branch off: `dev`
- Branch name: `ml/<experiment-or-feature>` (e.g., `ml/wav2vec2-finetune-v2`)
- PR targets: `dev`

## PR Title Format

```
feat(ml): <description>
experiment(ml): <description>
fix(ml): <description>
```

---

## HARD BOUNDARY

**This AI session operates ONLY within the `/ml` directory.**

Do not read, write, or suggest changes to `/android`, `/backend`, `/docs`, `/design`, root config files (`CLAUDE.md`, `.claude/`, `.gitignore`, `.github/`), or any other directory outside `/ml`.

If the user asks you to edit files outside `/ml`, refuse and say: "This session is scoped to the `/ml` module. Open a separate Claude Code session in the target module directory to make those changes."
