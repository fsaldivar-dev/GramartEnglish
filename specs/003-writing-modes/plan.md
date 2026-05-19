---
description: "Implementation plan for Writing Modes (Feature 003)"
---

# Implementation Plan: Writing Modes

**Branch**: `003-writing-modes` | **Date**: 2026-05-19 | **Spec**: [./spec.md](./spec.md)

**Input**: Feature specification from `specs/003-writing-modes/spec.md`

## Summary

Active-recall lesson modes that reverse the read flow: prompt is the Spanish meaning, answer is the English word. Three sub-modes ship as part of this feature:

1. **`write_pick_word`** (US1, P1) — 4 option cards in English; "smallest jump" reuse of the F001 option UI.
2. **`write_type_word`** (US2, P2) — text input; reuses the entire `TypedAnswerInputView` built in F002 for `listen_type`, including the Levenshtein-1 typo tolerance.
3. **`write_fill_gaps`** (US3, P3) — scaffolded production with vowels-first gaps. Optional for this release; can ship in v1.4 if v1.3 lands cleanly.

No new tables, no migration. The per-mode mastery axis (`word_mastery.(userId, wordId, mode)`) added in F002's migration 0003 already supports this feature unchanged. The only schema-adjacent change is one optional DTO field on `LessonQuestion`: `prompt: String?` carrying the Spanish meaning when the playing mode renders it directly.

## Technical Context

**Language/Version**: TypeScript on Node.js 20 LTS (backend); Swift 5.9 / SwiftUI on macOS 14+ (app).

**Primary Dependencies**: Fastify 5, better-sqlite3, hnswlib-node, zod (backend); SwiftUI, AVFoundation, local `LessonKit` + `BackendClient` packages (app).

**Storage**: SQLite via better-sqlite3. `schemaVersion` stays at **3**; no migration. The DB lives at `~/Library/Application Support/GramartEnglish/app.db` for the bundled app, `.gramart/app.db` for dev.

**Testing**: Vitest (backend unit + contract + integration + perf); XCTest (Swift packages + app).

**Target Platform**: macOS 14 (Sonoma) or later, Apple Silicon (arm64). Distributed as a self-contained `.app` bundle (~78 MB) with embedded Node + bundled corpus.

**Project Type**: Native macOS desktop application with an embedded Node.js backend (web-app pattern: `backend/` + `app/`).

**Performance Goals**: Inherited from F001/F002 budgets — cold launch ≤ 2 s, lesson screen transition ≤ 150 ms, backend p95 ≤ 200 ms (already 0.45 ms for `/v1/progress`), no regression on existing modes.

**Constraints**: Offline-capable, no telemetry, no cloud TTS. New Spanish prompt rendering MUST NOT add a CoreData / new persistence layer. Mastery semantics unchanged from F002 (2 consecutive corrects = mastered; hint usage on `write_type_word` disables mastery credit for that question per FR-009).

**Scale/Scope**: Corpus stays at 299 CEFR-leveled words (no change). Active modes go from 4 → **6 shipped** + 1 deferred + 1 reserved for F004. Estimated tasks ~28 (smaller than F002's 63 because most of the infrastructure is already there).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| **I. Test-First** | Each task pairs a failing test before its impl. Vitest for backend, XCTest for app. Test plan in `tasks.md` mirrors F002 structure (unit → contract → integration → perf). | ✅ |
| **II. Library-First** | No new Swift packages. Reuse `LessonKit` (`LessonMode`, `Levenshtein`), `BackendClient` (typed-answer flow), `TypedAnswerInputView` from F002. New code lives behind existing module boundaries. | ✅ |
| **III. Simplicity & YAGNI** | No new abstractions. `distractorBuilder.optionTextFor` gains 3 cases; same `switch` style as F002. `LessonQuestion` DTO gains 1 optional field (`prompt`). Defer `write_fill_gaps` to v1.4 if the gap rendering grows beyond ~50 LOC. | ✅ |
| **IV. Observability** | No new endpoints. The existing correlation-ID propagation through `POST /v1/lessons` + `/answers` covers writing modes too. Existing `lesson.started`, `lesson.answered` log events apply unchanged. | ✅ |
| **V. Versioning & Breaking Changes** | Bumps `version.json` MINOR `1.2.0 → 1.3.0` (new modes, no breaking changes). `schemaVersion` stays at 3. OpenAPI version bumps to 1.3.0; only additions (3 enum values + 1 optional field). Backward compatible — F002 clients still work. | ✅ |
| **VI. Security & Privacy** | No new data collection. Typed answers are scored and discarded (already the F002 contract). No external network. | ✅ |
| **VII. Accessibility** | `TypedAnswerInputView` already audited in F002's a11y audit. New work: audit the Spanish-prompt rendering (font scaling, VoiceOver label) and the differentiated subtitles on the two "Escribir" mode cards. New a11y audit doc at `specs/003-writing-modes/design/a11y-audit.md`. | ✅ |
| **VIII. Performance Budgets** | Same budgets. Add 1 perf bench: `write_pick_word` lesson-start p95 (must stay ≤ 200 ms). No new hot paths. | ✅ |

**Gate result**: PASS. No `Complexity Tracking` entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/003-writing-modes/
├── plan.md                 # this file (Phase 0 + 1 + 2 outline)
├── research.md             # Phase 0 — gap-pattern decision, hint accounting, prompt field
├── data-model.md           # Phase 1 — DTO delta (no schema change)
├── contracts/
│   └── openapi-delta.yaml  # Phase 1 — additions on top of v1.2.0
├── design/
│   └── a11y-audit.md       # Phase 2 polish, mirrors F002's audit format
├── quickstart.md           # Phase 1 — how to test write modes locally
└── tasks.md                # Phase 2 output (/speckit-tasks command)
```

### Source Code (repository root)

Backend additions:

```text
backend/src/
├── domain/schemas.ts                    # +3 LessonMode enum values
├── lessons/distractorBuilder.ts         # +3 cases in optionTextFor
├── lessons/lessonService.ts             # prompt assembly when mode is write_*
└── routes/lessons.ts                    # no change (typedAnswer flow already exists)

backend/tests/
├── unit/lessons/distractorBuilder.write.test.ts        # NEW
├── contract/lessons.start.write.test.ts                # NEW
├── integration/writePickWord.test.ts                   # NEW
├── integration/writeTypeWord.test.ts                   # NEW
└── perf/writeP95.test.ts                               # NEW
```

App additions:

```text
app/GramartEnglish/Sources/Features/Lesson/
├── WritingLessonView.swift              # NEW — Spanish prompt + options OR text field
└── LessonViewModel.swift                # passes prompt through state

app/GramartEnglish/Sources/App/
└── RootView.swift                       # one more case in questionView() dispatcher

app/Packages/LessonKit/Sources/LessonKit/
└── LessonMode.swift                     # promote 2 write modes from ComingSoonMode to LessonMode

app/GramartEnglish/Tests/Unit/
├── WritingLessonViewTests.swift                  # NEW
└── WritingLessonViewModelTests.swift             # NEW (for the prompt-passing path)
```

**Structure Decision**: Continue the F001/F002 layout — backend + Swift packages + executable app. No new top-level packages; F003 adds files to the existing directory tree only.

## Phase 0 (Research) Outcome

See [`research.md`](./research.md). Three decisions resolved:

1. **`write_fill_gaps` gap pattern** — vowels-first, then weak consonants (h/y/w), preserve first letter; gap ratio caps at 50%. See research.md §1.
2. **Hint button mastery accounting** — using a hint zeroes `consecutiveCorrect` for that word but still records a `correct` outcome with a `hintUsed: true` flag for analytics. SC-004 reads from this flag. See research.md §2.
3. **`prompt` field placement** — extend `LessonQuestion` DTO with optional `prompt: string`. Backend populates it for write modes; client falls back to existing rendering when absent. See research.md §3.

## Phase 1 (Design) Outcome

See [`data-model.md`](./data-model.md) and [`contracts/openapi-delta.yaml`](./contracts/openapi-delta.yaml).

- **Schema**: no change (still v3).
- **DTO**: `LessonQuestion.prompt: string?` and `AnswerLessonRequest.hintUsed: boolean?` added.
- **Enum**: `LessonMode` gains `write_pick_word`, `write_type_word`, `write_fill_gaps` (last is shipped placeholder for v1.4 if deferred).
- **`SHIPPED_MODES`**: 4 → 6 (or 7 if US3 lands).

## Phase 2 (Tasks) — handled by `/speckit-tasks`

`/speckit-tasks` will produce ~28 tasks in 5 phases mirroring F002:

| Phase | Scope | Approx tasks |
|---|---|---|
| 1. Setup | Enum + `LessonMode` promotion + version bump | 5 |
| 2. Foundational | Backend: prompt assembly, distractor cases, contract tests | 8 |
| 3. US1 — `write_pick_word` | View, ViewModel wiring, integration tests | 6 |
| 4. US2 — `write_type_word` | View variant, integration tests, FR-007/FR-009 paths | 6 |
| 5. Polish | a11y audit, perf bench, README, OpenAPI merge | 3 |
| (US3 deferred unless cap allows) | `write_fill_gaps` view + gap logic | +5 |

## Constitution Check (post-design)

Re-evaluated after writing `data-model.md` and `contracts/openapi-delta.yaml`. No new violations introduced. The new `prompt` and `hintUsed` fields are both **optional** so older v1.2 clients keep working — Principle V holds.

**Final gate**: ✅ PASS.

## Complexity Tracking

None. F003 is a low-complexity extension; everything reuses F001/F002 infrastructure.
