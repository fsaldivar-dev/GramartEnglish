---
description: "Task list for Vocabulary Lesson MVP"
---

# Tasks: Vocabulary Lesson MVP

**Input**: Design documents from `specs/001-vocabulary-lesson-mvp/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: Tests are **REQUIRED** because Constitution Principle I (Test-First) is NON-NEGOTIABLE. Every implementation task in a user-story phase MUST be preceded by its tests in that same phase.

**Organization**: Tasks are grouped by user story so each story can be implemented, tested, and demoed independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US0, US1, US2, US3). Setup/Foundational/Polish have no story label.
- All paths are repository-relative.

## Path Conventions

- macOS app: `app/GramartEnglish/Sources/...`, Swift packages under `app/Packages/`, tests under `app/GramartEnglish/Tests/` and `app/Packages/<Pkg>/Tests/`.
- Backend (Node.js/TypeScript): `backend/src/...`, tests under `backend/tests/`.
- Curated corpus: `data/cefr/`.
- Shared scripts: `scripts/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository skeleton, tooling, and baseline configuration shared by all stories.

- [X] T001 Create repository top-level directories per plan.md (`app/`, `backend/`, `data/cefr/`, `scripts/`, `.github/workflows/`)
- [X] T002 Initialize Node.js backend in `backend/` with `package.json`, `tsconfig.json` (strict mode), Vitest, esbuild, and core deps (fastify, pino, zod, better-sqlite3, hnswlib-node, ollama)
- [X] T003 [P] Configure ESLint + Prettier for the backend in `backend/.eslintrc.cjs` and `backend/.prettierrc`
- [X] T004 [P] Create Xcode project skeleton at `app/GramartEnglish.xcodeproj` targeting macOS 14, Apple Silicon, with SwiftUI App lifecycle and Hardened Runtime entitlements (no network entitlement)
- [X] T005 [P] Add empty Swift packages `app/Packages/LessonKit/` and `app/Packages/BackendClient/` with `Package.swift`, sources directory, and tests target
- [X] T006 [P] Add SwiftLint config at `app/.swiftlint.yml` and wire it into the Xcode build phase
- [X] T007 [P] Add `data/cefr/README.md` describing corpus sources (CEFR-J, EVP, Tatoeba) and licensing per `research.md` §8
- [X] T008 [P] Add `version.json` at repo root with the shared SemVer (`1.0.0`) consumed by both app and backend
- [X] T009 [P] Add `.github/workflows/ci.yml` running backend Vitest + Swift package tests on every push

**Checkpoint**: Backend and app build with no source files yet; CI is green.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Cross-cutting code that every user story needs. MUST complete before Phase 3.

### Backend foundation

- [X] T010 Create SQLite migration `backend/src/store/migrations/0001_init.sql` per [data-model.md](./data-model.md) (all 8 tables + indexes) and the migration runner in `backend/src/store/migrations/runner.ts`
- [X] T011 [P] Implement the pino logger + `correlation-id` Fastify plugin in `backend/src/observability/logger.ts` and `backend/src/observability/correlationId.ts`
- [X] T012 [P] Implement the SQLite connection factory (WAL mode, foreign keys on) in `backend/src/store/db.ts`
- [X] T013 [P] Implement the Ollama adapter with chat + embed methods plus a recorded-response fake in `backend/src/llm/ollama.ts` and `backend/src/llm/__fakes__/recorded.ts`
- [X] T014 [P] Implement the HNSW index manager (load, rebuild on schemaVersion mismatch, k-NN query) in `backend/src/rag/index.ts`
- [X] T015 Implement the Fastify server bootstrap with port `127.0.0.1:0`, stdout JSON handshake, and graceful shutdown in `backend/src/server.ts`
- [X] T016 [P] Add the OpenAPI loader that validates routes against `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml` at startup in `backend/src/openapiLoader.ts`
- [X] T017 [P] Implement zod schemas mirroring the OpenAPI components in `backend/src/domain/schemas.ts`

### Backend foundation tests (Test-First)

- [X] T018 [P] Vitest for the migration runner in `backend/tests/unit/store/runner.test.ts`
- [X] T019 [P] Vitest for the correlation-id plugin in `backend/tests/unit/observability/correlationId.test.ts`
- [X] T020 [P] Vitest for the Ollama adapter against the fake in `backend/tests/unit/llm/ollama.test.ts`
- [X] T021 [P] Vitest for the HNSW index manager in `backend/tests/unit/rag/index.test.ts`
- [X] T022 [P] Vitest for the server bootstrap + handshake in `backend/tests/integration/server.test.ts`

### App foundation

- [X] T023 Implement the child-process supervisor (launch, read stdout handshake, auto-relaunch x2, terminate on app quit) in `app/GramartEnglish/Sources/Features/BackendBridge/BackendSupervisor.swift`
- [X] T024 [P] Implement `BackendClient` package with `URLSession` HTTP client, automatic `x-correlation-id` injection, and typed methods derived from the OpenAPI doc in `app/Packages/BackendClient/Sources/BackendClient/`
- [X] T025 [P] Implement the local rotating file logger (`~/Library/Logs/GramartEnglish/app.log`) in `app/GramartEnglish/Sources/Shared/Logging/FileLogger.swift`
- [X] T026 [P] Implement shared accessibility helpers (focus ring modifier, dynamic-type-aware text styles, reduce-motion-aware transitions) in `app/GramartEnglish/Sources/Shared/Accessibility/`
- [X] T027 Implement the SwiftUI `@main` app with launch screen that waits for backend handshake and renders a calm "Setting things up…" view in `app/GramartEnglish/Sources/App/GramartEnglishApp.swift`

### App foundation tests

- [X] T028 [P] XCTest for `BackendSupervisor` (stdout parsing, relaunch limit) in `app/GramartEnglish/Tests/Unit/BackendSupervisorTests.swift`
- [X] T029 [P] Swift package tests for `BackendClient` using `URLProtocol` stubs in `app/Packages/BackendClient/Tests/BackendClientTests/`

### Data foundation

- [X] T030 [P] Add minimal seed corpus (10 placeholder words per level) at `data/cefr/{a1,a2,b1,b2,c1,c2}.json` so the rest of the pipeline can be exercised before final curation

**Checkpoint**: Backend boots, SQLite migrates, Ollama adapter is wired (faked in tests), app launches and connects. No user-visible feature yet.

---

## Phase 3: User Story 0 — Placement test (Priority: P1)

**Story goal**: First-launch user takes a ~12-question mixed-level placement test; the system estimates their CEFR level.

**Independent test criterion**: Fresh install → start placement → answer all questions → see an estimated CEFR level (one of A1–C2) and the per-level breakdown. No lessons or AI features needed.

### Tests for US0

- [X] T031 [P] [US0] Vitest contract test for `POST /v1/placement/start` against `contracts/openapi.yaml` in `backend/tests/contract/placement.start.test.ts`
- [X] T032 [P] [US0] Vitest contract test for `POST /v1/placement/submit` in `backend/tests/contract/placement.submit.test.ts`
- [X] T033 [P] [US0] Vitest unit test for the placement scoring algorithm (per-level ≥50% threshold, bump-down rule, A2 default) in `backend/tests/unit/lessons/placementScorer.test.ts`
- [X] T034 [P] [US0] Vitest unit test for the placement question selector (2 per level, no duplicates, deterministic seed) in `backend/tests/unit/lessons/placementSelector.test.ts`
- [X] T035 [P] [US0] XCTest for `PlacementViewModel` (state transitions, submit, error fallback) in `app/GramartEnglish/Tests/Unit/PlacementViewModelTests.swift`

### Implementation for US0

- [X] T036 [US0] Implement `VocabularyWord` repository (read-only: `byLevel`, `byBase`, `randomByLevel`) in `backend/src/store/wordRepository.ts`
- [X] T037 [US0] Implement `PlacementResult` repository (create, latestForUser) in `backend/src/store/placementRepository.ts`
- [X] T038 [US0] Implement the placement question selector (2 per level, draws distractors from the same level) in `backend/src/lessons/placementSelector.ts`
- [X] T039 [US0] Implement the placement scoring algorithm per `research.md` §7 in `backend/src/lessons/placementScorer.ts`
- [X] T040 [US0] Implement the placement routes in `backend/src/routes/placement.ts` and register them in `backend/src/server.ts`
- [X] T041 [US0] Implement `PlacementViewModel` (calls `BackendClient.startPlacement` / `.submitPlacement`, holds question index and answers) in `app/GramartEnglish/Sources/Features/Onboarding/PlacementViewModel.swift`
- [X] T042 [US0] Implement `WelcomeView` (title, two-bullet explanation, "Start placement", skip link) with full accessibility labels in `app/GramartEnglish/Sources/Features/Onboarding/WelcomeView.swift`
- [X] T043 [US0] Implement `PlacementQuestionView` (progress, word, 4 option cards with 1–4 keyboard shortcuts, skip) in `app/GramartEnglish/Sources/Features/Onboarding/PlacementQuestionView.swift`
- [X] T044 [US0] Implement `PlacementResultView` (estimated level reveal, per-level breakdown bars, "Start lesson" / "Pick another level") in `app/GramartEnglish/Sources/Features/Onboarding/PlacementResultView.swift`
- [X] T045 [US0] Wire the onboarding flow into the root navigation: first-launch detection → Welcome → Placement → Result in `app/GramartEnglish/Sources/App/RootView.swift`

**Checkpoint**: A fresh install completes the placement test end-to-end and shows the estimated level. T031–T035 pass.

---

## Phase 4: User Story 1 — Vocabulary lesson quiz (Priority: P1)

**Story goal**: User starts a 10-question multiple-choice lesson at their CEFR level, sees correct/incorrect feedback per answer, and gets a summary at the end.

**Independent test criterion**: User with a known CEFR level can complete a 10-question lesson, see per-answer feedback, and reach a summary screen showing score X/10 and the list of missed words. RAG/LLM features are NOT required for this story.

### Tests for US1

- [X] T046 [P] [US1] Vitest contract test for `POST /v1/lessons` in `backend/tests/contract/lessons.start.test.ts`
- [X] T047 [P] [US1] Vitest contract test for `POST /v1/lessons/{id}/answers` in `backend/tests/contract/lessons.answers.test.ts`
- [X] T048 [P] [US1] Vitest contract test for `POST /v1/lessons/{id}/complete` in `backend/tests/contract/lessons.complete.test.ts`
- [X] T049 [P] [US1] Vitest unit test for the 50/30/20 word-selection mix (FR-013a) including fallback when categories are empty in `backend/tests/unit/lessons/wordSelector.test.ts`
- [X] T050 [P] [US1] Vitest unit test for distractor generation (3 plausible same-level wrong definitions, all distinct from correct) in `backend/tests/unit/lessons/distractorBuilder.test.ts`
- [X] T051 [P] [US1] Vitest unit test for mastery updates (consecutiveCorrect reset on miss, `mastered=true` at 2) in `backend/tests/unit/lessons/masteryService.test.ts`
- [X] T052 [P] [US1] Vitest integration test: full lesson flow start → 10 answers → complete in `backend/tests/integration/lessonFlow.test.ts`
- [X] T053 [P] [US1] Swift package tests for `LessonKit` state machine (pristine → selected → submitted → next; end of lesson) in `app/Packages/LessonKit/Tests/LessonKitTests/StateMachineTests.swift`
- [X] T054 [P] [US1] XCTest for `LessonViewModel` (load questions, submit answer, advance, complete) in `app/GramartEnglish/Tests/Unit/LessonViewModelTests.swift`
- [X] T055 [P] [US1] XCUITest for the lesson happy path (start → answer → next → summary) in `app/GramartEnglish/Tests/UI/LessonFlowUITests.swift`

### Implementation for US1

- [X] T056 [US1] Implement `Lesson` repository (create, byId, updateState, setScore) in `backend/src/store/lessonRepository.ts`
- [X] T057 [US1] Implement `Question` repository (createMany, byLessonId, updateAnswer) in `backend/src/store/questionRepository.ts`
- [X] T058 [US1] Implement `WordMastery` repository (upsert, byUser, byUserAndWord) in `backend/src/store/masteryRepository.ts`
- [X] T059 [US1] Implement the 50/30/20 word selector in `backend/src/lessons/wordSelector.ts`
- [X] T060 [US1] Implement the distractor builder (sample 3 wrong canonical definitions from the same level, ensure uniqueness) in `backend/src/lessons/distractorBuilder.ts`
- [X] T061 [US1] Implement `LessonService` (`startLesson`, `submitAnswer`, `completeLesson`) wiring repositories + selector + distractor builder in `backend/src/lessons/lessonService.ts`
- [X] T062 [US1] Implement `MasteryService` (apply answer result, return updates) in `backend/src/lessons/masteryService.ts`
- [X] T063 [US1] Implement the lessons routes in `backend/src/routes/lessons.ts` and register them
- [X] T064 [US1] Implement `LessonKit` Swift package: `LessonStateMachine`, `Question`, `Answer`, `MasteryDelta` types in `app/Packages/LessonKit/Sources/LessonKit/`
- [X] T065 [US1] Implement `LessonViewModel` (drives the lesson via `BackendClient` + `LessonKit`) in `app/GramartEnglish/Sources/Features/Lesson/LessonViewModel.swift`
- [X] T066 [US1] Implement `HomeView` (level badge, "Start new lesson" card, stats row, last-lesson summary, settings gear) in `app/GramartEnglish/Sources/Features/Lesson/HomeView.swift`
- [X] T067 [US1] Implement `LessonQuestionView` (progress header, word, 4 option cards with 1–4 keyboard shortcuts, exit affordance) in `app/GramartEnglish/Sources/Features/Lesson/LessonQuestionView.swift`
- [X] T068 [US1] Implement `AnswerFeedbackView` (correct/incorrect state with icon + text + color, canonical definition card, Next button) in `app/GramartEnglish/Sources/Features/Lesson/AnswerFeedbackView.swift`
- [X] T069 [US1] Implement `LessonSummaryView` (score, tone-tuned message, missed-words list with definitions, Start another / Back home) in `app/GramartEnglish/Sources/Features/Lesson/LessonSummaryView.swift`
- [X] T070 [US1] Wire the post-placement flow into `RootView`: PlacementResult → Home → Lesson → Summary

**Checkpoint**: A user with a chosen CEFR level can complete a full quiz lesson end-to-end. T046–T055 pass. MVP slice is shippable.

---

## Phase 5: User Story 2 — AI examples & contextual definitions (Priority: P2)

**Story goal**: User taps "Show examples" on a word and gets 2–3 LLM-generated example sentences and a level-adapted contextual definition, grounded by the RAG pipeline. When Ollama is unavailable the canonical fallback is shown with a clear banner.

**Independent test criterion**: For a known word at a known CEFR level, the system returns 2–3 example sentences each containing the word or a valid inflection, with cited RAG source IDs, in < 1.5 s to first token under nominal conditions. With Ollama stopped, the same call returns a canonical fallback and a `fallback: true` flag.

### Tests for US2

- [X] T071 [P] [US2] Vitest contract test for `GET /v1/words/{word}/examples` including the `503/200+fallback:true` branch in `backend/tests/contract/words.examples.test.ts`
- [X] T072 [P] [US2] Vitest contract test for `GET /v1/words/{word}/definition` in `backend/tests/contract/words.definition.test.ts`
- [X] T073 [P] [US2] Vitest unit test for the prompt builder (system prompt forbids invention; user prompt includes canonical entry + retrieved passages + target level) in `backend/tests/unit/rag/promptBuilder.test.ts`
- [X] T074 [P] [US2] Vitest unit test for the RAG retriever (lexical + semantic two-stage, returns ≥1 source) in `backend/tests/unit/rag/retriever.test.ts`
- [X] T075 [P] [US2] Vitest unit test for the output validator (output contains the word or a valid inflection; otherwise downgrade to fallback) in `backend/tests/unit/llm/outputValidator.test.ts`
- [X] T076 [P] [US2] Vitest integration test for the fallback path with Ollama adapter throwing in `backend/tests/integration/aiFallback.test.ts`
- [X] T077 [P] [US2] XCTest for `WordExamplesViewModel` (loading, success, fallback) in `app/GramartEnglish/Tests/Unit/WordExamplesViewModelTests.swift`
- [X] T078 [P] [US2] XCUITest for "Show examples" sheet (loads in < 1.5 s with stub, shows fallback banner on simulated Ollama outage) in `app/GramartEnglish/Tests/UI/ExamplesPanelUITests.swift`

### Implementation for US2

- [X] T079 [US2] Implement the corpus ingestion script `scripts/ingest-cefr.ts` (loads `data/cefr/*.json`, populates `VocabularyWord`, builds RAGSource rows + embeddings via Ollama, persists HNSW index)
- [X] T080 [US2] Implement `RAGSource` repository (createMany, byKindAndLevel, byIds) in `backend/src/store/ragSourceRepository.ts`
- [X] T081 [US2] Implement the RAG retriever (lexical lookup + HNSW k-NN, returns 3–5 sources) in `backend/src/rag/retriever.ts`
- [X] T082 [US2] Implement the prompt builders for `examples` and `contextual_definition` in `backend/src/rag/promptBuilder.ts`
- [X] T083 [US2] Implement the output validator (word/inflection check, hallucination guard) in `backend/src/llm/outputValidator.ts`
- [X] T084 [US2] Implement `AIGenerationService` that orchestrates retrieve → prompt → call Ollama → validate → log `AIGeneration` row, with fallback to canonical example/definition on error in `backend/src/llm/aiGenerationService.ts`
- [X] T085 [US2] Implement `AIGeneration` repository (insert, byCorrelationId) in `backend/src/store/aiGenerationRepository.ts`
- [X] T086 [US2] Implement the words routes in `backend/src/routes/words.ts` and register them
- [X] T087 [US2] Implement `WordExamplesViewModel` (calls `BackendClient.getExamples` / `.getDefinition`, exposes loading / success / fallback states) in `app/GramartEnglish/Sources/Features/Lesson/WordExamplesViewModel.swift`
- [X] T088 [US2] Implement `ExamplesPanelView` (sheet/inspector with shimmer loading, 2–3 examples with the word emphasized, attribution line, "i" tooltip) in `app/GramartEnglish/Sources/Features/Lesson/ExamplesPanelView.swift`
- [X] T089 [US2] Implement `FallbackBannerView` (yellow calm banner used by `ExamplesPanelView` when `fallback == true`) in `app/GramartEnglish/Sources/Features/Lesson/FallbackBannerView.swift`
- [X] T090 [US2] Add the "Show examples" affordance to `LessonQuestionView` and `AnswerFeedbackView`; show panel during and after the question
- [X] T091 [US2] Add the menu-bar / window-corner "AI helper offline" indicator (driven by `/v1/health.ollamaAvailable` polling every 10 s) in `app/GramartEnglish/Sources/Shared/Status/OllamaStatusIndicator.swift`

**Checkpoint**: With Ollama running, the user sees grounded examples and contextual definitions for missed words. With Ollama stopped, the fallback banner appears and quiz functions still work. T071–T078 pass.

---

## Phase 6: User Story 3 — Persistence & resume (Priority: P3)

**Story goal**: Progress (level, mastery, lesson history) persists across launches. User can resume an in-progress lesson and see which words they've mastered.

**Independent test criterion**: Complete one lesson, quit the app, relaunch — Home shows last lesson score and a "Continue with level X — lesson N" button. Close mid-lesson and relaunch — Home offers "Resume lesson" or "Start new".

### Tests for US3

- [X] T092 [P] [US3] Vitest integration test for resuming an in-progress lesson (`GET /v1/lessons/{id}` returns remaining questions) in `backend/tests/integration/resumeLesson.test.ts`
- [X] T093 [P] [US3] Vitest unit test for mastery aggregation (`GET /v1/progress` returns mastered/to-review counts) in `backend/tests/unit/lessons/progressService.test.ts`
- [X] T094 [P] [US3] Vitest contract test for the settings update endpoint (`PATCH /v1/me`) once added in `backend/tests/contract/me.test.ts`
- [X] T095 [P] [US3] XCUITest for the cold-relaunch scenario in `app/GramartEnglish/Tests/UI/ResumeUITests.swift`

### Implementation for US3

- [X] T096 [US3] Extend the OpenAPI doc with `GET /v1/lessons/{id}`, `GET /v1/progress`, and `PATCH /v1/me` (level override + a11y prefs) in `contracts/openapi.yaml`
- [X] T097 [US3] Implement `GET /v1/lessons/{id}` (returns remaining questions for in-progress, or summary for completed) in `backend/src/routes/lessons.ts`
- [X] T098 [US3] Implement `GET /v1/progress` returning mastered / to-review / lessons-completed counts in `backend/src/routes/progress.ts`
- [X] T099 [US3] Implement `PATCH /v1/me` for level override and accessibility prefs (writes to `User` row) in `backend/src/routes/me.ts`
- [X] T100 [US3] Update `HomeView` to render last-lesson card, "Resume / Start new" branching, and mastered/to-review counts in `app/GramartEnglish/Sources/Features/Lesson/HomeView.swift`
- [X] T101 [US3] Implement `SettingsView` with tabs General · Learning · Accessibility · About (level override, reset progress with confirm, reduce motion / large text overrides, version + offline indicator) in `app/GramartEnglish/Sources/Features/Settings/SettingsView.swift`
- [X] T102 [US3] Implement the "reset progress" path that truncates `Lesson`, `Question`, `WordMastery`, `PlacementResult` and re-runs first-launch onboarding in `backend/src/routes/me.ts` and `app/GramartEnglish/Sources/Features/Settings/`

**Checkpoint**: Closing and reopening the app preserves all progress; Home reflects it. T092–T095 pass.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Performance budgets, accessibility audit, packaging, distribution, docs. Runs after MVP stories pass.

### Performance (Constitution VIII)

- [X] T103 [P] Add backend latency bench for `/v1/lessons` p95 ≤ 200 ms in `backend/perf/apiP95.test.ts`
- [X] T104 [P] Add LLM first-token latency bench (≤ 1.5 s with real Ollama) in `backend/perf/llmFirstToken.test.ts`
- [X] T105 [P] Add macOS cold-launch bench (≤ 2.0 s) using a signpost harness in `app/GramartEnglish/Tests/Perf/ColdLaunchTests.swift`
- [X] T106 [P] Add screen-transition bench (≤ 150 ms) in `app/GramartEnglish/Tests/Perf/TransitionTests.swift`
- [X] T107 Wire all four perf benches into CI as gates that fail the build on regression in `.github/workflows/ci.yml`

### Accessibility audit (Constitution VII)

- [X] T108 [P] Accessibility audit pass: VoiceOver labels on every interactive element across all screens, with a written checklist appended to `specs/001-vocabulary-lesson-mvp/design/a11y-audit.md`
- [X] T109 [P] Keyboard-only walkthrough: complete every flow without a mouse; document shortcuts in `app/GramartEnglish/Sources/Shared/Accessibility/Shortcuts.md`
- [X] T110 [P] Dynamic Type + Increase Contrast manual verification at default and +2 sizes; record findings in `a11y-audit.md`

### Packaging & distribution

- [X] T111 Implement `scripts/package-backend.sh` that builds the backend (`tsc + esbuild`), copies the arm64 Node 20 binary, rebuilds native modules, and emits `app/GramartEnglish/Resources/backend/`
- [X] T112 Wire `package-backend.sh` into the Xcode build phase so every archive includes a fresh backend bundle
- [X] T113 Add notarization + signing scripts at `scripts/sign-and-notarize.sh` using Hardened Runtime, no network entitlement (per `research.md` §10)
- [X] T114 Verify bundle size ≤ 80 MB compressed; record actual size in `specs/001-vocabulary-lesson-mvp/notes/bundle-size.md`

### Corpus curation

- [X] T115 [P] Curate ≥ 50 author-reviewed words per CEFR level in `data/cefr/{a1..c2}.json` (replaces the seed corpus from T030)
- [X] T116 [P] Curate canonical example sentences (1–3 per word) and add to `data/cefr/examples/` per word

### Docs

- [X] T117 [P] Add repo-level `README.md` linking to spec, plan, constitution, and quickstart
- [X] T118 [P] Add `CONTRIBUTING.md` describing the spec-kit workflow (spec → plan → tasks → implement) and the Constitution Check expectation

**Checkpoint**: All success criteria (SC-001..SC-008) measurable; perf budgets enforced in CI; app signs + notarizes; corpus is real.

---

## Dependencies

```text
Phase 1 (Setup)            ──┐
                             ▼
Phase 2 (Foundational)    ───┴──▶  Phase 3 (US0 Placement)  ──▶  Phase 4 (US1 Lesson)
                                                                      │
                                                                      ▼
                                                                Phase 5 (US2 AI)
                                                                      │
                                                                      ▼
                                                                Phase 6 (US3 Persistence)
                                                                      │
                                                                      ▼
                                                                Phase 7 (Polish)
```

- **Phase 1** must finish before Phase 2.
- **Phase 2** must finish before any user-story phase.
- **Phase 3 (US0)** and **Phase 4 (US1)** are both P1; deliver them as the **MVP slice**.
- **Phase 5 (US2)** depends on Phase 4 only for the UI hooks (`LessonQuestionView`, `AnswerFeedbackView`). Its backend pieces are independent and can start once Phase 2 is done.
- **Phase 6 (US3)** depends on Phase 4 for the lesson model and on Phase 3 for the user state.
- **Phase 7** runs last but can start its `[P]` items in parallel once Phase 4 is complete.

## Parallel execution examples

Within Phase 2 (Foundational), the following can run in parallel after T010 lands:

```text
T011 (pino + correlation-id)   ║  T012 (db.ts)
T013 (Ollama adapter + fake)   ║  T014 (HNSW manager)
T016 (OpenAPI loader)          ║  T017 (zod schemas)
T024 (BackendClient)           ║  T025 (FileLogger)
T026 (Accessibility helpers)   ║  T030 (Seed corpus)
```

Within Phase 4 (US1), all `[P]` test tasks (T046–T055) can run in parallel before any implementation begins, satisfying Test-First.

Within Phase 5 (US2), the prompt builder (T082), retriever (T081), and output validator (T083) are file-isolated and can be developed in parallel after T080 lands.

## Implementation strategy

1. **Land the MVP slice first**: Phase 1 → Phase 2 → Phase 3 (US0) → Phase 4 (US1). At that checkpoint the product is demoable end-to-end without the LLM — useful for early user testing and validating SC-001, SC-002, SC-003, SC-006, SC-008.
2. **Layer in US2 (AI)** next, once SC-004 can be measured against the real Ollama. The fallback path guarantees US1 keeps working if anything regresses.
3. **Layer in US3 (persistence)** to unlock SC-008 (mastery growth across 5 lessons).
4. **Polish** before any external release: enforce all four performance budgets in CI, complete accessibility audit, replace the seed corpus with curated words, sign and notarize the app.

## Format validation

All tasks above conform to `- [ ] <ID> [P?] [Story?] <description with file path>`. Tasks in Phases 1, 2, and 7 carry no story label by design. Tasks in Phases 3–6 are labeled US0–US3 respectively.

**Total tasks**: 118 (T001–T118)

| Phase | Tasks | Range |
|-------|-------|-------|
| 1. Setup | 9 | T001–T009 |
| 2. Foundational | 21 | T010–T030 |
| 3. US0 — Placement | 15 | T031–T045 |
| 4. US1 — Lesson | 25 | T046–T070 |
| 5. US2 — AI examples | 21 | T071–T091 |
| 6. US3 — Persistence | 11 | T092–T102 |
| 7. Polish | 16 | T103–T118 |
