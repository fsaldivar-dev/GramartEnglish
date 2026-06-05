# Feature 005 — Adaptive Placement: Quickstart

## TL;DR

```bash
./scripts/dev.sh                       # backend + app, fresh DB
# or
./scripts/dev.sh --keep-db
```

You should land on Welcome → tap "Empezar" → see the new **self-report screen**
("¿Has estudiado inglés antes?") with three buttons:

- **Nunca antes** → starts the test at A1/A2 boundary
- **Un poco / algunas clases** → starts at A2/B1
- **Bastante, llevo años** → starts at B1/B2
- **Empezar sin elegir** → starts at the midpoint (B1)

Then the placement test runs **one question at a time**, adapting to your
answers, finishing in 12–30 items instead of always 24.

## What changed since F003

- **No schema migration.** `schemaVersion` stays at **3**.
- **No new env vars.**
- **`/v1/placement/start`** now returns **one** question instead of 24. Legacy
  v1.3 clients still get 24 (header sniffed).
- **New `/v1/placement/answer`** endpoint: post one answer, get the next
  question or the final result.
- **`/v1/placement/submit`** untouched (legacy batch).
- **`PlacementResultResponse`** gains optional `algorithmVersion` +
  `itemsAdministered`.

## How to test the new flow locally

### Adaptive flow (US1)

1. Fresh DB: `./scripts/dev.sh`.
2. Welcome → "Empezar" → self-report appears.
3. Pick "Nunca antes". First question is around A1/A2.
4. Answer 12+ questions. Notice the progress bar shows `n / 30`.
5. Test ends when the algorithm is confident (around item 15 for a consistent
   answerer) OR after 30 items max.
6. Result screen unchanged in look, but now displays the adaptive
   `itemsAdministered` count in the breakdown.

### "Beginner who can't read C1" regression (the user's complaint)

1. Pick "Nunca antes".
2. Answer the first 4 items deliberately wrong (or pick "No lo sé" four times).
3. **Expected**: the algorithm locks at A1 by item ~6-8 (floor lock-in rule).
   Result screen shows estimatedLevel = A1.
4. **Before F005**: ~50 % chance of landing at C1 due to lucky guessing
   distribution across the 4-per-level grid.

### Manual override regression (the user's secondary complaint)

1. Finish placement. Go to Settings (gear icon).
2. Change level to A1, click "Guardar".
3. Start a lesson. **Expected**: only A1 words appear.
4. Backend log: `lesson.started` with `level: "A1"`.

This path is now covered by
`backend/tests/contract/me.level.override.test.ts` — it cannot regress without
turning the test red.

## Rolling back

There's no migration to roll back. To revert F005:

```bash
git revert <merge-commit-of-005-adaptive-placement>
```

A v1.4 client running against a v1.3 backend gets the v1.3 24-question shape
on `/start` (header is ignored by older backend). The v1.4 client falls back
to batch mode for that placement.

## Tests

```bash
# Backend
cd backend && pnpm test                                # 196+ tests after F005
pnpm run perf                                          # incl. placement adaptive p95

# Swift packages
cd app/Packages/LessonKit && swift test
cd app/Packages/BackendClient && swift test

# App
cd app/GramartEnglish && swift test
```

## Known gaps for F005

- **No new question types.** Cloze/paraphrase/grammar are still future work;
  the v1.4 release fixes the algorithm, not the item bank diversity.
- **Algorithm is deterministic** (no Bayesian posterior). Future `v3` can
  upgrade `algorithmVersion` without API churn.
- **In-memory state** — a backend restart mid-placement drops the test. Same
  as v1.3; acceptable for a single-user desktop app.

## Related docs

- [spec.md](./spec.md)
- [plan.md](./plan.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [contracts/openapi-delta.yaml](./contracts/openapi-delta.yaml)
- [design/a11y-audit.md](./design/a11y-audit.md) — produced in Polish phase
