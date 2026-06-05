# F011 — Implementation Plan (v1.12.0)

## Branch / SHAs

- Branch: `feat/011-polish-pedagogy-round-v1.12.0`
- Base: `0eaced7` (Merge PR #17 — v1.11.0)
- Conventional commits per item:
  - `chore(F011 item 1)` — false-friend copy refinement (Lucía)
  - `feat(F011 item 2)` — padding-literal sweep + lint (Mariana)
  - `feat(F011 item 3)` — shortcuts cheatsheet ⌘/ (Priya)
  - `test(F011 item 4)` — snapshot totalCount regression net (QA)
  - `chore(release): v1.12.0 — F011 (polish + pedagogy round)`

## Modules touched

### Data corpus
- `data/cefr/a1.json` — `large` false-friend copy refined.
- `data/cefr/b1.json` — `assist` false-friend copy refined.
- `data/cefr/a2.json` — `success` already v1.10-style (no change).

### App (Swift)
- `app/GramartEnglish/Sources/App/RootView.swift` — ⌘`/` trigger button
  + cheatsheet sheet wiring.
- `app/GramartEnglish/Sources/Features/Help/ShortcutsCheatsheetView.swift`
  — **new**, the cheatsheet view.
- `app/GramartEnglish/Sources/Features/Lesson/ExamplesPanelView.swift` —
  `.padding(20)` → `Spacing.lg`.
- `app/GramartEnglish/Sources/Features/Lesson/HomeView.swift` —
  `.padding(32)` → `Spacing.xl`.
- `app/GramartEnglish/Sources/Features/Lesson/LessonSummaryView.swift` —
  `.padding(32)` → `Spacing.xl`.
- `app/GramartEnglish/Sources/Features/Lesson/ListeningLessonView.swift`
  — `.padding(28)` → `Spacing.xl`.
- `app/GramartEnglish/Sources/Features/Lesson/ModeCard.swift` —
  `.padding(16)` → `Spacing.md`.
- `app/GramartEnglish/Sources/Features/Lesson/VerbIntroCard.swift` —
  `.padding(16)` → `Spacing.md`.
- `app/GramartEnglish/Sources/Features/Onboarding/PlacementResultView.swift`
  — `.padding(32)` → `Spacing.xl`.
- `app/GramartEnglish/Sources/Features/Onboarding/WelcomeView.swift` —
  `.padding(32)` → `Spacing.xl`.
- `app/GramartEnglish/Sources/Features/Progress/MyWordsView.swift` —
  `.padding(24)` → `Spacing.lg`.

### Tests
- `app/GramartEnglish/Tests/Unit/DesignTokenContractTests.swift` —
  fourth lint regex for `.padding(N)` bare-number literals.
- `app/GramartEnglish/Tests/Unit/ShortcutsCheatsheetTests.swift` —
  **new**, 7 cases pinning content + a11y + Dynamic Type smoke.
- `app/GramartEnglish/Tests/Unit/SnapshotTotalCountTests.swift` —
  **new**, 5 cases pinning the snapshot generator invariant.

## Risk register

- **Swift 5.9 concurrency** — `LessonStateStore.flush()` is still the
  one place that bit us in F007. SnapshotTotalCountTests use the
  `debounceOverrideMillis = 0` + explicit `flush()` pattern established
  in F007 / F010; no new awaits in the persistence path.
- **Cheatsheet trigger** — hosting `.keyboardShortcut("/")` on a hidden
  Button is the SwiftUI-idiomatic path on macOS 14. The button is
  `accessibilityHidden` so VoiceOver doesn't announce a phantom
  "Atajos" control.
- **Padding lint scope** — the regex deliberately matches only
  `\.padding\(\s*\d+\s*[,)]`. The named-edge form `.padding(.top, N)`
  is not flagged this round.

## Verify gates

```
backend  → pnpm install && pnpm run lint:types && pnpm test
LessonKit → swift test
BackendClient → swift test
GramartEnglish → swift test
```

All four must be green before the release commit lands.
