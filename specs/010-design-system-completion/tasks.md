# F010 — Tasks (v1.11.0)

Dependency-ordered. Each block is a single conventional commit.

## T1 — Item 2 — Corpus + belt test  *(done)*

- [x] T1.1 — Add `record` at A2 with Lucía's locked false-friend copy
      (`data/cefr/a2.json`).
- [x] T1.2 — Refine `embarrassed` copy at A2 + B1 to Lucía's v1.11
      version (`pregnant — el falso amigo más peligroso socialmente`).
- [x] T1.3 — Add `attend` and `discuss` at B1 with locked copy
      (`data/cefr/b1.json`).
- [x] T1.4 — `backend/tests/unit/store/falseFriend.f010.test.ts`:
      4 cases pinning the round-trip (corpusLoader → SQLite →
      `WordRepository.byBase`).
- [x] T1.5 — `pnpm test --filter falseFriend.f010` green (4/4).

## T2 — Item 1 — Token sweep  *(done)*

- [x] T2.1 — Migrate 13 `cornerRadius: N` literals (6 → `Radius.sm`,
      10 → `Radius.md`, 14 → `Radius.md`).
- [x] T2.2 — Migrate 5 `.tint.opacity(0.X)` literals (0.12 / 0.15 →
      `Tint.soft`; 0.18 → `Tint.medium`).
- [x] T2.3 — Migrate 5 raw `.green/.red/.orange` foregrounds to
      `Semantic.{success,error,warning}` (`AnswerFeedbackView`
      badge/border + `FallbackBannerView` icon).
- [x] T2.4 — Extend `DesignTokenContractTests` with a single walker
      that fails on all three literal classes
      (`testNoTokenLiteralsInFeatures`).
- [x] T2.5 — `swift test --filter DesignTokenContractTests` green (7/7).

## T3 — Item 4 — Warm-tune dark palette  *(done)*

- [x] T3.1 — Update `Assets.xcassets/SemanticWarning.colorset` dark
      to `#F5C242`.
- [x] T3.2 — Update `Assets.xcassets/SemanticError.colorset` dark to
      `#EF5B5B`.
- [x] T3.3 — Update `DesignTokens.Semantic.{warning,error}` +
      `…DarkHex` constants + header palette doc.
- [x] T3.4 — Update `SemanticColorsTests` dark-bg pin messages to
      reference the new hexes; verify ≥ 4.5:1 still holds
      (warning ≈ 10.2:1, error ≈ 5.1:1).
- [x] T3.5 — `swift test --filter SemanticColorsTests` green (10/10).

## T4 — Item 3 — Resume CTA  *(done)*

- [x] T4.1 — `Features/Lesson/ResumeLessonCard.swift` (token-clean
      card with `onResume` callback).
- [x] T4.2 — Extend `LessonSummaryView` with `resumableSnapshot:` +
      `onResumeLesson:` params and a public `shouldShowResumeCard`
      predicate.
- [x] T4.3 — Wire `LessonFlowView`: probe `LessonStateStore.shared.load()`
      in the summary `.task`; forward to RootFlowView via
      `onResumeLeftover:`; phase-hop to `.lesson(snap.level, snap.mode,
      resumeId: snap.lessonId)`.
- [x] T4.4 — `LessonSummaryResumeCardTests` — 4 cases on visibility
      predicate + callback independence.
- [x] T4.5 — `swift test --filter LessonSummary` green (5/5 across
      the three summary test files).

## T5 — Docs + release

- [x] T5.1 — Spec-kit under `specs/010-design-system-completion/`
      (spec, plan, research, data-model, contracts, tasks).
- [ ] T5.2 — `version.json` 1.10.0 → 1.11.0.
- [ ] T5.3 — `openapi.yaml` `info.version` 1.10.0 → 1.11.0.
- [ ] T5.4 — `README.md` Latest release + What's new.
- [ ] T5.5 — `CLAUDE.md` Active feature → 010.
- [ ] T5.6 — Final release commit + push branch.
