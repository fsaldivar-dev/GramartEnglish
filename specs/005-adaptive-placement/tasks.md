---
description: "Task list for Adaptive Placement (Feature 005)"
---

# Tasks: Adaptive Placement

**Input**: Design documents from `specs/005-adaptive-placement/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/openapi-delta.yaml](./contracts/openapi-delta.yaml)

**Tests**: REQUIRED (Constitution Principle I — Test-First, NON-NEGOTIABLE).

**Organization**: Grouped by user story. F005 ships **US1 (adaptive backend) + US2 (app self-report + one-Q UI)** in v1.4.0.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 Bump `version.json` to `1.4.0` (`schemaVersion` stays at 3 — no migration in F005).
- [ ] T002 [P] Extend `PlacementStartRequest` zod in `backend/src/routes/placement.ts` with optional `selfReport: z.enum(['never','some','lots']).nullish()`.
- [ ] T003 [P] Extend Swift `BackendClient.PlacementStartRequest` in `app/Packages/BackendClient/Sources/BackendClient/BackendClient.swift` with `let selfReport: String?` (Codable optional). Add new `PlacementAnswerRequest` / `PlacementAnswerResponse` (continue/done union) DTOs.
- [ ] T004 [P] Add `algorithmVersion: String?` + `itemsAdministered: Int?` to Swift `BackendClient.PlacementResultResponse` (optional, back-compat).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Pure algorithm + selector refactor. Tests precede implementation.

### Tests

- [ ] T005 [P] Vitest `backend/tests/unit/lessons/adaptivePlacement.test.ts` — covers `initialEstimateFor(selfReport)`, `step(state, correct)` monotonicity, `pickNextLevel(state)` rotation across [-1, 0, +1] window with attempted-count tiebreak, terminator rules (confidence ≥ 0.85 ∧ items ≥ 12, hard cap 30, floor lock-in 4 A1 misses → A1, ceiling lock-in 4 C2 hits at ≥ 12 → C2).
- [ ] T006 [P] Vitest `backend/tests/unit/lessons/placementSelector.test.ts` — updated for the new `pickQuestionForLevel(repo, level, usedWordIds, seed)` single-item selector. The legacy `selectPlacementQuestions` (24 questions) stays exported for the legacy /submit path; its tests stay green.

### Implementation

- [ ] T007 [P] Implement `backend/src/lessons/adaptivePlacement.ts` exporting `createState(selfReport)`, `pickNextLevel`, `step`, `done`, `finalize` per `research.md` §1+§3.
- [ ] T008 Extend `backend/src/lessons/placementSelector.ts` with `pickQuestionForLevel(repo, level, usedWordIds, seed?)`. Reuses the existing distractor logic but for a single target word at a chosen level. Old `selectPlacementQuestions` stays for /submit.

**Checkpoint**: Algorithm is unit-tested and deterministic. No HTTP yet.

---

## Phase 3: User Story 1 — Adaptive backend flow (Priority: P1)

**Story goal**: A v1.4 client can POST `/v1/placement/start` (with optional
selfReport), receive one question + placementId, POST `/v1/placement/answer`
N times, and get a result. The v1.3 batch path keeps working.

### Tests

- [ ] T009 [P] [US1] Vitest contract test `backend/tests/contract/placement.start.test.ts` updated — when `x-client-version: 1.4` is set, the response is `{ placementId, question, progress: {current:1, max:30}, algorithmVersion: 'v2' }`. Legacy path (no header) still returns 24 questions. selfReport echo validated.
- [ ] T010 [P] [US1] Vitest contract test `backend/tests/contract/placement.answer.test.ts` — happy path (answer → continue), terminal path (answer → done with PlacementResultResponse), 404 for unknown placementId, 400 for malformed payload, -1 optionIndex recorded as miss.
- [ ] T011 [P] [US1] Vitest contract test `backend/tests/contract/placement.submit.test.ts` updated — legacy 24-answer batch still 200s and writes `algorithmVersion: 'v1'` to the persisted JSON envelope.
- [ ] T012 [P] [US1] Vitest integration test `backend/tests/integration/adaptivePlacementFlow.test.ts` — fixed-seed run with selfReport='never' AND deterministic all-wrong answers ends at A1 in ≤ 8 items (floor lock-in); same seed with all-right answers from selfReport='lots' ends at C2.
- [ ] T013 [P] [US1] Vitest contract regression test `backend/tests/contract/me.level.override.test.ts` — POST /v1/lessons {level:A2} → assert words returned are A2; PATCH /v1/me {currentLevel:A1} → POST /v1/lessons (no level body) → assert words are A1. Pins the user's "forcing A1 didn't help" complaint.

### Implementation

- [ ] T014 [US1] Rewrite `backend/src/routes/placement.ts`:
  - `/start`: branch on `x-client-version` header — legacy keeps the 24-question path; adaptive (1.4+) creates an `InFlightPlacement` with `algorithmVersion: 'v2'`, initializes state from `selfReport`, picks first question via `pickNextLevel` + `pickQuestionForLevel`, and returns single-question response.
  - `/answer` (NEW): looks up placementId, scores the question (find the served `PlacementQuestion` in `delivered[]` by id), updates `state.perLevel`, calls `step(state, correct)`, logs `placement.item`, then either returns the next question (calling `pickNextLevel`+`pickQuestionForLevel` again) or finalizes (writes the `placement_results` row with `_meta` envelope, logs `placement.completed`).
  - `/submit` (legacy): keeps current behaviour; on success, persists with `algorithmVersion: 'v1'` envelope.
- [ ] T015 [US1] Extend `backend/src/store/placementRepository.ts` decode/encode to round-trip the `_meta` sentinel inside `perLevelScores` without breaking existing reads (filter `_meta` out of typed maps; hydrate `algorithmVersion` + `itemsAdministered` from it).

**Checkpoint**: All backend contract + integration + override tests green. The v1.4 server speaks adaptive to a v1.4 client and legacy to a v1.3 client.

---

## Phase 4: User Story 2 — App self-report + one-Q-at-a-time (Priority: P2)

**Story goal**: Mac app sends `x-client-version: 1.4`, shows the self-report
screen, then drives the placement one question at a time using the new
`/answer` endpoint. Result screen unchanged in look.

### Tests

- [ ] T016 [P] [US2] XCTest `app/GramartEnglish/Tests/Unit/PlacementSelfReportViewTests.swift` — renders three buttons + skip button, calls `onPick(.never|.some|.lots|nil)` on tap.
- [ ] T017 [P] [US2] XCTest `app/GramartEnglish/Tests/Unit/PlacementViewModelTests.swift` updated — new state machine (`.selfReport`, `.loading`, `.question(current, max, q)`, `.submitting`, `.finished`, `.failed`); `answer(_:)` calls `BackendClient.answerPlacement` and either advances to the next `.question` or transitions to `.finished`. Mock the client with a tiny in-process stub.

### Implementation

- [ ] T018 [US2] Add `func answerPlacement(placementId:questionId:optionIndex:)` to `BackendClient` in `app/Packages/BackendClient/Sources/BackendClient/BackendClient.swift`. Also add the `X-Client-Version: 1.4` header to every placement-related request.
- [ ] T019 [US2] Add `PlacementSelfReportView.swift` at `app/GramartEnglish/Sources/Features/Onboarding/PlacementSelfReportView.swift` — three big buttons + a tertiary "Empezar sin elegir".
- [ ] T020 [US2] Rewrite `app/GramartEnglish/Sources/Features/Onboarding/PlacementViewModel.swift` state machine per T017. `start(selfReport:)` sends the new request, stores `placementId`, advances to `.question`. `answer(_:)` posts /answer and dispatches on `kind`.
- [ ] T021 [US2] Update `app/GramartEnglish/Sources/App/RootView.swift` `OnboardingPhase` to insert `.selfReport` before `.running`, wire the picked value into `vm.start(selfReport:)`.

**Checkpoint**: End-to-end adaptive placement works in the app. Demoable.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [ ] T022 [P] Accessibility audit at `specs/005-adaptive-placement/design/a11y-audit.md` — covers self-report buttons (VoiceOver labels, 44pt min-tap, keyboard shortcuts 1/2/3/0), the "Calibrando…" badge during the test (announced once), and the progress label `Pregunta X de hasta 30`.
- [ ] T023 [P] Backend perf bench `backend/perf/placementP95.test.ts` — `POST /v1/placement/answer` p95 ≤ 200 ms over a 30-item run on the in-memory store (expected ≪ 5 ms).
- [ ] T024 Merge `specs/005-adaptive-placement/contracts/openapi-delta.yaml` into canonical `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml`; bump `info.version` to `1.4.0`. Mark the delta MERGED with a banner.
- [ ] T025 Update repo `README.md` "What's new" — add a short blurb on the adaptive placement and link to the spec.

---

## Dependencies

```text
Phase 1 (Setup)         ──┐
                          ▼
Phase 2 (Foundational) ───┴──▶  Phase 3 (US1 backend adaptive)
                                       │
                                       ▼
                                Phase 4 (US2 app self-report + 1-Q UI)
                                       │
                                       ▼
                                Phase 5 (Polish)
```

## Implementation strategy

1. **MVP slice**: Phase 1 → 2 → 3. At this point a curl-driven adaptive run works end-to-end against the backend.
2. **Layer in US2**: app self-report screen + new state machine + /answer call.
3. **Polish**: a11y, perf bench, OpenAPI merge, README.
4. **Release**: bump `v1.4.0` tag → triggers the existing Release workflow.

## Format validation

All tasks conform to `- [ ] <ID> [P?] [Story?] <description with file path>`.

**Total tasks**: 25 (T001-T025).

| Phase | Tasks | Range |
|-------|-------|-------|
| 1. Setup | 4 | T001-T004 |
| 2. Foundational | 4 | T005-T008 |
| 3. US1 — Adaptive backend | 7 | T009-T015 |
| 4. US2 — App UI | 6 | T016-T021 |
| 5. Polish | 4 | T022-T025 |
