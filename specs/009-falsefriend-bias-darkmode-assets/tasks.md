# F009 — tasks (TDD order)

## Phase 1 — write tests first (red)

- [ ] T1a · `backend/tests/unit/store/falseFriend.f009.test.ts` — assert
      the 6 new corpus entries load and that `success` carries the
      Lucía-approved copy `(un evento o noticia)`.
- [ ] T1b · `backend/tests/unit/lessons/falseFriendBias.test.ts` — 50-run
      seeded bias test. Pool of 40 words, 4 false-friends, ≥ 80 % of runs
      see ≥ 1 false-friend in the chosen 10. Edge: when all false-friends
      are already mastered in mode, no bias is applied (count distribution
      matches baseline).
- [ ] T1c · `app/GramartEnglish/Tests/Unit/SemanticColorsTests.swift` —
      assert all three named colors resolve from the bundle, and that
      the relative-luminance contrast against the window background
      is ≥ 4.5 in both light and dark.
- [ ] T1d · `app/GramartEnglish/Tests/Unit/SpeakButtonMutedStateTests.swift`
      — icon name flips with `isMuted`; accessibility label appends
      "(audio silenciado)" when muted.

## Phase 2 — make them green

- [ ] T2a · Add 6 corpus entries (A1 ×4, B1 ×2) and the A2 `success`
      copy fix.
- [ ] T2b · `wordSelector.ts`: introduce `FALSE_FRIEND_BIAS_FACTOR =
      1.15`, apply per-candidate weight, document pedagogical rationale.
- [ ] T2c · Create `Sources/Resources/Assets.xcassets/` with three
      `.colorset` directories, update `Package.swift` to process
      resources, rewrite `DesignTokens.Semantic` to read from the bundle.
- [ ] T2d · `SpeakButton.swift`: swap glyph to `speaker.slash.fill`
      when `isMuted`, append "(audio silenciado)" to a11y label.

## Phase 3 — docs + version

- [ ] T3a · `version.json` → 1.10.0
- [ ] T3b · `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml`
      `info.version` → 1.10.0
- [ ] T3c · README "What's new" stanza for v1.10.0
- [ ] T3d · CLAUDE.md active feature → 009

## Phase 4 — build + verify

- [ ] T4a · `pnpm run lint:types && pnpm test` (backend)
- [ ] T4b · `swift test` for each of LessonKit, BackendClient, GramartEnglish
- [ ] T4c · Conventional commits per item, final `chore(release): v1.10.0`
