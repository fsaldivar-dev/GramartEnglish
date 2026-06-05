# F007 — Persistence, Prosody, Tokens & Distractor Hygiene (v1.8.0)

**Status**: shipped 2026-06-05.
**Decided by**: PO + TL. Scope locked at 4 items — no additions in implementation.
**Inputs**: persona feedback after v1.7.0 (see [team-personas.md](../team-personas.md)) — Priya, Lucía, Mariana.

## Why this cycle

After v1.7.0 the team evaluated the app against the 5 evaluator personas. The cycle picks the **smallest set of fixes that close the highest-confidence injuries** — not a rewrite. Four items, one PR per item, total impact bounded.

## US1 — Persistence (Priya)

**As** a learner who needs to step away mid-lesson **I want** my progress to survive `Cmd+Q` / crash / force-kill **so that** I don't lose ~15 min of work and the affective injury that comes with it.

- FR-001 The client persists an in-flight `LessonStateSnapshot` to `~/Library/Application Support/GramartEnglish/lesson-state.json` on every lesson-VM phase transition.
- FR-002 Writes are atomic (write `.tmp` then `replaceItem`) and debounced (≤1 write per 500ms).
- FR-003 Corrupt JSON on load is deleted; load returns nil; the app starts at Welcome/Home as if no snapshot existed.
- FR-004 On launch, when a local snapshot's `lessonId` matches the server's `progress.resumable.lessonId`, the app routes directly into the lesson flow.
- FR-005 The snapshot is cleared eagerly on lesson complete and on any "abandoned" terminal state.

## US2 — Prosódico audio (Lucía)

**As** an A1 learner trying to mimic a new English word **I want** to hear it at slow speed **so that** I can self-correct each phoneme before committing.

- FR-006 `SpeechService` exposes a named `SpeechRate` enum with two values: `.normal` (0.42) and `.slow` (0.35). Concrete values pinned by tests.
- FR-007 The verb-intro card (`VerbIntroCard`), `LessonQuestionView`, and `AnswerFeedbackView` render a slow-rate companion button (`tortoise.fill`) next to the existing normal-rate speaker, with keyboard shortcut `D`.
- FR-008 The verb-intro card also exposes both rates for the **example sentence**, not just the verb base.

## US3 — Design tokens + Dynamic Type fixes (Mariana)

**As** a low-vision learner using `accessibility5` Dynamic Type **I want** the lesson summary and Spanish prompt to scale instead of clipping **so that** I can read the numbers without zooming the OS.

- FR-009 A `DesignTokens.swift` file establishes `Spacing`, `Radius`, `Tint`, and `Semantic` (success/warning/error) tokens. Asset-catalog colour migration deferred to v1.9; v1.8.0 ships system fallbacks.
- FR-010 `LessonSummaryView` switches the score from `.system(size: 80)` to `.system(.largeTitle).minimumScaleFactor(0.5)`.
- FR-011 `WritingLessonView`'s Spanish prompt hero switches from `.system(size: 44)` to the same Dynamic-Type-respecting pattern.
- FR-012 Lesson-summary emoji badges are replaced with SF Symbols (`book.fill`, `ear.fill`, `headphones`, `pencil`, `arrow.triangle.2.circlepath`).
- FR-013 Hardcoded `.green` / `.orange` / `.red` colour literals in the summary route through `Semantic.success` / `.warning` / `.error`.

## US4 — Remove `overRegularize` as visible distractor (Lucía)

**As** an A1 learner being assessed on the past form of `go` **I want** the wrong options to be plausible irregular forms, not "goed" **so that** the test isn't teaching me the error.

- FR-014 The `conjugate_pick_form` distractor recipe ships `[base, past_participle, random_other_past_at_level]` — never the over-regularized `<base>ed`.
- FR-015 The over-regularized form is still generated server-side and surfaced as `feedbackHint` on the answer response when the learner *commits* to it (typed write modes targeting verbs, defensive fallback for picker modes).
- FR-016 `AnswerFeedbackView` renders the `feedbackHint` markdown-formatted under the wrong-answer banner, tinted via `Semantic.warning.opacity(Tint.soft)`.

## Success criteria

- Cmd+Q mid-lesson → relaunch lands on the same question (FR-004 manual verification).
- Pressing `D` on the verb-intro card plays the verb at audibly slower rate (FR-006/007 manual verification; `SpeechRateTests` pins the numeric delta ≥ 0.05).
- LessonSummaryView at Dynamic Type `accessibility5` does not clip the score (FR-010 manual verification + `LessonSummaryDynamicTypeTests` smoke).
- A `conjugate_pick_form` lesson for `go` shows `went/go/gone/+random-A2-past` and never `goed` (FR-014 — backend regression test).
- Typing `goed` in a write-mode lesson for `go` returns `feedbackHint` containing "irregular" and "went" (FR-015 — backend test).

## Non-goals (explicitly out of scope)

- Asset-catalog Semantic colours (v1.9, Mariana).
- Token propagation across every view (v1.9, Mariana).
- Conjugation in non-past tenses (future feature, Siobhán).
- TBLT task-based lessons (B1+, James — backlog).
