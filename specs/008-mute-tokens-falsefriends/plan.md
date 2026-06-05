# F008 — Implementation plan

## Sequencing

The four items are independent at the file level; we sequence by surface area
to minimize line-number churn in the SpeechCallSiteAudit:

1. **Item 4** — RootView wiring (1 file, 0 line shifts in lesson views).
2. **Item 1** — `MuteToggleButton` + lesson chrome edits. Shifts line
   numbers in 4 lesson views. Audit manifest updated in the same commit.
3. **Item 2** — Token sweep. Further line shifts handled in the audit
   update from Item 1.
4. **Item 3** — False-friend belt. Touches data, backend, BackendClient,
   LessonKit, AnswerFeedbackView. No lesson-view line-number churn.

## Test discipline

Constitution III — failing tests first per layer:

| Layer | Test |
|-------|------|
| Backend (Item 3) | `tests/unit/store/falseFriend.test.ts`, `tests/contract/lessons.falseFriend.test.ts` |
| Backend (feedbackHint copy) | extended assertion in `tests/unit/lessons/lessonService.feedbackHint.test.ts` |
| LessonKit (Item 3) | exercised via Swift app tests |
| Swift app (Item 1) | `Tests/Unit/MuteToggleTests.swift` |
| Swift app (Item 2) | extended `DesignTokenContractTests.testNoHardcodedSystemSizeLiteralsInFeatures` |
| Swift app (Item 3) | `Tests/Unit/FalseFriendRenderTests.swift` |
| Swift app (Item 4) | `Tests/Unit/LessonSummaryCallbacksTests.swift` |

## Build pipeline (matches the runbook)

```
cd backend && pnpm install && pnpm run lint:types && pnpm test
cd app/Packages/LessonKit && swift test
cd app/Packages/BackendClient && swift test
cd app/GramartEnglish && swift test
```

All four must pass.

## Swift 5.9 concurrency note

`MuteToggleButton`'s state is `@State Bool`; no captured-`var` test pattern
needed. The `TestFlag` workaround (commits b7d4814 / 0a09215 / 069e3fb on
the v1.8.0 branch) isn't exercised here.
