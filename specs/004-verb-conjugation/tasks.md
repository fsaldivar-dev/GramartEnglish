# F004 v1.6.0 — Tasks

Test-First discipline: the failing test for each layer lands before the implementation in that layer.

## Phase 0 — Corpus

- **T001** Hand-curate `data/cefr/verbs.json` (60 verbs, 40 A2 + 20 B1, ~50% irregular). [done]
- **T002** Augment `data/cefr/a2.json` (14 new verbs) and `data/cefr/b1.json` (7 new verbs) so every `verbs.json` base has a `vocabulary_words` row. [done]
- **T003** Document the verb schema in `data/cefr/README.md`. [done]

## Phase 1 — Backend tests (red)

- **T010** [P] Write `backend/tests/unit/lessons/verbConjugationBuilder.test.ts` — distractor recipe, over-regularization rule, MCQ shape, collision fallback, determinism. [done]
- **T011** [P] Write `backend/tests/unit/lessons/lessonService.conjugate.test.ts` — startLesson assembles 10 conjugate_pick_form questions, mode dispatches correctly, missing-corpus throws. [done]

## Phase 2 — Backend impl (green)

- **T020** Add `conjugate_pick_form` to `LessonMode` enum in `backend/src/domain/schemas.ts`; add `isConjugationMode` + `CONJUGATION_MODES` exports; extend `LessonQuestion` zod schema with `verbBase?` and `targetTense?`. [done]
- **T021** Create `backend/src/store/verbRepository.ts` — `VerbRow`, `VerbRepository`, `loadVerbCorpus(corpusDir, wordRepo)`. [done]
- **T022** Create `backend/src/lessons/verbConjugationBuilder.ts` — `overRegularize`, `buildVerbQuestion`. [done]
- **T023** Wire `LessonService.startLesson` to dispatch `conjugate_pick_form` to a new private `startConjugationLesson`; update `describeLesson` to rehydrate prompt/verbBase/targetTense for resumed lessons. [done]
- **T024** Wire `VerbRepository` into `backend/src/routes/lessons.ts` and pass `corpusDir` through `backend/src/server.ts`. [done]

## Phase 3 — Swift tests (red)

- **T030** [P] Bump `LessonModeTests.swift` count assertions (7 → 8); add cases for `.conjugatePickForm` icon/display/conjugation flag. [done]
- **T031** [P] Write `ConjugationLessonViewTests.swift` — Spanish-infinitive parser, prompt copy pin, DTO carries verbBase + targetTense. [done]
- **T032** [P] Update `ModeCardComingSoonTests.swift` + `ModeCardTests.swift` to reflect the (now empty) `ComingSoonMode` and the shipped Conjugar card. [done]

## Phase 4 — Swift impl (green)

- **T040** Add `.conjugatePickForm` to `LessonMode`; drop it from `ComingSoonMode`; add `isConjugation` flag; bump `SHIPPED_MODES` to 8. [done]
- **T041** Add `verbBase` + `targetTense` to `LessonKit.LessonQuestion`. [done]
- **T042** Add the same fields to `BackendClient.LessonQuestionDTO`; bump `clientVersion` to "1.6.0". [done]
- **T043** Create `app/GramartEnglish/Sources/Features/Lesson/ConjugationLessonView.swift`. [done]
- **T044** Dispatch `.conjugatePickForm` → `ConjugationLessonView` in `RootView.questionView(for:state:)`. [done]

## Phase 5 — Contracts + version

- **T050** Bump `version.json` to 1.6.0. [done]
- **T051** Bump `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml` to 1.6.0; add enum value + 2 optional fields. [done]
- **T052** Write `specs/004-verb-conjugation/contracts/openapi-delta.yaml` (historical record). [done]

## Phase 6 — Docs

- **T060** Update README.md "Latest release" + modes table. [pending — see below]
- **T061** Update CLAUDE.md "Active feature" pointer. [pending — see below]

## Phase 7 — Verify

- **T070** `cd backend && pnpm install && pnpm run lint:types && pnpm test`.
- **T071** `cd app/Packages/LessonKit && swift test`.
- **T072** `cd app/Packages/BackendClient && swift test`.
- **T073** `cd app/GramartEnglish && swift test` (or `./scripts/build-app.sh` if present).
- **T074** Commit per layer; final release commit `chore(release): v1.6.0 — conjugate_pick_form (F004 US1)`.

## Deferred from v1.6.0 (re-open in F004 US2+)

- `conjugate_type_form` mode (typed input variant).
- `conjugate_listen_pick_base` mode (reverse-recognition listening variant).
- Tenses: `past_participle`, `gerund`, `third_person`.
- Promote `verbs.json` to a `verbs` SQL table if the corpus grows past ~150 entries or tenses multiply.
- Rules engine for unseen regular verbs.
- `alternates` array (`learned / learnt`, `traveled / travelled`).
