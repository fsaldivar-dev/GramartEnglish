# F010 — Design System Completion + Resume CTA + 4 False-Friends (v1.11.0)

## Goal

Finish the design-token migration that v1.8 (F007) opened and v1.9
(F008) advanced; pay the v1.10 audit IOUs Mariana flagged on
`AnswerFeedbackView` and `FallbackBannerView`; warm-tune the dark
Semantic palette; add a resume CTA on the lesson summary so an
abandoned in-flight lesson isn't lost to the next "empezar otra"
click; add Lucía's four new A2-B1 false-friend belt entries.

This is a polish + hygiene release. No backend surface area changes;
`schemaVersion` stays at 3; `openapi.info.version` and `version.json`
move 1.10.0 → 1.11.0.

## Locked scope (4 items)

### Item 1 — Mariana token literal sweep (FINISH)

Migrate every remaining raw design literal in `Sources/Features/` (and
the one offender in `App/RootView`) to the token API introduced in
F007 / F008:

- **13 `cornerRadius: N` literals** → `Radius.{sm, md, lg}`
  - `6` → `Radius.sm` (smallest token is sm=8; rounded up).
  - `10` → `Radius.md` (12).
  - `14` → `Radius.md` (between md=12 and lg=16; rounded DOWN to
    preserve the F007 visual rhythm — comment in ModeCard explains).
- **5 `.tint.opacity(0.X)` literals** → `Tint.{soft, medium, strong}`
  - `0.12` → `Tint.soft`; `0.18` → `Tint.medium`; `0.15` → `Tint.soft`
    (nearest token).
- **5 raw `.green/.red/.orange` `foregroundStyle(…)` sites** →
  `Semantic.{success, error, warning}`
  - `AnswerFeedbackView.badgeColor` (3 cases); `borderColor` (2 cases).
  - `FallbackBannerView` icon.

The `DesignTokenContractTests.testNoTokenLiteralsInFeatures` walker
now lints all three classes with the same offender-list shape as the
F008 `.system(size:)` lint — future drift fails CI loudly.

### Item 2 — Lucía's 4 new A2-B1 false-friend entries

| Word          | Level | Trap                                                   |
| ------------- | ----- | ------------------------------------------------------ |
| `embarrassed` | A2/B1 | _embarazada_ = pregnant (refined copy, "socialmente")  |
| `record`      | A2    | _recordar_ = to remember (record = grabar)             |
| `attend`      | B1    | _atender_ = to serve / take care of (attend = asistir) |
| `discuss`     | B1    | _discutir_ = to argue (discuss = hablar de)            |

`embarrassed` already existed at A2 from v1.9; copy is updated to
Lucía's refined version on both A2 and B1 rows. Round-trip pinned by
`backend/tests/unit/store/falseFriend.f010.test.ts`.

### Item 3 — Priya P1: Resume-lesson CTA from Summary

When `LessonSummaryView` renders and `LessonStateStore.shared.load()`
returns a snapshot with a `lessonId` ≠ the summary's, surface a
"Continuar lección anterior" card above the existing CTAs.

- New `Features/Lesson/ResumeLessonCard.swift` — token-clean
  (`Radius.md`, `Tint.soft`, `Spacing.sm/md`).
- `LessonSummaryView` gains `resumableSnapshot:` + `onResumeLesson:`
  and a public `shouldShowResumeCard` predicate (testable).
- `LessonFlowView` probes the store in the summary's `.task` and
  forwards via `onResumeLeftover:`; RootFlowView phase-hops to
  `.lesson(snap.level, snap.mode, resumeId: snap.lessonId)`.

### Item 4 — Warm-tune dark Semantic palette

Mariana's latina-warm pass on the dark-appearance hexes:

|         | Light (unchanged) | Dark (v1.10 → v1.11) |
| ------- | ----------------- | -------------------- |
| Warning | `#B45309`         | `#FBBF24` → `#F5C242` |
| Error   | `#B91C1C`         | `#F87171` → `#EF5B5B` |

Both still pass WCAG AA on `#1E1E1E` (warning ≈ 10.2:1, error ≈ 5.1:1).
Updates flow through `Assets.xcassets/{SemanticWarning, SemanticError}`
+ `DesignTokens.Semantic.{warning, error}` + the `…DarkHex` constants
+ the `SemanticColorsTests` dark-bg contrast pins.

## Out of scope

- Any new backend endpoint, schema migration, or OpenAPI shape change.
- Token propagation to non-`Sources/Features/` modules (LessonKit /
  BackendClient view code stays as-is; they don't render UI).
- Re-tuning the light palette (Mariana: ship the dark warm-tune first).

## Personas in the room

- **Mariana** — design tokens lead. Drove items 1 + 4; signed off on
  the rounding policy and the warm-tune hexes.
- **Lucía** — pedagogy lead. Locked the four new A2-B1 false-friend
  copies (item 2).
- **Priya** — onboarding / UX lead. P1 owner for item 3.

See `specs/team-personas.md` for full role context.
