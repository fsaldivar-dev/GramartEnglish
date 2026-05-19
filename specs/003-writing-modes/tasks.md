---
description: "Task list for Writing Modes (Feature 003)"
---

# Tasks: Writing Modes

**Input**: Design documents from `specs/003-writing-modes/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/openapi-delta.yaml](./contracts/openapi-delta.yaml)

**Tests**: REQUIRED (Constitution Principle I — Test-First, NON-NEGOTIABLE).

**Organization**: Tasks grouped by user story so each story can be implemented, tested, and demoed independently. F003 ships **US1 (P1) + US2 (P2)** in v1.3.0. US3 (`write_fill_gaps`, P3) is specced in `research.md` §1 and deferred to v1.4 — not in this task list.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1, US2). Setup / Foundational / Polish carry no label.
- All paths are repository-relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Land the enum additions, version bump, and Swift-side mode promotion that every story below needs. **No DB migration in F003** (per [data-model.md](./data-model.md)).

- [ ] T001 Bump `version.json` to `1.3.0` (`schemaVersion` STAYS at 3 — F003 adds no migration).
- [ ] T002 [P] Extend `LessonMode` zod enum + `SHIPPED_MODES` in `backend/src/domain/schemas.ts` with `write_pick_word`, `write_type_word`, `write_fill_gaps`. `SHIPPED_MODES` includes the first two; `write_fill_gaps` stays an enum value but is excluded from shipped list (placeholder for v1.4).
- [ ] T003 [P] Promote `writePickWord` + `writeTypeWord` from `ComingSoonMode` to `LessonMode` in `app/Packages/LessonKit/Sources/LessonKit/LessonMode.swift`. Differentiate `displaySubtitle`:
   - `writePickWord` → "Escribir — reconoce en inglés"
   - `writeTypeWord` → "Escribir — escribe la palabra"
   `writeFillGaps` stays in `ComingSoonMode` for v1.4.
- [ ] T004 [P] Add `prompt: z.string().optional()` to the client-facing `LessonQuestion` zod shape in `backend/src/domain/schemas.ts` (or wherever the start-lesson response is validated). No code consumes it yet.
- [ ] T005 [P] Add `hintUsed: z.boolean().optional()` to `AnswerRequest` zod schema in `backend/src/routes/lessons.ts`. Default `false`, mutually compatible with both `optionIndex` and `typedAnswer` paths.

**Checkpoint**: Backend + Swift have the enum vocabulary + DTO field. Nothing user-visible yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Distractor + service + repository changes that BOTH user stories below depend on. Tests precede implementation (Principle I).

### Backend foundation tests

- [ ] T006 [P] Vitest for `optionTextFor` in `backend/tests/unit/lessons/distractorBuilder.write.test.ts` (write_pick_word → English options; write_type_word + write_fill_gaps → option text is English even though caller doesn't show options).
- [ ] T007 [P] Vitest unit test in `backend/tests/unit/lessons/lessonService.prompt.test.ts` verifying that `LessonService.startLesson` populates `LessonQuestion.prompt` with `target.spanishOption` ONLY for write modes; absent for read + listen modes.
- [ ] T008 [P] Vitest contract test in `backend/tests/contract/lessons.start.write.test.ts` covering: `POST /v1/lessons` with `mode: write_pick_word` returns 10 questions where every `prompt` is non-empty and every `options` array contains the canonical English word; same for `mode: write_type_word` minus the options check.
- [ ] T009 [P] Vitest unit test for `hintUsed` mastery handling in `backend/tests/unit/lessons/masteryRepository.hint.test.ts` (correct answer with `hintUsed: true` resets `consecutiveCorrect` to 0 even when the answer is right; correct answer with `hintUsed: false` increments as before).

### Backend foundation implementation

- [ ] T010 Extend `optionTextFor` in `backend/src/lessons/distractorBuilder.ts` with cases for `write_pick_word`, `write_type_word`, `write_fill_gaps` — all return `word.base` (English) since the option axis is English in every write mode. Confirms FR-002.
- [ ] T011 Extend `LessonService.startLesson` in `backend/src/lessons/lessonService.ts` to populate `prompt: target.spanishOption` on each `LessonQuestion` when `mode` is one of the write modes. Read + listen modes leave `prompt` undefined. This is purely additive — no breaking change to the existing builders.
- [ ] T012 Extend `AnswerRequest` parsing in `backend/src/routes/lessons.ts` to pass `hintUsed` through to `LessonService.submitAnswer` when present. Refine the existing zod `.refine` so `hintUsed` doesn't interfere with the `optionIndex` XOR `typedAnswer` rule.
- [ ] T013 Extend `LessonService.submitAnswer` + `MasteryRepository.apply` in `backend/src/store/masteryRepository.ts` to accept an optional `hintUsed: boolean` and, when true, force `consecutiveCorrect = 0` regardless of outcome. Updates the mastery row but does NOT change the response shape.

**Checkpoint**: Backend boots, schema is exposed, but no UI is wired yet.

---

## Phase 3: User Story 1 — Write & Pick the English Word (Priority: P1)

**Story goal**: Student opens Home, sees the "Escribir — reconoce en inglés" card, picks a 10-question lesson where the Spanish meaning is the prompt and 4 English words are the options.

**Independent test criterion**: Full `write_pick_word` flow works end-to-end. UI shows Spanish prompt centered, 4 English option cards, audio plays the English word on reveal. Per-mode mastery for `write_pick_word` is independent of `read_pick_meaning` (a word mastered in read can still be pending in this mode).

### Tests for US1

- [ ] T014 [P] [US1] Vitest integration test in `backend/tests/integration/writePickWord.test.ts` (start lesson with `mode: write_pick_word` → 10 questions with non-empty `prompt` + 4 English options → answer all → complete → progress reflects per-mode mastery for `write_pick_word`).
- [ ] T015 [P] [US1] XCTest for `WritingLessonView` in option mode in `app/GramartEnglish/Tests/Unit/WritingLessonViewTests.swift` (renders prompt prominently, exposes options as `OptionCard`s, calls `onAnswer(idx)` on tap).
- [ ] T016 [P] [US1] XCTest for `LessonViewModel` carrying `prompt` through state at `app/GramartEnglish/Tests/Unit/WritingLessonViewModelTests.swift` (start lesson, verify `state.currentQuestion?.prompt == "clima"` for the seeded fake response).

### Implementation for US1

- [ ] T017 [US1] Extend the Swift `LessonQuestion` model in `app/Packages/LessonKit/Sources/LessonKit/LessonKit.swift` with `let prompt: String?`. Update the initializer + existing tests that construct `LessonQuestion` directly to pass `prompt: nil`.
- [ ] T018 [US1] Extend `BackendClient.LessonQuestionDTO` in `app/Packages/BackendClient/Sources/BackendClient/BackendClient.swift` with `let prompt: String?` (Codable optional → wire-back-compat). Also extend `BackendClient.AnswerLessonRequest` with `let hintUsed: Bool?` and a new `answerLesson(lessonId:questionId:typedAnswer:hintUsed:answerMs:)` overload.
- [ ] T019 [US1] Implement `WritingLessonView` at `app/GramartEnglish/Sources/Features/Lesson/WritingLessonView.swift`:
   - Renders `question.prompt` as the big centered text (style mirrors `LessonQuestionView`'s 56pt word but uses `.title` for prose-friendly Spanish).
   - When `mode == .writePickWord`: 4 `OptionCard`s vertically (same as F001 read mode), keyboard 1-4, "No lo sé" skip with `0`.
   - `.task(id: question.id)` triggers `SpeechService.shared.speakEnglish(question.word)` **only on reveal** (not on appear — Spanish-first display means we DON'T autoplay English at question time).
- [ ] T020 [US1] Update `LessonFlowView.questionView(for:state:)` in `app/GramartEnglish/Sources/App/RootView.swift` to dispatch `write_pick_word` → `WritingLessonView`. Listen + read paths unchanged.

**Checkpoint**: User can pick "Escribir — reconoce en inglés" from Home, take a 10-question lesson, see Spanish prompts + English options, hear the word on reveal, and see `perModeMastered.write_pick_word` move independently from read. Demoable.

---

## Phase 4: User Story 2 — Write & Type the English Word (Priority: P2)

**Story goal**: Variant of US1 where the user TYPES the English word instead of picking from options. Reuses F002's `TypedAnswerInputView` wholesale plus the new `hintUsed` mastery flag (FR-009).

**Independent test criterion**: Typed write mode works end-to-end with Levenshtein-1 tolerance, hint button reveals letters and disables mastery credit for that word, empty input routes to skip.

### Tests for US2

- [ ] T021 [P] [US2] Vitest integration test for `write_type_word` in `backend/tests/integration/writeTypeWord.test.ts` (exact match + typo-1 = correct; typo-2 = incorrect; empty = 400; `hintUsed: true` on a correct typed answer leaves the mastery row with `consecutiveCorrect=0` even after 2 right answers in a row).
- [ ] T022 [P] [US2] XCTest for `WritingLessonView` typed variant in `app/GramartEnglish/Tests/Unit/WritingLessonViewTypedTests.swift` (when `mode.isTyped`, renders `TypedAnswerInputView` in place of the option grid; pressing Enviar fires `onTypedAnswer(_:hintUsed:)`).
- [ ] T023 [P] [US2] XCTest for `LessonViewModel` typed write path at `app/GramartEnglish/Tests/Unit/WritingLessonViewModelTypedTests.swift` (sends `typedAnswer + hintUsed=true` when the user used a hint; reveal exposes `typedAnswerEcho`).

### Implementation for US2

- [ ] T024 [US2] Extend `TypedAnswerInputView` in `app/GramartEnglish/Sources/Features/Lesson/TypedAnswerInputView.swift` to call back with `hintUsed: Bool` based on whether `hintChars > 0` at submit time. Backward compatible: existing call sites in `ListeningLessonView` ignore the flag.
- [ ] T025 [US2] Extend `WritingLessonView` (from T019) to render `TypedAnswerInputView` instead of options when `mode == .writeTypeWord`. Pass through `question.prompt` + `question.word` as before.
- [ ] T026 [US2] Extend `LessonViewModel.answerTyped(_:hintUsed:)` in `app/GramartEnglish/Sources/Features/Lesson/LessonViewModel.swift` to accept the new flag and forward it to `BackendClient.answerLesson(...)`.
- [ ] T027 [US2] Update `LessonFlowView.questionView(for:state:)` to dispatch `write_type_word` → `WritingLessonView` with the typed callbacks wired.

**Checkpoint**: All 6 shipped modes work end-to-end (read + 3 listen + 2 write). F003 is code-complete pending polish.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: A11y audit, perf budget, docs merge, release alignment.

- [ ] T028 [P] Accessibility audit at `specs/003-writing-modes/design/a11y-audit.md` mirroring F002's audit format. Covers: differentiated subtitles on the two "Escribir" mode cards (avoid VoiceOver reading the same label twice), Spanish prompt VoiceOver label (`accessibilityLabel("Significado en español: <prompt>")`), `TypedAnswerInputView` reused-as-is reference to F002's audit.
- [ ] T029 [P] Backend perf bench `backend/perf/writeP95.test.ts` — `POST /v1/lessons` p95 ≤ 200 ms for `write_pick_word` AND `write_type_word`. Seeds 1 prior lesson so the distractor pool is realistic.
- [ ] T030 Merge `specs/003-writing-modes/contracts/openapi-delta.yaml` into the canonical `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml`; bump `info.version` to `1.3.0`. Mark the delta file as MERGED with a banner at the top (same pattern as F002).
- [ ] T031 Update repo `README.md` "Lesson modes" table — promote the two `write_*` rows from "Próximamente" to "Shipped (F003)". Add a short paragraph on the `write_pick_word` vs `write_type_word` distinction.

---

## Dependencies

```text
Phase 1 (Setup)         ──┐
                          ▼
Phase 2 (Foundational) ───┴──▶  Phase 3 (US1 write_pick_word)
                                       │
                                       ▼
                                Phase 4 (US2 write_type_word)
                                       │
                                       ▼
                                Phase 5 (Polish)
```

- Phase 1 strictly before Phase 2.
- Phase 2 strictly before Phase 3 (foundational `prompt` + `hintUsed` plumbing).
- US1 ships before US2 (US2 reuses `WritingLessonView` from T019).
- Polish runs last but `[P]` items can start once US1 lands.

## Parallel execution examples

Within Phase 2 every test file is parallel-safe (different paths):

```text
T006 (distractor) ║ T007 (prompt assembly) ║ T008 (contract) ║ T009 (hintUsed)
```

Within Phase 3 the three test tasks (T014, T015, T016) run together before any implementation, satisfying Test-First.

## Implementation strategy

1. **MVP slice**: Phase 1 → Phase 2 → Phase 3 (US1). At this checkpoint Home shows the new "Escribir — reconoce en inglés" card and the lesson plays. Already demoable.
2. **Layer in US2**: tiny incremental — same `WritingLessonView` with a different sub-render. Reuses everything F002 built for `listen_type`.
3. **Polish**: a11y audit, perf bench, README + OpenAPI merge.
4. **Release**: bump `v1.3.0` tag → triggers the existing Release workflow → publishes `.app` zip.

## Format validation

All tasks conform to `- [ ] <ID> [P?] [Story?] <description with file path>`. Setup / Foundational / Polish phases carry no story label by design. Phases 3-4 are labeled US1 / US2 respectively.

**Total tasks**: 31 (T001-T031). US3 (`write_fill_gaps`) is intentionally excluded — see `research.md` §1 for the masking spec ready for v1.4.

| Phase | Tasks | Range |
|-------|-------|-------|
| 1. Setup | 5 | T001-T005 |
| 2. Foundational | 8 | T006-T013 |
| 3. US1 — write_pick_word | 7 | T014-T020 |
| 4. US2 — write_type_word | 7 | T021-T027 |
| 5. Polish | 4 | T028-T031 |
