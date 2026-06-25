# ML Module — Agent Instructions

You are working in the ML module of Bayaan. Read this file fully before making changes. For project-wide rules, see [`../AGENTS.md`](../AGENTS.md).

---

## What this module is

This module hosts the deployment script for Bayaan's recitation-analysis engine — a pretrained, off-the-shelf model, not something trained in this repo. There is no training code here currently; data collection, wav2vec2 fine-tuning, ONNX export, and the rest of the original training plan never happened and have been dropped.

The deployed service is [`muaalem_modal.py`](./muaalem_modal.py), running on Modal (serverless GPU). The de-risking spike that proved this approach out lives in [`../spike/`](../spike/).

---

## Owner

Solo project — Abdalrahman (@Abdalrahman-py).

---

## Tech stack

- **Language:** Python 3.11+
- **Deployment platform:** [Modal](https://modal.com) — serverless GPU, scale-to-zero
- **Dependencies:** `requirements.txt`

---

## Local setup

```bash
cd ml
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install modal
modal token new      # one-time, opens browser
```

---

## How to do the work

**Deploying a change:**
```bash
modal deploy ml/muaalem_modal.py
```

**Gotcha — verifying a deploy actually took effect:** the app keeps a warm container alive for several minutes after the last request (`scaledown_window`), and every request resets that timer. A plain `modal deploy` does **not** replace an already-warm container, so you can hit old code and think your fix didn't land. Force fresh containers before verifying a change:

```bash
modal app stop bayaan-muaalem && modal deploy ml/muaalem_modal.py
```

The next request after that cold-starts (tens of seconds) on the new code.

For a live demo, pin a warm instance with `min_containers=1` so users don't eat the cold start.

---

## Boundaries

You may modify files inside `/ml/`. For changes to `/android/`, `/backend/`, `/docs/`, or root config, say so and let the user decide — there's no other team member to hand off to, so this is a heads-up, not a refusal.

You may read `/backend/src/main/kotlin/com/bayaan/Routing.kt` to confirm the request/response shape the backend expects from the engine.

---

## Trusted commands

```bash
pip install -r requirements.txt
modal deploy ml/muaalem_modal.py
modal app stop bayaan-muaalem
```

---

## Common pitfalls

- **Thinking a deploy failed because of the warm-container gotcha above** — always `modal app stop` before re-testing a code change.
- **Forgetting the cold-start cost in UX decisions** — the app's "uploading/analyzing" state exists specifically to cover this.
