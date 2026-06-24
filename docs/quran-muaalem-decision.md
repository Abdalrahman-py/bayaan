# Quran engine: decision + spike results (2026-06-23)

## Decision
Use `obadx/quran-muaalem` as the recitation-checking engine instead of training our own. It already detects recitation and tajweed errors accurately, it's MIT-licensed, and its maintainer offered to help. Our work is the app around it, not the model.

## What the app does (MVP)
One loop: pick an ayah → record → the engine flags mistakes → show them on the script → try again. Plain programmatic feedback first (no AI-written explanations yet). Surahs: Al-Fatihah and Al-Bayyinah.

Left for later: accounts, lessons, the Arabic-proficiency stage, spoken feedback.

## Spike: does it work, is it fast?
Ran the engine on a Modal cloud GPU with a real phone recording of Al-Fatihah ayah 2.

| Measure | Time |
|---|---|
| Model inference only | 0.064s |
| Warm request, end to end | 1.74s |
| Cold request, end to end | 24.4s |

It read the recitation correctly and matched the reference, differing only on one madd length — exactly the kind of mistake we want it to catch.

## The one limitation: cold start
The GPU sleeps when unused (so it costs nothing idle). The first request after it sleeps takes ~24s to wake. Every request after that is fast (~1.7s).

Plan: wake the GPU when the user opens the record screen, so it's ready by the time they finish reciting. In production, keep one instance always on.

## Cost
A few cents per run, inside the free tier.

## Next step
A backend slice that records audio, uploads it, and stores it — needed both for the app and for collecting recitation recordings from children at local mosques.
