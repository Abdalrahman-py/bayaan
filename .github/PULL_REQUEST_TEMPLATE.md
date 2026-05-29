## What does this PR do?

<!-- One sentence summary -->

## Module affected

- [ ] Android (`/android`)
- [ ] Backend (`/backend`)
- [ ] ML (`/ml`)
- [ ] Docs / infra (cross-module — needs lead sign-off)

> One module per PR. If this PR touches multiple modules, coordinate with the lead first.

## Target branch

- [ ] `dev` (correct target for module work)
- [ ] `main` (only for release PRs from `dev`)

## How to test

<!-- Steps for the reviewer. Use "N/A" only for pure docs/config changes. -->

## AI-assisted development checklist

- [ ] Module's `AGENTS.md` is still accurate after this change (update it if conventions changed)
- [ ] No `.env` files, API keys, or secrets committed
      Run: `git diff origin/dev | grep -iE "(api[_-]?key|secret|password|token)"`
- [ ] Changes stay within the module boundary (no cross-module edits)
- [ ] If an AI agent generated significant portions of this PR, a human teammate has reviewed it line-by-line

## Standard checklist

- [ ] Builds without errors
- [ ] Tests pass (or N/A with reason)
- [ ] Linked to an issue or task
