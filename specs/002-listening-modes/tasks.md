---
description: "Task list for Listening Modes (Feature 002)"
---

# Tasks: Listening Modes

**Input**: Design documents from `specs/002-listening-modes/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/openapi-delta.yaml](./contracts/openapi-delta.yaml)

**Tests**: REQUIRED (Constitution Principle I — Test-First, NON-NEGOTIABLE).

**Organization**: Tasks are grouped by user story so each story can be implemented, tested, and demoed independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1, US2, US3). Setup/Foundational/Polish have no story label.
- All paths are repository-relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Land the migration and shared types that every user story will use.

- [X] T001 Add SQL migration `backend/src/store/migrations/0003_lesson_modes.sql` matching [data-model.md](./data-model.md) (adds `users.preferredMode`, `lessons.mode`, `questions.typedAnswer`, recreates `word_mastery` with `(userId, wordId, mode)` PK + migrates existing rows to `mode='read_pick_meaning'`).
- [X] T001a Add rollback companion at `backend/src/store/migrations/0003_lesson_modes_rollback.sql` and a `npm run db:rollback` script entry in `backend/package.json`. Satisfies Constitution V ("All schema changes MUST ship with a migration AND a rollback path"). Behavior: drops non-read mastery rows, rebuilds v2 PK on `word_mastery`, removes added columns, resets `user_version=2`.
- [X] T002 [P] Add `LessonMode` enum + ALL_MODES helper in `backend/src/domain/schemas.ts` (zod enum: `read_pick_meaning | listen_pick_word | listen_pick_meaning | listen_type`).
- [X] T003 [P] Add `LessonMode` enum in Swift at `app/Packages/LessonKit/Sources/LessonKit/LessonMode.swift` with `displayName(spanish:)`, `icon` (SF Symbol), `prompt` helpers.
- [X] T004 [P] Add pure Levenshtein helper in TS at `backend/src/lessons/levenshtein.ts` (function `levenshteinAtMost(a, b, k): number` returning Infinity once exceeded — short-circuit for performance).
- [X] T005 [P] Add pure Levenshtein helper in Swift at `app/Packages/LessonKit/Sources/LessonKit/Levenshtein.swift` (same shape, returning Int).
- [X] T006 Bump `version.json` to `1.2.0`, update `schemaVersion` to `3`.

**Checkpoint**: Backend and app both have the enum + helpers, but no logic uses them yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Mode-aware mastery + selector + route changes that every user story depends on. Tests precede implementation (Principle I).

### Backend foundation tests

- [X] T007 [P] Vitest for migration `0003_lesson_modes.sql` in `backend/tests/unit/store/migration0003.test.ts` (verify `word_mastery` PK, columns added, existing rows preserved with `mode='read_pick_meaning'`). Separate file from `runner.test.ts` to avoid merge conflicts with F001 tests.
- [X] T007a [P] Vitest for the rollback path in `backend/tests/unit/store/migration0003.rollback.test.ts` (apply 0003 → seed non-read mastery → run rollback → verify v2 PK restored, columns dropped, non-read rows discarded, `user_version=2`).
- [X] T008 [P] Vitest for `levenshteinAtMost` in `backend/tests/unit/lessons/levenshtein.test.ts` (exact match=0; single substitution/insert/delete=1; transposition=2; rejects ≥2 short-circuit). Plus a **parameterized fixture of 20 curated (canonical, typo, expectedDistance) triples** covering common real-world typos for SC-004 (e.g., `weather → wether`, `language → lenguage`, `dangerous → dangerus`, `important → imporant`, `expensive → expensiv` …). Asserts ≥ 90% acceptance at threshold 1.
- [X] T009 [P] Vitest for the extended `MasteryRepository` in `backend/tests/unit/lessons/masteryRepository.modes.test.ts` (per-mode `apply`, per-mode `countMastered`, per-mode `allForUser`).
- [X] T010 [P] Vitest for the mode-aware `wordSelector` in `backend/tests/unit/lessons/wordSelector.modes.test.ts` (50/30/20 mix isolated per mode; mastering "weather" in read does NOT make it ineligible for listening selection).
- [X] T011 [P] Vitest for `modeRecommender` in `backend/tests/unit/lessons/modeRecommender.test.ts`. Covers: argmax pending; LRU tiebreaker; **brand-new user (all-modes-tied + null lastSeen) → `listen_pick_word`** (per research.md §2); **coming-soon modes excluded from candidates** (only shipped modes can win).
- [X] T012 [P] Vitest contract test for the extended `POST /v1/lessons` in `backend/tests/contract/lessons.start.modes.test.ts` (missing `mode` → defaults to `read_pick_meaning`; explicit `mode` honored; invalid `mode` → 400).
- [X] T013 [P] Vitest contract test for the extended `POST /v1/lessons/{id}/answers` in `backend/tests/contract/lessons.answers.typed.test.ts` (typed answer with exact match → correct; typo within Levenshtein 1 → correct + `typedAnswerEcho` populated; distance≥2 → incorrect).
- [X] T014 [P] Vitest contract test for the extended `GET /v1/progress` in `backend/tests/contract/progress.modes.test.ts` (`perModeMastered` returned with all 4 modes; `recommendedMode` is a valid `LessonMode`).

### Backend foundation implementation

- [X] T015 Extend `MasteryRepository` to accept `mode` everywhere it currently keys by `(userId, wordId)`; methods: `byUserAndWord(userId, wordId, mode)`, `allForUser(userId, mode?)`, `apply({…, mode})`, `countMastered(userId, mode?)`, `countToReview(userId, mode?)` in `backend/src/store/masteryRepository.ts`.
- [X] T016 Extend `wordSelector` to accept a `mode` arg and filter mastery/pools by `(userId, level, mode)` in `backend/src/lessons/wordSelector.ts`.
- [X] T017 [P] Implement `modeRecommender` in `backend/src/lessons/modeRecommender.ts` (input: userId, currentLevel, all-modes mastery snapshot; output: `LessonMode`).
- [X] T018 [P] Extend `UserRepository` with `setPreferredMode(userId, mode)` and include `preferredMode` in returned rows in `backend/src/store/userRepository.ts`.
- [X] T019 Extend `LessonRepository.create` to persist `mode` and `Lesson` shape to include it in `backend/src/store/lessonRepository.ts`.
- [X] T020 Extend `QuestionRepository.recordAnswer` to also accept `typedAnswer: string | null` in `backend/src/store/questionRepository.ts`.
- [X] T021 Extend `LessonService.startLesson` to take `mode` (default `read_pick_meaning`), pass to `wordSelector`, persist on `Lesson` row in `backend/src/lessons/lessonService.ts`.
- [X] T022 Extend `LessonService.submitAnswer` and `.submitSkip` to set `mode` outcome on `MasteryRepository.apply` and accept `typedAnswer` path for `listen_type` in `backend/src/lessons/lessonService.ts`.
- [X] T023 Update `POST /v1/lessons` route to read `mode` from body (zod schema with default), call service with it; update `POST /v1/lessons/{id}/answers` to accept `typedAnswer` (mutually exclusive with `optionIndex`) in `backend/src/routes/lessons.ts`.
- [X] T024 Update `GET /v1/progress` route to include `perModeMastered` + `recommendedMode` in `backend/src/routes/progress.ts`.
- [X] T025 [P] Add `PATCH /v1/me` ability to set `preferredMode`; update `MePatchRequest` zod schema in `backend/src/routes/me.ts`.

### App foundation

- [X] T026 Extend `BackendClient.startLesson(level:, mode:)` and add a typed-answer variant in `app/Packages/BackendClient/Sources/BackendClient/BackendClient.swift`.
- [X] T027 [P] Extend `BackendClient.answerLesson(...)` to accept an optional `typedAnswer: String?` parameter; update `AnswerLessonResponse` to expose `typedAnswerEcho: String?`.
- [X] T028 [P] Extend `BackendClient.progress()` response to include `perModeMastered: [String: Int]` and `recommendedMode: String`.

### App foundation tests

- [X] T029 [P] Swift package tests for `LessonMode` in `app/Packages/LessonKit/Tests/LessonKitTests/LessonModeTests.swift` (icon mapping, display name, parsing from raw string).
- [X] T030 [P] Swift package tests for `Levenshtein` in `app/Packages/LessonKit/Tests/LessonKitTests/LevenshteinTests.swift` (mirror of T008 cases).
- [X] T031 [P] XCTest for `BackendClient` updates with URLProtocol mocks in `app/Packages/BackendClient/Tests/BackendClientTests/BackendClientModesTests.swift` (mode in request body, typedAnswer round-trip, progress mode fields).

**Checkpoint**: Backend boots with the new schema, exposes modes on lessons/answers/progress, but the user-facing UI is unchanged.

---

## Phase 3: User Story 1 — Listen and pick the English word (Priority: P1)

**Story goal**: Student opens Home, sees mode cards, picks "Escuchar", takes a 10-question lesson where audio plays and they pick the matching English word from 4 written options.

**Independent test criterion**: Pure listening flow works end-to-end with at least 10 mastered words across one lesson. UI shows mode cards on Home with "Recomendado para ti" tag.

### Tests for US1

- [X] T032 [P] [US1] Vitest integration test for the full `listen_pick_word` flow in `backend/tests/integration/listenPickWord.test.ts` (start lesson with mode → 10 questions → answer all → complete → progress reflects per-mode mastery).
- [X] T033 [P] [US1] XCTest for `ModeCard` view in `app/GramartEnglish/Tests/Unit/ModeCardTests.swift` (renders icon, name, pending count, recommended tag when flagged).
- [X] T034 [P] [US1] XCTest for `ListeningLessonViewModel` in `app/GramartEnglish/Tests/Unit/ListeningLessonViewModelTests.swift` (start in mode triggers audio playback marker; selecting option records answer; reveal phase exposes English correctOption).

### Implementation for US1

- [X] T035 [US1] Implement `ModeCard` view at `app/GramartEnglish/Sources/Features/Lesson/ModeCard.swift` with parameters: icon (SF Symbol), name (Spanish), subtitle, `pendingCount`, `isEnabled: Bool`, `comingSoon: Bool`, optional `recommendedTag: Bool`, tap action. When `isEnabled == false` OR `comingSoon == true`, render the card with reduced opacity (~0.5), grayscale tint, a "Próximamente" pill in the corner, and disable tap. Satisfies FR-011.
- [X] T036 [US1] Replace the single "Empezar nueva lección" CTA on `HomeView` with a 2×2 card grid of all 4 modes; populate from `progress.perModeMastered` + `progress.recommendedMode`. Cards `read_pick_meaning` + the listening modes shipped in this feature are enabled; `write_*` (F003) and `conjugate_*` (F004) modes render as `comingSoon = true`. In `app/GramartEnglish/Sources/Features/Lesson/HomeView.swift`.
- [X] T036a [US1] Add `XCTest` for the "coming-soon" card behavior in `app/GramartEnglish/Tests/Unit/ModeCardComingSoonTests.swift`: tapping a disabled card is a no-op; the "Próximamente" pill renders; the tooltip is set.
- [X] T037 [US1] Implement `ListeningLessonView` at `app/GramartEnglish/Sources/Features/Lesson/ListeningLessonView.swift` (replaces the big word with a prominent 🔊 button; 4 option cards underneath; auto-speaks on appear; `S` repeats).
- [X] T038 [US1] Extend `LessonViewModel` with a stored `mode: LessonMode` and a `@ViewBuilder` switch in `LessonFlowView` that picks the view per mode: `read_pick_meaning` → existing `LessonQuestionView`, `listen_pick_word` → `ListeningLessonView`. **Decision: extend, do NOT introduce `LessonModeRouter` yet** — defer that abstraction until F004 introduces verb modes. Files: `app/GramartEnglish/Sources/Features/Lesson/LessonViewModel.swift` and `app/GramartEnglish/Sources/App/RootView.swift` (the `LessonFlowView` switch).
- [X] T039 [US1] Wire `RootView` so picking a mode card creates a `LessonFlowView` with the chosen `mode` in `app/GramartEnglish/Sources/App/RootView.swift`.
- [X] T040 [US1] Persist the picked mode through `BackendClient.patchMe(preferredMode:)` after each lesson so next launch defaults to it in `app/GramartEnglish/Sources/Features/Lesson/LessonViewModel.swift`.

**Checkpoint**: User can pick "Escuchar" from Home cards, take a 10-question listening lesson, and see per-mode progress update. Demoable.

---

## Phase 4: User Story 2 — Listen and pick the Spanish meaning (Priority: P2)

**Story goal**: Variant of US1 where options are Spanish translations instead of English words.

**Independent test criterion**: Same mode card flow, but the lesson options show Spanish text and the underlying mastery axis is separate from US1's mode.

### Tests for US2

- [X] T041 [P] [US2] Vitest integration test for `listen_pick_meaning` flow in `backend/tests/integration/listenPickMeaning.test.ts` (mode-specific mastery progresses independently of US1's mode).
- [X] T042 [P] [US2] XCTest snapshot/render test for `ListeningLessonView` in `listen_pick_meaning` mode (Spanish options vs English) in `app/GramartEnglish/Tests/Unit/ListeningLessonViewModeTests.swift`.

### Implementation for US2

- [X] T043 [US2] Extend `LessonService.startLesson` to dispatch option-text-source by mode: `listen_pick_word` → `target.base`, `listen_pick_meaning` → `target.spanishOption` (already used for `read_pick_meaning`) in `backend/src/lessons/lessonService.ts`.
- [X] T044 [US2] Extend `ListeningLessonView` to render the right option set based on mode (it already receives mode via the view model); no UI re-design, just data swap.
- [X] T045 [US2] Ensure the reveal screen in `listen_pick_meaning` shows BOTH the English canonical AND the Spanish meaning (because Spanish is what was on-screen) in `app/GramartEnglish/Sources/Features/Lesson/AnswerFeedbackView.swift` (extend with a mode-aware variant). **Also**: on `.onAppear` of the reveal in ANY listening mode, trigger `SpeechService.shared.speakEnglish(canonical)` after a 250 ms debounce. Satisfies FR-008 + FR-012 (reinforcement audio).

**Checkpoint**: Two of the three listening sub-modes work end-to-end.

---

## Phase 5: User Story 3 — Listen and type (Priority: P3)

**Story goal**: Audio plays; user types the word; Levenshtein ≤ 1 tolerated; reveal shows typed vs canonical when corrected.

**Independent test criterion**: Typed answer flow works for all 10 questions; typos within distance 1 are accepted; the reveal makes the typo visible.

### Tests for US3

- [X] T046 [P] [US3] Vitest integration test for `listen_type` flow in `backend/tests/integration/listenType.test.ts` (typed exact-match correct, typed Levenshtein-1 correct + echo populated, typed Levenshtein-2 incorrect, empty typed = skipped).
- [X] T047 [P] [US3] XCTest for `TypedAnswerInputView` in `app/GramartEnglish/Tests/Unit/TypedAnswerInputViewTests.swift` (focus on appear, submit on Return, trim+lowercase, empty → skip path).
- [X] T048 [P] [US3] XCTest for `ListeningLessonViewModel` typed path in `app/GramartEnglish/Tests/Unit/ListeningLessonViewModelTypedTests.swift` (sends `typedAnswer`, parses `typedAnswerEcho`, renders reveal with both strings).

### Implementation for US3

- [X] T049 [US3] Implement `TypedAnswerInputView` at `app/GramartEnglish/Sources/Features/Lesson/TypedAnswerInputView.swift` (monospaced `TextField` with autocorrect/autocapitalize off; submit on `↩`; hint button reveals first letter; skip button).
- [X] T050 [US3] Extend `ListeningLessonView` to swap the 4-option cards for `TypedAnswerInputView` when mode is `listen_type` in `app/GramartEnglish/Sources/Features/Lesson/ListeningLessonView.swift`.
- [X] T051 [US3] Extend `AnswerFeedbackView` with the side-by-side typed vs canonical layout (FR-007a) when `typedAnswerEcho` is non-null in `app/GramartEnglish/Sources/Features/Lesson/AnswerFeedbackView.swift`. The reveal also auto-speaks the canonical (reuses the FR-012 hook added in T045).
- [X] T052 [US3] Wire `LessonViewModel.submitTypedAnswer(_:)` to call `BackendClient.answerLesson(typedAnswer:)` in `app/GramartEnglish/Sources/Features/Lesson/LessonViewModel.swift`.

**Checkpoint**: All three listening modes work end-to-end. F002 is feature-complete pending polish.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Performance budgets, accessibility, per-mode mastery surfacing, docs.

- [X] T053 [P] Add backend latency bench for `GET /v1/progress` p95 ≤ 100 ms (now does mode aggregations) in `backend/perf/progressP95.test.ts`.
- [X] T054 [P] Add macOS perf bench for mode-card render (≤ 50 ms after progress fetch) in `app/GramartEnglish/Tests/Perf/HomeRenderTests.swift`.
- [X] T055 [P] Add macOS perf bench for audio-first-token (≤ 300 ms from question appear) in `app/GramartEnglish/Tests/Perf/AudioLatencyTests.swift`.
- [X] T056 Surface per-mode mastery badges (📖 👂 ✏️ 🔁) on the summary screen and on a new "Mis palabras" detail screen in `app/GramartEnglish/Sources/Features/Lesson/LessonSummaryView.swift` and `app/GramartEnglish/Sources/Features/Progress/MyWordsView.swift` (new file).
- [X] T057 Accessibility audit checklist update at `specs/002-listening-modes/design/a11y-audit.md` (new file, mirroring 001's audit format) covering ModeCard, ListeningLessonView, TypedAnswerInputView.
- [X] T058 [P] Update CI workflow `.github/workflows/ci.yml` so new perf benches run on every push.
- [X] T059 [P] Append to repo `README.md` a "Lesson modes" section documenting the 4 modes and the per-mode mastery model. Also add a quickstart addendum at `specs/002-listening-modes/quickstart.md` covering: env vars (none new), how to test listening flows locally (no Ollama needed for L1/L2/L3, only TTS), how to rollback via `npm run db:rollback`.
- [X] T060 Merge `specs/002-listening-modes/contracts/openapi-delta.yaml` into the canonical `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml`; bump `info.version` to `1.2.0`.

---

## Dependencies

```text
Phase 1 (Setup)             ──┐
                              ▼
Phase 2 (Foundational)    ────┴──▶  Phase 3 (US1 listen_pick_word)
                                          │
                                          ▼
                                    Phase 4 (US2 listen_pick_meaning)
                                          │
                                          ▼
                                    Phase 5 (US3 listen_type)
                                          │
                                          ▼
                                    Phase 6 (Polish)
```

- Phase 1 strictly before Phase 2.
- Phase 2 strictly before any user-story phase.
- US1 must ship first (it lands the ModeCard grid + ListeningLessonView). US2 reuses both views; US3 adds TypedAnswerInputView.
- Polish runs last but `[P]` items can start once US1 lands.

## Parallel execution examples

Within Phase 2 the test files are all parallel-safe (different files):

```text
T007 (migration) ║ T008 (Levenshtein) ║ T009 (mastery repo)
T010 (selector)  ║ T011 (recommender) ║ T012 (lessons contract)
T013 (typed answer contract)         ║ T014 (progress contract)
```

Within Phase 3, the three test tasks (T032, T033, T034) run together before any implementation begins, satisfying Test-First.

## Implementation strategy

1. **MVP slice**: Phase 1 → Phase 2 → Phase 3 (US1). At this checkpoint the app has the mode card grid AND a working listening-pick-word lesson. Already demoable.
2. **Layer in US2 (Spanish-option variant)**: tiny incremental (same view, swapped data source).
3. **Layer in US3 (typed listening)**: introduces the new `TypedAnswerInputView` which Feature 003 (writing modes) will reuse.
4. **Polish**: badges, perf benches, accessibility audit, docs merge.

## Format validation

All tasks conform to `- [ ] <ID> [P?] [Story?] <description with file path>`. Setup/Foundational/Polish phases carry no story label by design. Phases 3–5 are labeled US1–US3 respectively.

**Total tasks**: 63 (T001–T060 + T001a, T007a, T036a)

| Phase | Tasks | Range |
|-------|-------|-------|
| 1. Setup | 7 | T001, T001a, T002–T006 |
| 2. Foundational | 26 | T007, T007a, T008–T031 |
| 3. US1 — listen_pick_word | 10 | T032–T036, T036a, T037–T040 |
| 4. US2 — listen_pick_meaning | 5 | T041–T045 |
| 5. US3 — listen_type | 7 | T046–T052 |
| 6. Polish | 8 | T053–T060 |
