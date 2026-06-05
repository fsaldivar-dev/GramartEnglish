# F006 Tasks — TDD ordered

- **T1 [Backend][test]** `backend/src/routes/verbs.test.ts` — assert
  `GET /v1/verbs/go/intro` returns `{ base, es, exampleEs, exampleEn, audioBase }`,
  and `GET /v1/verbs/zzz/intro` returns 404. Watch fail.
- **T2 [Backend][impl]** `backend/src/routes/verbs.ts` + wire into `server.ts`.
  Reuse the verb-corpus already loaded for the lessons route.
- **T3 [BackendClient][test+impl]** Add `VerbIntro` struct,
  `fetchVerbIntro(base:)`, bump `clientVersion` to `1.7.0`. Decode test in
  `BackendClientTests/VerbIntroTests.swift`.
- **T4 [App][test+impl]** `VerbIntroCardTests.swift` covers content rendering,
  `.accessibilityLanguage("es-MX")` on Spanish strings, Esc shortcut,
  audio-button presence. Implement `VerbIntroCard.swift`.
- **T5 [App][test+impl]** `VerbIntroSeenStoreTests.swift` covers hasSeen/markSeen
  roundtrip, persistence across instances (suite-name UserDefaults),
  `reset()` clears. Implement `VerbIntroSeenStore.swift`.
- **T6 [App][test]** `LessonViewModelIntroGatingTests.swift`: unseen verb →
  `pendingIntro` set; seen → straight to `.answering`; non-conjugate modes
  never call `fetchVerbIntro`.
- **T7 [App][impl]** Wire `LessonViewModel.pendingIntro` + dispatch in
  `RootView` (between `.answering` and the question view).
- **T8 [Docs+a11y]** `version.json` 1.7.0, OpenAPI bump + new path in
  `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml`, README "What's new",
  CLAUDE.md active-feature pointer, manual a11y audit (VoiceOver order, Dynamic
  Type at XXL, Esc dismissal verified by keyboard-only flow).
