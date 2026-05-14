# Feature 002 — Listening Modes: Quickstart

## TL;DR

```bash
./scripts/dev.sh            # backend (fresh DB) + app
# or
./scripts/dev.sh --keep-db  # preserve previous mastery
./scripts/dev.sh app <port> # launch only the app against an already-running backend
```

You should land on a Home screen with a 2×3 grid: 4 enabled mode cards + 2 grayed-out "Próximamente" cards. The card tagged "Recomendado para ti" for a brand-new user is **Escuchar — Escucha y elige la palabra** (`listen_pick_word`).

## What changed since F001

- **Schema v3** (migration 0003). `word_mastery` now keys on `(userId, wordId, mode)`. F001 mastery rows were migrated with `mode = 'read_pick_meaning'`.
- **No new env vars.** Listening modes use the local `AVSpeechSynthesizer` — no extra dependencies, no Ollama call for L1/L2/L3, no network.
- **TTS only.** Ollama is still optional (only used by the example-sentences feature from F001).

## How to test the new flows locally

### `listen_pick_word`
1. Home → tap the "Escuchar — Escucha y elige la palabra" card.
2. Audio plays automatically. Press `S` to repeat.
3. Pick the matching English word from the 4 cards. Press `1`–`4` or click.
4. On reveal the canonical word is re-spoken after 250 ms.

### `listen_pick_meaning`
Same flow, but options are Spanish translations. The reveal still re-speaks the English word so you reinforce the audio-to-meaning link.

### `listen_type`
1. Pick the "Escuchar — Escucha y escribe" card.
2. Field is auto-focused, monospaced, autocorrect off.
3. Type the word and press `↩`. Typos within Levenshtein distance 1 (e.g. `wether` → `weather`) are accepted as correct — the reveal shows your input struck through under the canonical spelling.
4. `H` reveals the next letter (cumulative). `0` skips.

### Per-mode mastery
- Home → click **Mis palabras** (top-left) to see all 4 modes side by side.
- The post-lesson summary also shows the 4-mode badge strip with the current mode highlighted.

## Rolling back to v2 (F001 only)

```bash
cd backend
pnpm run db:rollback 2
```

The rollback **discards all non-read mastery rows** and rebuilds `word_mastery` with the F001 PK shape. Take a copy of `~/.gramart/app.db` first if you want to preserve listening progress.

## Tests

```bash
# Backend (vitest)
cd backend && pnpm test

# Backend perf benches (includes new GET /v1/progress p95 bench)
pnpm run perf

# Swift packages
cd app/Packages/LessonKit    && swift test
cd app/Packages/BackendClient && swift test

# Swift app (includes mode-card render bench + audio first-token bench)
cd app/GramartEnglish && swift test
```

To actually hear audio during the audio-latency bench (skipped by default in CI):

```bash
cd app/GramartEnglish && GRAMART_PERF_AUDIO=1 swift test --filter AudioLatencyTests
```

## Known a11y gaps (F002)

The biggest known limitation: there is **no on-screen caption track** for the listening modes yet, so a hearing-impaired user without VoiceOver cannot use them. See [design/a11y-audit.md](./design/a11y-audit.md) for the full list and the F003 follow-up plan.

## Related docs

- [spec.md](./spec.md) — what F002 is and why
- [plan.md](./plan.md) — how we built it
- [data-model.md](./data-model.md) — migration 0003 details
- [contracts/openapi-delta.yaml](./contracts/openapi-delta.yaml) — wire-level additions
- [design/a11y-audit.md](./design/a11y-audit.md) — accessibility audit
- [research.md](./research.md) — design decisions (Levenshtein impl, recommender heuristic, audio caching, mode icons, reveal UX)
