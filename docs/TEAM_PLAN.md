# Bayaan — Team Plan (Arabic track build-out)

> Written 2026-07-06. This is the delegation layer on top of
> [`PRODUCTION_PLAN.md`](./PRODUCTION_PLAN.md) (the *what*) — this file is the *who*.
> Each workstream below has its own assignment sheet in [`workstreams/`](./workstreams/).
> The production plan was written for a solo dev; this plan re-slices it for the team.
> Where they disagree on sequencing, this file wins.

## Roles

| Person | Workstream | Sheet |
|---|---|---|
| **Issa** | Android: app shell (M0), then lesson player (M2) | [ws-android-shell.md](./workstreams/ws-android-shell.md), [ws-lesson-player.md](./workstreams/ws-lesson-player.md) |
| **Osama** | Android: lesson player exercises with Issa (M2), then mic/voice UX (M3 client side) | [ws-lesson-player.md](./workstreams/ws-lesson-player.md) |
| **Ramzi** | Backend + tooling: content pipeline engineering (M1), learn backend (M4), `/speech/grade` (M3 server side) | [ws-content-pipeline.md](./workstreams/ws-content-pipeline.md), [ws-learn-backend.md](./workstreams/ws-learn-backend.md) |
| **Abdalrahman** | Product owner / reviewer — not a builder on these workstreams | this file, §Reviewer duties |

If Osama is unavailable (unconfirmed since kickoff), Issa absorbs M2 solo and M3
client work shifts after M2 — nothing else changes.

## The two contracts (freeze these first — everything parallelizes after)

1. **Content schema** — `content/curriculum.json` + per-lesson JSON shape
   (M1 PRD, [`specs/m1-content-pipeline.md`](./specs/m1-content-pipeline.md) P0 #1).
   Producer: Ramzi. Consumers: lesson player (M2), content authoring.
   Freeze = schema file + `content/README.md` merged; after that, changes need
   Abdalrahman's sign-off.
2. **`/speech/grade` response shape** — already specified in
   `PRODUCTION_PLAN.md` §3.3/§9: `{verdict, score, phoneme_issues[], feedback_key}`.
   Producer: Ramzi. Consumer: M2/M3 client. The grading behavior behind it is
   **decided** — see [`decisions/grading-tiers.md`](./decisions/grading-tiers.md)
   (Path A, edge-insertion tolerance, crash→retry). Do not re-litigate.

## Sequence

```
Week 0:  Issa → M0 shell          Ramzi → schema draft + build_content.py skeleton
         (parallel, no deps)       Abdalrahman → approves schema (contract 1 frozen)
Week 1+: Issa/Osama → M2 player   Ramzi → validator, packer, rule-tag script,
         against frozen schema             then /speech/grade (contract 2)
                                   Content authoring (agent-generated) → Abdalrahman
                                   reviews per unit, content freezes unit by unit
Then:    M3 wiring (Osama client + Ramzi server) → M4 learn backend (Ramzi)
```

## Working model

- Branch per workstream chunk, PR to `main`, **Abdalrahman reviews every PR**
  (CODEOWNERS: android lines activate once Issa/Osama hand in GitHub handles —
  currently commented out, see `.github/CODEOWNERS`).
- Every module has an `AGENTS.md` — read yours before touching anything; AI
  agents (Claude Code) are expected tooling here, see `scripts/setup.sh` for the
  per-role command.
- Acceptance criteria are NOT in this file — each workstream sheet quotes its
  acceptance list from `PRODUCTION_PLAN.md` §10. A workstream is done when its
  acceptance list is green **on a real device**, not when it compiles.

## Reviewer duties (Abdalrahman — the non-delegable ~3 hrs/week)

1. Approve the content schema once (contract 1).
2. Review each authored curriculum unit before it freezes (~1–2 hrs/unit —
   tajweed/pedagogy correctness; this is the product's credibility).
3. Review PRs (CODEOWNERS routes them anyway).
4. Unblock decisions. Everything decided so far is written down: grading tiers
   (`decisions/grading-tiers.md`), curriculum design (`PRODUCTION_PLAN.md` §4),
   UI law (`android/UI_SPEC.md`). A teammate should only need you for something
   *not* in those files.
5. Line up the ~250 human-recorded letter clips (qari or self — longest lead
   item, start now; TTS placeholders unblock the pipeline meanwhile).

## Out of scope for everyone (deferred, don't creep)

`PRODUCTION_PLAN.md` §13: memorization mode, roleplay, streaming ASR, Edge
Functions migration, remote content updates, iOS, social, paywall.
