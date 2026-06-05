# F011 — Research notes (v1.12.0)

Compact notes on the decisions behind the four locked items.

## Item 1 — False-friend copy style (Lucía)

v1.10 codified the embedded-English style: the Spanish gloss names the
English target word inline so a learner who doesn't know the contrast
verb can still resolve the trap.

- `large` (A1) — old: `… NO es 'largo' (que significa long)`. New:
  `… NO es 'largo' (que en inglés es long).` The `que en inglés es`
  framing is the v1.10 default (it appears on `library`, `exit`,
  `carpet`, `fabric`).
- `assist` (B1) — old: `… NO es 'asistir' (que es ir a un evento).`
  New: `… NO es 'asistir' (que es to attend an event).` The English
  phrase is the actual verb the learner will later read in a B1+
  context; "ir a un evento" is a paraphrase that doesn't help with
  recognition.
- `success` (A2) — already shipped in the v1.10 style; verified, no
  change.

## Item 2 — Spacing scale rounding policy (Mariana)

The `Spacing` enum has 8/12/16/24/32 (no 20 or 28). The v1.11 rubric
Mariana wrote on the corner-radius sweep: round to the nearest token,
prefer the lower step when between scales. Two sites this round are
between steps:

- `ExamplesPanelView`'s `padding(20)` — between sm=12 and lg=24.
  Rounded UP to `Spacing.lg`. Rationale: the side-panel layout reads
  cramped at 12; 24 keeps the row gap clearly distinct from the
  padding.
- `ListeningLessonView`'s `padding(28)` (hero "S/D" letter) — between
  lg=24 and xl=32. Rounded UP to `Spacing.xl`. Rationale: the circle
  background is generous-by-design and 24 closed the visual gap
  between the glyph and the chrome.

Both rounding decisions are documented inline at the call-site.

## Item 3 — Cheatsheet keyboard discovery (Priya)

The macOS-idiomatic discovery path for a keyboard cheatsheet is two
prongs: (1) a `Help` menu item (`Show Keyboard Shortcuts`), and (2)
a global keyboard shortcut (the Affinity / Sketch / Notion convention
is `⌘?` or `⌘/`).

This round ships only the keyboard path (`⌘/`). The Help menu wiring
is out of scope (no menu commands are currently customised; the
`GramartEnglishApp` ships the default menus). A follow-up can add the
`CommandGroup(replacing: .help)` once a second help item appears.

### Why a hidden Button hosts the shortcut

SwiftUI `.keyboardShortcut` requires a focusable control. The
SwiftUI-idiomatic way to host a global app shortcut on macOS without
a visible button is a zero-size, opacity-0 button inside the root
ZStack. We `.accessibilityHidden(true)` it so VoiceOver doesn't
announce a phantom "Atajos" control.

### Spanish copy choices

The action descriptions mirror the existing UI copy: `Escuchar`
matches `SpeakButton`'s accessibilityLabel; `Elegir opción` matches
the placement-question prompt; `Empezar de nuevo` from F007's resume
banner. Keeps voice consistent across the app.

## Item 4 — Snapshot totalCount audit (QA)

Audit found every snapshot persistence in `LessonViewModel.swift`
routes through `persistSnapshot()` → `snapshot(for:)`, and that
builder ALWAYS sets `totalCount: state.questions.count` for both
`.answering` and `.revealing` cases. The non-resumable phases
(`.idle`, `.loading`, `.completing`, `.summary`, `.failed`) return
nil from the builder, which routes to `stateStore.clear()` — also
correct.

No code change shipped this round; just the test pin.

The "abandon mid-lesson" scenario doesn't clear the store: RootView's
`onExit` callback routes through `goHome(level:)` without calling
`LessonStateStore.shared.clear()`. The last persisted snapshot
remains on disk with `totalCount` intact for the next launch's
`ResumeLessonCard` to read.
