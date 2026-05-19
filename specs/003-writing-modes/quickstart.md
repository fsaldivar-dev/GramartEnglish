# Feature 003 — Writing Modes: Quickstart

## TL;DR

```bash
./scripts/dev.sh                       # backend + app, fresh DB
# or — pick up where you left off
./scripts/dev.sh --keep-db
```

You should land on Home with **6 active mode cards** (up from 4 in v1.2):

📖 Leer · 👂 Escuchar (×3) · ✏️ Escribir — reconoce en inglés · ✏️ Escribir — escribe la palabra

`write_fill_gaps` is deferred to v1.4 unless v1.3 has spare capacity.

## What changed since F002

- **No schema migration.** `schemaVersion` stays at **3**.
- **No new env vars.** Spanish prompts come from the existing CEFR corpus's `spanishOption` column.
- **Two new mode cards** replace the two identical "Escribir — Próximamente" placeholders. The "Conjugar — Próximamente" card stays put pending F004.
- **OpenAPI** bumps to **1.3.0** with one additive `prompt` field and one additive `hintUsed` flag.

## How to test the new flows locally

### `write_pick_word` (US1)
1. Home → tap "Escribir — reconoce en inglés".
2. Prompt is the Spanish meaning (e.g. **clima / tiempo**); 4 option cards show English words.
3. Press `1-4` or click an option. On reveal the backend plays the canonical English word's TTS so you hear what you just identified.

### `write_type_word` (US2)
1. Home → tap "Escribir — escribe la palabra".
2. Spanish prompt + monospaced text field with autofocus.
3. Type the English word; press `↩`. Levenshtein ≤ 1 typos are accepted (`weathr` for `weather` = correct).
4. `⌘H` reveals one letter; using the hint zeroes the mastery streak for that word.
5. `⌘.` or empty submit = skip.

### Per-mode mastery
Open "Mis palabras" (top-left button on Home) to see all 6 modes with independent counts. A word can be mastered in `read_pick_meaning` and still pending in both writing modes — that's the "I recognize but can't produce" gap from SC-003.

## Rolling back

There's no migration to roll back. To revert F003:

```bash
git revert <merge-commit-of-003-writing-modes>
```

A v1.3 client running against a v1.2 backend gets a `400 invalid_payload` when starting a write lesson (the backend's zod schema rejects the new enum value) — the app surfaces this as a clear "this server is too old" error.

## Tests

```bash
# Backend
cd backend && pnpm test                                # 153+ tests after F003
pnpm run perf                                          # incl. write-mode p95

# Swift packages
cd app/Packages/LessonKit && swift test
cd app/Packages/BackendClient && swift test

# App (incl. perf benches)
cd app/GramartEnglish && swift test                    # 41+ tests after F003
```

## Known gaps for F003

- **`write_fill_gaps` (US3)** is specced but ships in v1.4. Masking logic is in `research.md` §1 if you want to land it as part of v1.3.
- **Hint history persistence**: hint usage is logged but not stored per-row in `questions`. F004 can add the column without retroactive backfill.

## Related docs

- [spec.md](./spec.md)
- [plan.md](./plan.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [contracts/openapi-delta.yaml](./contracts/openapi-delta.yaml)
- [design/a11y-audit.md](./design/a11y-audit.md) — produced during Phase 2 (tasks.md)
