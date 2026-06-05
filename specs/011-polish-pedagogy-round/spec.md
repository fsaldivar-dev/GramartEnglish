# F011 — Polish + Pedagogy Round (v1.12.0)

## Goal

A small polish-and-pedagogy round picking up four items the v1.11
review trio (Lucía, Mariana, Priya) and the QA pass left on the table:
three more A2-B1 false-friend refinements, the v1.11 `.padding(N)`
literal sweep Mariana asked for, Priya's keyboard cheatsheet, and a
regression net for the snapshot `totalCount` plumbing QA flagged.

No backend surface area, no schema migration, no new endpoint.
`schemaVersion` stays at 3; `openapi.info.version` and `version.json`
move 1.11.0 → 1.12.0.

## Locked scope (4 items)

### Item 1 — Lucía's false-friend trio refinement

Three entries already exist in the corpus; this round tightens the
Spanish copy so each gloss embeds the English target word inline (the
style Lucía codified in v1.10) rather than relying on the reader to
know what "long" / "to attend an event" / "evento" mean.

| Word      | Level | Status                                       |
| --------- | ----- | -------------------------------------------- |
| `success` | A2    | already v1.10-style — no change              |
| `large`   | A1    | refined: `… NO es 'largo' (que en inglés es long).` |
| `assist`  | B1    | refined: `… NO es 'asistir' (que es to attend an event).` |

### Item 2 — Mariana's `.padding(N)` literal sweep

Migrate the 9 bare-number `.padding(N)` call-sites in
`Sources/Features/` to the `Spacing.*` token scale Mariana finished in
v1.11, and extend `DesignTokenContractTests.testNoTokenLiteralsInFeatures`
with a fourth lint so future drift fails CI loudly.

| literal | token        | sites |
| ------- | ------------ | ----- |
| 16      | `Spacing.md` | ModeCard, VerbIntroCard |
| 20      | `Spacing.lg` | ExamplesPanelView (rounded up — inline note) |
| 24      | `Spacing.lg` | MyWordsView |
| 28      | `Spacing.xl` | ListeningLessonView (rounded up — inline note) |
| 32      | `Spacing.xl` | LessonSummaryView, HomeView, WelcomeView, PlacementResultView |

The new lint matches `.padding(N)` and `.padding(N, …)` (bare-number
first arg) — the named-edge form `.padding(.top, 8)` is deliberately
out of scope for this round.

### Item 3 — Priya's shortcuts cheatsheet (⌘`/`)

New view `Sources/Features/Help/ShortcutsCheatsheetView.swift` —
three labelled sections (Audio / Respuesta / Navegación) totalling 9
shortcuts. Each row is a monospaced key + Spanish action; VoiceOver
announces each row as a single `"<key>, <action>"` utterance via
`accessibilityElement(children: .combine)`.

Trigger: ⌘`/` from anywhere — a zero-size, opacity-0,
accessibility-hidden button in `ReadyFlowView`'s ZStack hosts the
shortcut and toggles a sheet. Esc closes via `.cancelAction`.

### Item 4 — Snapshot `totalCount` plumbing regression net

QA flagged that v1.11 Polish A plumbed `totalCount` through the
CONSUMER side (`ResumeLessonCard`) but a small window existed where
the SNAPSHOT GENERATOR could emit `nil` — any new persistence
call-site that bypassed `snapshot(for:)`.

Audit: every save in `LessonViewModel` routes through
`persistSnapshot()` → `snapshot(for:)`, which always sets
`totalCount: state.questions.count`. The audit was clean.

This item ships a regression net (`SnapshotTotalCountTests.swift`,
5 cases) covering: after `start()`, after `answer()`, after
`dismissVerbIntro()`, after `skip()`, and after a mid-lesson abandon.

## Out of scope

- Backend changes (no schema, no endpoint, no `openapi.yaml` shape).
- Named-edge `.padding(.top, N)` migration — follow-up pass.
- Cheatsheet menu-bar integration (Help menu wiring stays as-is; the
  ⌘`/` shortcut is the primary discovery path).

## Personas in the room

- **Lucía** — pedagogy lead. Item 1 false-friend copy refinement.
- **Mariana** — design tokens lead. Item 2 padding sweep + lint.
- **Priya** — onboarding / UX lead. Item 3 cheatsheet.
- **QA** — Item 4 regression net.

See `specs/team-personas.md` for full role context.
