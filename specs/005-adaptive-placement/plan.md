---
description: "Implementation plan for Adaptive Placement (Feature 005)"
---

# Implementation Plan: Adaptive Placement

**Branch**: `005-adaptive-placement` | **Date**: 2026-06-05 | **Spec**: [./spec.md](./spec.md)

**Input**: Feature specification from `specs/005-adaptive-placement/spec.md`

## Summary

Replace the fixed 24-question linear placement (4 per CEFR level) with a two-stage
adaptive test that asks **one question at a time**, ramps difficulty based on the
running estimate, and stops as early as confidence allows (12–30 items). The user's
reported failure mode — "me puso en C1 sin saber inglés" — is caused by the current
test's high variance (2/4 = pass via guessing) and its inability to early-out on a
beginner who clearly cannot read past A1. The new algorithm:

1. Starts from an optional self-report (`never` / `some` / `lots` → 1.5 / 3.0 / 4.5
   on the 1..6 CEFR scale).
2. Each answer updates `levelEstimate` by ±0.4 (step shrinks as confidence grows).
3. Picks the next question from `clamp(round(levelEstimate) ± 1)` with rotation so
   no level is over-sampled.
4. Stops when `confidence ≥ 0.85` AND items ≥ 12, or hard-stops at 30 items.

The on-the-wire shape changes minimally: `/v1/placement/start` now returns ONE
question + `placementId` (instead of 24); a new `POST /v1/placement/answer`
streams one answer and returns either the next question or the final result.
The legacy `/v1/placement/submit` (batch) is **kept** so v1.3 clients still
work: it scores its 24 answers with the legacy fixed-bucket scorer.

No schema change. `schemaVersion` stays at **3**. `placement_results` already
stores per-level breakdown + estimatedLevel, which the new flow populates the
same way (just from fewer items per level on average).

The Settings manual-level override and `userRepo.setLevel` are already
end-to-end correct (see Research §5); we add a regression contract test to pin
that behaviour so the user's secondary complaint ("forcing A1 didn't help")
cannot regress unnoticed.

## Technical Context

**Language/Version**: TypeScript on Node.js 20 LTS (backend); Swift 5.9 / SwiftUI on macOS 14+ (app).

**Primary Dependencies**: Fastify 5, better-sqlite3, hnswlib-node, zod (backend); SwiftUI, AVFoundation, local `LessonKit` + `BackendClient` packages (app). **No new third-party deps.**

**Storage**: SQLite via better-sqlite3. `schemaVersion` stays at **3**; no migration. `placement_results` table reused as-is.

**Testing**: Vitest (backend unit + contract + integration + perf); XCTest (Swift packages + app).

**Target Platform**: macOS 14 (Sonoma) or later, Apple Silicon (arm64).

**Project Type**: Native macOS desktop app with embedded Node.js backend (web-app pattern: `backend/` + `app/`).

**Performance Goals**: Inherited — backend p95 ≤ 200 ms (already 0.45 ms for `/v1/progress`). New `/v1/placement/answer` must hold p95 ≤ 200 ms even on the longest path (30 items × hot in-memory store).

**Constraints**: Offline-capable, no telemetry, no cloud TTS. No new persistence layer. Mastery semantics unchanged from F002/F003.

**Scale/Scope**: Corpus stays at 299 CEFR-leveled words (no change). The selector now drives ONE question at a time, sampling 12–30 across the test. Estimated ~24 tasks (smaller than F003's 31 because most plumbing exists; the bulk is algorithmic).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| **I. Test-First** | Every task pairs a failing test before its impl. The algorithm gets unit tests with deterministic seeds; the routes get contract tests; the end-to-end placement → lesson flow gets one integration test. | ✅ |
| **II. Library-First** | New algorithm lives in `backend/src/lessons/adaptivePlacement.ts` behind a clean function `step(state, answer)`. No new Swift packages. Swift PlacementViewModel changes are local. | ✅ |
| **III. Simplicity & YAGNI** | No IRT, no Bayesian likelihood model — a deterministic per-level rotation with a moving estimate is enough for 6 buckets and ≤ 30 items. Justified in research.md §1. | ✅ |
| **IV. Observability** | One new structured log per item: `placement.item` with `placementId`, `position`, `selectedLevel`, `levelEstimateBefore`, `levelEstimateAfter`, `confidence`, `correct`. Final `placement.completed` log gains `algorithmVersion: 'v2'`. | ✅ |
| **V. Versioning & Breaking Changes** | Bumps `version.json` MINOR `1.3.0 → 1.4.0`. `schemaVersion` stays at 3. OpenAPI bumps to 1.4.0; adds `/v1/placement/answer` and adds the `algorithmVersion` field on the result. Old `/start` + `/submit` paths remain functional for backward compatibility with v1.3 clients in the field. | ✅ |
| **VI. Security & Privacy** | No new data collection. Self-report is a single ordinal value, kept in-memory, not stored to disk. | ✅ |
| **VII. Accessibility** | One new question screen variant ("Calibrando…" indicator). New a11y audit at `specs/005-adaptive-placement/design/a11y-audit.md` covering the self-report buttons + the in-flight progress label. | ✅ |
| **VIII. Performance Budgets** | New `placementP95.test.ts` covers the per-item endpoint. In-memory state, ≤ 30 items, no DB writes per item → expected p95 ≪ 5 ms. | ✅ |

**Gate result**: PASS. No `Complexity Tracking` entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/005-adaptive-placement/
├── plan.md                 # this file
├── research.md             # Phase 0 — algorithm, anchor, stop rules, override regression
├── data-model.md           # Phase 1 — DTO + in-memory shape (no schema change)
├── contracts/
│   └── openapi-delta.yaml  # Phase 1 — additions on top of v1.3.0
├── design/
│   └── a11y-audit.md       # Phase 2 polish (mirrors F003)
├── quickstart.md           # Phase 1 — how to test adaptive locally
├── spec.md                 # already on disk
└── tasks.md                # Phase 2 output
```

### Source Code (repository root)

Backend additions/refactors:

```text
backend/src/
├── lessons/adaptivePlacement.ts            # NEW — pure algorithm (state, step, terminate)
├── lessons/placementSelector.ts            # REFACTORED — gains pickNextQuestion(level, used, repo, seed)
├── lessons/placementScorer.ts              # KEPT — still used for legacy /submit + final report
├── routes/placement.ts                     # adds /v1/placement/answer; /start returns 1 question
└── store/placementRepository.ts            # adds algorithmVersion + itemsAdministered (optional, in-row JSON only)
                                            # (no schema change — fields go into the existing perLevelScores JSON envelope)

backend/tests/
├── unit/lessons/adaptivePlacement.test.ts  # NEW — algorithm correctness + termination
├── unit/lessons/placementSelector.test.ts  # UPDATED — pickNextQuestion contract
├── unit/lessons/placementScorer.test.ts    # UNCHANGED (legacy path still tested)
├── contract/placement.start.test.ts        # UPDATED — 1 question shape, selfReport echo
├── contract/placement.answer.test.ts       # NEW
├── contract/placement.submit.test.ts       # UPDATED — legacy path still 200s with 24 answers
├── contract/me.level.override.test.ts      # NEW — pin regression for the user's complaint
├── integration/adaptivePlacementFlow.test.ts # NEW — end-to-end ramp, then lesson starts at right level
└── perf/placementP95.test.ts               # NEW
```

App changes:

```text
app/Packages/BackendClient/Sources/BackendClient/
└── BackendClient.swift                     # +PlacementAnswerRequest/Response, +selfReport on start

app/GramartEnglish/Sources/Features/Onboarding/
├── PlacementViewModel.swift                # rewritten state machine — one Q at a time
├── PlacementQuestionView.swift             # adds "Calibrando…" badge
├── PlacementSelfReportView.swift           # NEW — 3-button anchor question
└── PlacementResultView.swift               # unchanged

app/GramartEnglish/Sources/App/
└── RootView.swift                          # OnboardingPhase: prepend .selfReport before .running

app/GramartEnglish/Tests/Unit/
├── PlacementViewModelTests.swift           # UPDATED
└── PlacementSelfReportViewTests.swift      # NEW
```

**Structure Decision**: Same F001/F002/F003 layout — backend + Swift packages + executable app. F005 only refactors existing files plus 3 new ones per side.

## Phase 0 (Research) Outcome

See [`research.md`](./research.md). Decisions resolved:

1. **Algorithm** — deterministic per-level rotation with moving estimate + sample-size confidence. No IRT, no Bayes.
2. **Self-report anchor** — 3-button onboarding question; maps to initial estimate; OPTIONAL (skippable → defaults to 3.5).
3. **Stop rules** — `confidence ≥ 0.85 AND items ≥ 12`, hard cap 30.
4. **Manual override regression** — Settings PATCH /v1/me already plumbs through; we add a pinning contract test.
5. **Telemetry** — `placement.item` log per answer; `placement.completed` already exists, gains `algorithmVersion: 'v2'`, `itemsAdministered`.
6. **Backward compat** — `/v1/placement/submit` (batch, 24 answers) kept; flagged `algorithmVersion: 'v1'`.

## Phase 1 (Design) Outcome

See [`data-model.md`](./data-model.md) and [`contracts/openapi-delta.yaml`](./contracts/openapi-delta.yaml).

- **Schema**: no change (still v3).
- **DTOs**: `PlacementStartRequest.selfReport: 'never'|'some'|'lots'|null`. `PlacementStartResponse` now returns `{ placementId, question, progress: {current, max} }` (one Q). New `PlacementAnswerRequest/Response`. Legacy `PlacementSubmitRequest/Response` untouched.
- **`placementId`** stays in-memory like before.
- **`PlacementResultResponse`** gains optional `algorithmVersion: 'v1'|'v2'`, `itemsAdministered: number`. Optional → backward compatible.

## Phase 2 (Tasks) — handled by `/speckit-tasks`

`/speckit-tasks` produces ~24 tasks in 5 phases mirroring F003:

| Phase | Scope | Approx tasks |
|---|---|---|
| 1. Setup | version bump, OpenAPI delta scaffold, BackendClient DTOs | 4 |
| 2. Foundational | Algorithm + selector refactor + tests | 6 |
| 3. US1 — Adaptive backend flow | New routes + contract tests + integration | 6 |
| 4. US2 — App self-report + one-Q-at-a-time | ViewModel + 2 views + tests | 5 |
| 5. Polish | a11y, perf bench, override regression, README, OpenAPI merge | 4 |

## Constitution Check (post-design)

Re-evaluated after writing `data-model.md` and `contracts/openapi-delta.yaml`. No
new violations. All additions are optional fields; old clients keep working.

**Final gate**: ✅ PASS.

## Complexity Tracking

None. F005 is a contained refactor: ~400 LOC new algorithm + tests, ~150 LOC client wiring. All existing F001/F002/F003 surfaces unchanged.
