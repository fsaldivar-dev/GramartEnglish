---
description: "Implementation plan for Verb Conjugation MVP (Feature 004, v1.6.0)"
---

# Implementation Plan: Verb Conjugation (v1.6.0)

**Branch**: `feat/004-verb-conjugation-v1.6.0` | **Date**: 2026-06-05 | **Spec**: [./spec.md](./spec.md)

## Summary

Ship `conjugate_pick_form` — the MCQ variant of verb conjugation drilling — as the v1.6.0 release. Scope locked by PO+TL to a single mode (MCQ), a single tense (simple past), and two CEFR levels (A2 + B1) backed by a 60-verb hand-curated corpus. Zero new SQL tables, `schemaVersion` stays at 3, mastery axis reuses `(userId, wordId, mode)` unchanged.

The architectural lever: each verb's English `base` already exists (or is added) in `vocabulary_words`, so the verb-specific metadata (`simple_past`, `past_participle`, `irregular`, Spanish `es`) lives in a side-channel JSON (`data/cefr/verbs.json`) that overlays the existing row. No FK changes. No migration.

## Technical Context

**Language/Version**: TypeScript on Node.js 20 LTS (backend); Swift 5.9 / SwiftUI on macOS 14+ (app).

**Primary Dependencies**: Fastify 5, better-sqlite3, zod (backend); SwiftUI, local `LessonKit` + `BackendClient` packages (app).

**Storage**: SQLite via better-sqlite3. `schemaVersion` stays at **3**; no migration. The new `verbs.json` is a side-channel corpus loaded once at boot.

**Testing**: Vitest (backend unit + contract + integration + perf); XCTest (Swift packages + app).

**Target Platform**: macOS 14 (Sonoma) or later, Apple Silicon (arm64).

**Performance Goals**: Inherited from prior releases — backend p95 ≤ 200 ms. The conjugation start path is O(N) over a 40-element pool plus 4 options × 10 questions, so well under budget.

**Scale/Scope**: Active modes go 7 → **8 shipped**. Estimated tasks ~14.

## Constitution Check

| Principle | Check | Status |
|---|---|---|
| **I. Test-First** | `verbConjugationBuilder.test.ts` lands before the builder; `lessonService.conjugate.test.ts` before the service wiring; `LessonModeTests.swift` count assertion bumped before `LessonMode` is touched; `ConjugationLessonViewTests.swift` pins prompt copy before the view exists. | ✅ |
| **II. Library-First** | No new Swift packages. Reuse `OptionCard`, `ProgressHeader`, `AnswerFeedbackView`. New code stays inside existing module boundaries. | ✅ |
| **III. Simplicity & YAGNI** | Side-channel JSON instead of a new `verbs` table avoids schemaVersion bump + migration + rollback. `over_regularize` is `base + "ed"` — no special-casing for trailing-e because the L2 mistake doesn't apply that rule either. Tense filter UI deferred (only one tense ships). | ✅ |
| **IV. Observability** | No new endpoints. Existing `lesson.started` / `lesson.answered` log events apply unchanged. | ✅ |
| **V. Versioning & Breaking Changes** | `version.json`: 1.5.3 → **1.6.0** (MINOR — new mode). `schemaVersion` stays at 3. OpenAPI 1.5.1 → **1.6.0** (additive: 1 enum value + 2 optional DTO fields). Backward compatible. | ✅ |
| **VI. Security & Privacy** | No new data collection. No external network. | ✅ |
| **VII. Accessibility** | Spanish-locale a11y label on the prompt hero ("Pasado simple del verbo en español: <es>") + hint ("Elige la forma correcta del pasado simple en inglés"). `OptionCard` already audited in F002 a11y pass. | ✅ |
| **VIII. Performance Budgets** | Same budgets. No new hot paths. | ✅ |

**Gate result**: PASS.

## Project Structure

### Backend
- `backend/src/domain/schemas.ts` — add enum value + DTO fields + `isConjugationMode` helper.
- `backend/src/store/verbRepository.ts` — **new**. In-memory verb corpus + lookup-by-base / by-wordId / random-sample.
- `backend/src/lessons/verbConjugationBuilder.ts` — **new**. Pure question builder with distractor recipe + collision fallback.
- `backend/src/lessons/lessonService.ts` — branch `startLesson` on `mode === 'conjugate_pick_form'`; delegate to the verb path. `describeLesson` rehydrates `prompt + verbBase + targetTense` on resume.
- `backend/src/routes/lessons.ts` — wire `VerbRepository` into the route's `LessonService` instance.
- `backend/src/server.ts` — pass `corpusDir` to `registerLessonRoutes`.

### Swift app
- `app/Packages/LessonKit/Sources/LessonKit/LessonMode.swift` — add `.conjugatePickForm`; promote out of `ComingSoonMode`; add `isConjugation` flag; bump SHIPPED_MODES to 8.
- `app/Packages/LessonKit/Sources/LessonKit/LessonKit.swift` — add `verbBase` + `targetTense` to `LessonQuestion`.
- `app/Packages/BackendClient/Sources/BackendClient/BackendClient.swift` — add fields to `LessonQuestionDTO`; bump `clientVersion` to "1.6.0".
- `app/GramartEnglish/Sources/Features/Lesson/ConjugationLessonView.swift` — **new**. Prompt hero + 4 `OptionCard`s.
- `app/GramartEnglish/Sources/App/RootView.swift` — dispatch `.conjugatePickForm` → `ConjugationLessonView`.

### Corpus
- `data/cefr/verbs.json` — **new**. 60 verbs.
- `data/cefr/a2.json` — augment with 14 verbs needed for the corpus that weren't already there.
- `data/cefr/b1.json` — augment with 7 verbs.
- `data/cefr/README.md` — document the verb schema + invariants.

### Contracts
- `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml` — version 1.6.0; add enum value + 2 optional schema fields.
- `specs/004-verb-conjugation/contracts/openapi-delta.yaml` — historical record of what F004 v1.6.0 added.

## Risks + mitigations

1. **Distractor collision on regular verbs** (`travel → traveled` × 3 slots). Mitigated by the deterministic top-up that fills from same-level past forms; tested with a fixed-seed unit test.
2. **`overRegularize("bake") = "bakeed"` looks linguistically silly.** Intentional — this is the *learner mistake* we want to surface, not the linguist's spelling rule. Documented inline.
3. **`verbs.json` row whose `base` is not in `vocabulary_words`.** The loader silently skips such rows and the test `verbConjugationBuilder.test.ts` asserts every verb resolves a `wordId > 0` in the production corpus. Augmented a2.json/b1.json with the 21 missing bases so this never fires in prod.
4. **`ModeCardComingSoonTests` references `ComingSoonMode.conjugatePickForm`.** Updated to assert the enum is now empty.

## Out of scope reminders (v1.6.0)

- US2 (`conjugate_type_form`) and US3 (`conjugate_listen_pick_base`).
- Other tenses.
- Migration to a real `verbs` table.
- Rules engine for unseen regular verbs.
