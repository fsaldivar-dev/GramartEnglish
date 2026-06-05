# F007 Tasks (v1.8.0) — TDD order

## Item 1 — Persistence (Priya)

- [x] T1.1 Test: `LessonStateStoreTests` — round-trip, corruption recovery, atomic write under concurrency, debounce coalescing.
- [x] T1.2 Code: `LessonStateStore` + `LessonStateSnapshot` (`Sources/Shared/Persistence/`).
- [x] T1.3 Test: extend `LessonViewModelTests` — snapshot fires on start/answer/next, clears on complete.
- [x] T1.4 Code: wire `persistSnapshot()` into every `phase = …` site in `LessonViewModel`.
- [x] T1.5 Code: `RootView.initialPhase` consults the store, validates against `progress.resumable`, routes into the lesson flow or clears stale snapshot.

## Item 2 — Prosody (Lucía)

- [x] T2.1 Test: `SpeechRateTests` — pins `.normal = 0.42`, `.slow = 0.35`, monotonic gap ≥ 0.05.
- [x] T2.2 Code: `SpeechRate` enum + named-rate overload in `SpeechService`.
- [x] T2.3 Code: `SpeakButton` gains a `rate: SpeechRate` parameter + slow-mode symbol + a11y wiring.
- [x] T2.4 Code: dual buttons in `VerbIntroCard` (base + example sentence), `LessonQuestionView`, `AnswerFeedbackView`.
- [x] T2.5 Test: update `SpeechCallSiteAuditTests` line numbers + exclude `SpeechService.swift` from the audit (trampoline).

## Item 3 — DesignTokens (Mariana)

- [x] T3.1 Test: `DesignTokenContractTests` — pin Spacing/Radius/Tint scales + presence of Semantic colours.
- [x] T3.2 Code: `Sources/Design/DesignTokens.swift`.
- [x] T3.3 Code: `LessonSummaryView` — Dynamic Type fix on score, SF Symbols replace emoji badges, Semantic colours replace `.green`/`.orange`/`.red` literals.
- [x] T3.4 Code: `WritingLessonView.spanishPromptHero` — same Dynamic Type fix.
- [x] T3.5 Test: `LessonSummaryDynamicTypeTests` — smoke test that the view constructs cleanly at extreme Dynamic Type sizes.

## Item 4 — Distractor fix (Lucía)

- [x] T4.1 Test: `verbConjugationBuilder.test.ts` — update existing test, add "NEVER over-regularized as option" regression guard.
- [x] T4.2 Code: drop `overRegularize` from the desired-distractor slot list in `verbConjugationBuilder`.
- [x] T4.3 Test: `lessonService.feedbackHint.test.ts` — typing `goed` for `go` returns the hint; correct answers don't; unrelated wrong answers don't.
- [x] T4.4 Code: `maybeOverRegularizationHint` in `LessonService.submitAnswer`; populate `feedbackHint` on the response.
- [x] T4.5 Code: add `feedbackHint` to `BackendClient.AnswerLessonResponse` (Swift).
- [x] T4.6 Code: add `feedbackHint` to `AnswerOutcome` (LessonKit), propagate through `LessonViewModel`.
- [x] T4.7 Test + Code: `AnswerFeedbackHintTests` — outcome preserves the hint; `AnswerFeedbackView` renders the hint when present and renders cleanly when nil.

## Item 5 — Docs + release

- [x] T5.1 Commit `specs/team-personas.md`.
- [x] T5.2 Bump `version.json` → 1.8.0; bump `BackendClient.clientVersion` → 1.8.0; update audit test.
- [x] T5.3 Update README + CLAUDE.md.
- [x] T5.4 Update `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml` info.version + document `feedbackHint`.
