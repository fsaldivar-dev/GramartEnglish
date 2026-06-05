# F011 — Tasks (v1.12.0)

Dependency-ordered, one commit per item.

## T001 — Item 1: Lucía's false-friend trio refinement (S) ✅

- [x] `data/cefr/a1.json`: `large` — apply v1.10-style "que en inglés es long".
- [x] `data/cefr/b1.json`: `assist` — apply v1.10-style "que es to attend an event".
- [x] `data/cefr/a2.json`: `success` — verify already v1.10-style (no change).
- [x] Commit: `chore(F011 item 1): refine large/assist false-friend copy (Lucía)`.

## T002 — Item 2: Mariana's `.padding(N)` literal sweep (S) ✅

- [x] Grep `.padding(\s*[0-9]` under `Sources/Features/` → 9 sites.
- [x] Migrate per rounding rubric (16→md, 20→lg↑, 24→lg, 28→xl↑, 32→xl).
- [x] Document the two round-ups (20→24, 28→32) inline.
- [x] Extend `DesignTokenContractTests.testNoTokenLiteralsInFeatures`
      with a `.padding(N)` regex.
- [x] Plant a `.padding(20)` regression → confirm lint fires → restore.
- [x] Commit: `feat(F011 item 2): padding-literal sweep + lint (Mariana)`.

## T003 — Item 3: Priya's shortcuts cheatsheet ⌘`/` (S/M) ✅

- [x] New `Sources/Features/Help/ShortcutsCheatsheetView.swift` with
      three sections totalling 9 entries.
- [x] VoiceOver: `accessibilityElement(children: .combine)` + an
      explicit `"<key>, <action>"` label per row.
- [x] Wire ⌘`/` trigger in `ReadyFlowView` via zero-size,
      `accessibilityHidden(true)` button + sheet.
- [x] New `Tests/Unit/ShortcutsCheatsheetTests.swift` (7 cases) pinning
      content + a11y + Dynamic Type smoke at `.accessibility3`.
- [x] Commit: `feat(F011 item 3): shortcuts cheatsheet (⌘/) (Priya)`.

## T004 — Item 4: Snapshot `totalCount` regression net (S) ✅

- [x] Audit `LessonViewModel.swift`: every persistence call routes
      through `persistSnapshot()` → `snapshot(for:)`. Builder always
      sets `totalCount: state.questions.count`. No bypass.
- [x] New `Tests/Unit/SnapshotTotalCountTests.swift` (5 cases):
      after start, after answer, after dismissVerbIntro, after skip,
      after abandon mid-lesson.
- [x] Commit: `test(F011 item 4): pin snapshot totalCount across
      persistence paths (QA)`.

## T005 — Release plumbing ⏳

- [ ] `version.json` → 1.12.0 (schemaVersion stays 3).
- [ ] `backend/openapi.yaml` `info.version` → 1.12.0.
- [ ] `README.md` — Latest release + "What's new in v1.12.0" section.
- [ ] `CLAUDE.md` — Active feature pointer → 011.
- [ ] Verify gates (backend pnpm test + 3 swift test runs).
- [ ] Commit: `chore(release): v1.12.0 — F011 (polish + pedagogy round)`.
- [ ] Push branch (no PR yet).
