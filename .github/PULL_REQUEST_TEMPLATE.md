## What does this PR do?

<!-- One sentence summary -->

## Module affected

- [ ] Android (`/android`)
- [ ] Backend (`/backend`)
- [ ] ML (`/ml`)
- [ ] Docs / infra

## How to test

<!-- Steps for the reviewer. Use "N/A" only for pure docs/config changes. -->

## Checklist

- [ ] Module's `AGENTS.md` is still accurate after this change (update it if conventions changed)
- [ ] No `.env` files, API keys, or secrets committed
      Run: `git diff origin/main | grep -iE "(api[_-]?key|secret|password|token)"`
- [ ] Builds without errors
- [ ] Tests pass (or N/A with reason)
