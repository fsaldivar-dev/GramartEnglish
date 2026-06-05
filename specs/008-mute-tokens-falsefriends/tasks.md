# F008 — Tasks

Ordered for minimum line-number churn. Each block is a separate commit.

## Item 4 — Differentiate summary buttons
- [x] T4.1 RootView: wire `onStartAnother` to `vm.start(resumeId: nil)`, keep `onBackHome → onExit`.
- [x] T4.2 Add `LessonSummaryCallbacksTests.swift` pinning the API shape + non-collapse contract.

## Item 1 — Mute toggle in lesson chrome
- [x] T1.1 New `Sources/Shared/Speech/MuteToggleButton.swift`.
- [x] T1.2 Insert button left of X in LessonQuestionView, ListeningLessonView, WritingLessonView, ConjugationLessonView with `Spacing.sm`.
- [x] T1.3 Add `MuteToggleTests.swift`.
- [x] T1.4 Update `SpeechCallSiteAuditTests` line-number manifest (no new call-site classification needed — toggle doesn't call `speakEnglish`).

## Item 2 — Token sweep
- [x] T2.1 Migrate every `.system(size:)` in `Sources/Features/` to `.font(.system(.TextStyle, design:...))` + `minimumScaleFactor`.
- [x] T2.2 Migrate cornerRadius literals (8/12/16 → `Radius.sm/.md/.lg`) where they appear.
- [x] T2.3 Extend `DesignTokenContractTests` with the grep-based `.system(size:)` lint.

## Item 3 — False-friend belt + L1 transfer copy
- [x] T3.1 Backend migration `0004_false_friend.sql`.
- [x] T3.2 `WordRepository` + `corpusLoader` + `LessonService` plumbing.
- [x] T3.3 Curate ~10 belt entries in `data/cefr/a2.json` + `b1.json`.
- [x] T3.4 Backend tests: `tests/unit/store/falseFriend.test.ts`, `tests/contract/lessons.falseFriend.test.ts`.
- [x] T3.5 BackendClient DTO + LessonKit struct add `falseFriendEs?: String`.
- [x] T3.6 LessonViewModel mapping forwards the field.
- [x] T3.7 AnswerFeedbackView renders the chip when present.
- [x] T3.8 Swift test: `FalseFriendRenderTests.swift`.
- [x] T3.9 Update `feedbackHint` template + extend Swift `AnswerFeedbackHintTests` and backend `lessonService.feedbackHint.test.ts` to assert "hispanohablantes".

## Docs
- [x] D1 openapi.yaml: info.version 1.9.0, falseFriendEs added.
- [x] D2 README updated.
- [x] D3 version.json bumped to 1.9.0 (schemaVersion stays 3).
- [x] D4 CLAUDE.md Active feature → 008.
