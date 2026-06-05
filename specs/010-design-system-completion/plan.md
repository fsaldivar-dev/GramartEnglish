# F010 — Implementation Plan (v1.11.0)

## Branch / SHAs

- Branch: `feat/010-design-system-completion-v1.11.0`
- Base: `137961c` (Merge PR #16 — v1.10.0)
- Conventional commits per item:
  - `feat(F010 item 2)` — corpus + belt test
  - `feat(F010 item 1)` — token literal sweep + tightened lint
  - `feat(F010 item 4)` — warm-tune dark palette
  - `feat(F010 item 3)` — resume CTA from summary
  - `chore(release): v1.11.0 — F010 (…)` — version + docs

## Modules touched

### Backend
- `data/cefr/a2.json` — `record` (new), `embarrassed` (refined copy).
- `data/cefr/b1.json` — `attend`, `discuss` (new); `embarrassed` (refined).
- `backend/tests/unit/store/falseFriend.f010.test.ts` — round-trip pin
  for the four entries (4 cases).

### App (Swift)
- `app/GramartEnglish/Sources/Design/DesignTokens.swift` — Semantic
  `warning`/`error` darkHex constants + header palette doc.
- `app/GramartEnglish/Sources/App/RootView.swift` — token sweep
  (1 site) + LessonFlowView wiring of `onResumeLeftover` +
  `leftoverSnapshot` state.
- `app/GramartEnglish/Sources/Features/Lesson/AnswerFeedbackView.swift`
  — 4 `cornerRadius` literals + 5 raw colors.
- `app/GramartEnglish/Sources/Features/Lesson/ExamplesPanelView.swift`
  — 1 `cornerRadius` literal.
- `app/GramartEnglish/Sources/Features/Lesson/FallbackBannerView.swift`
  — 1 raw color (`.orange` → Semantic.warning).
- `app/GramartEnglish/Sources/Features/Lesson/HomeView.swift` —
  1 `cornerRadius` + 2 tint opacities.
- `app/GramartEnglish/Sources/Features/Lesson/LessonSummaryView.swift`
  — `resumableSnapshot:` + `onResumeLesson:` params + card insertion.
- `app/GramartEnglish/Sources/Features/Lesson/ListeningLessonView.swift`
  — 1 tint opacity.
- `app/GramartEnglish/Sources/Features/Lesson/ModeCard.swift` —
  2 `cornerRadius` + 1 tint opacity.
- `app/GramartEnglish/Sources/Features/Lesson/ResumeLessonCard.swift`
  — **new**, the Priya P1 CTA card.
- `app/GramartEnglish/Sources/Features/Onboarding/PlacementQuestionView.swift`
  — 1 tint opacity + 2 `cornerRadius` literals.
- `app/GramartEnglish/Sources/Features/Onboarding/PlacementSelfReportView.swift`
  — 2 `cornerRadius` literals.
- `app/GramartEnglish/Sources/Resources/Assets.xcassets/SemanticWarning.colorset/Contents.json`
  — dark variant hex.
- `app/GramartEnglish/Sources/Resources/Assets.xcassets/SemanticError.colorset/Contents.json`
  — dark variant hex.

### Tests
- `app/GramartEnglish/Tests/Unit/DesignTokenContractTests.swift` —
  add `testNoTokenLiteralsInFeatures` (3 lints in one walker).
- `app/GramartEnglish/Tests/Unit/SemanticColorsTests.swift` — re-pin
  dark-bg contrast assertions for the new hexes.
- `app/GramartEnglish/Tests/Unit/LessonSummaryResumeCardTests.swift`
  — **new**, 4 cases on `shouldShowResumeCard` + callback wiring.

## Risk register

- **Swift 5.9 concurrency** — `LessonStateStore` flush timing is the
  one place that bit us in F007. We do not introduce new awaits in
  the summary flow; the `.task` on the summary already runs on the
  MainActor and the snapshot load is synchronous.
- **TestFlag pattern** — no new TestFlag introduced; the resume card
  predicate is pure and observable on the view.
- **Asset catalog drift** — the `actool` (Xcode) path and the SPM
  fallback hexes are both updated to `#F5C242` / `#EF5B5B`; the
  `SemanticColorsTests` dark-bg contrast tests pin both.

## Verify gates

```
backend  → pnpm install && pnpm run lint:types && pnpm test
LessonKit → swift test
BackendClient → swift test
GramartEnglish → swift test
```

All four must be green before the release commit lands.
