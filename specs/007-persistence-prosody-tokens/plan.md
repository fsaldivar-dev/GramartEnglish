# F007 Plan (v1.8.0)

## Constitution Check

| Principle | Status | Note |
|---|---|---|
| I. Local-first | ✅ | `LessonStateStore` writes to Application Support; no network. |
| II. Simplicity | ✅ | 4 items, ~600 LOC net additions. Token API established without forcing site-wide propagation. |
| III. Privacy | ✅ | Snapshot file holds lessonId+mode+level+indices — no user input echo. |
| IV. Determinism (corpus) | ✅ | Distractor recipe seeded as before. |
| V. Backwards-compat | ✅ | `feedbackHint` is optional on the answer response. `AnswerOutcome` initializer keeps the new param defaulted. |
| VI. Performance | ✅ | Debounced disk writes (≤2/sec). Symbol swap in summary view drops two emoji-glyph layout passes. |
| VII. Accessibility | ✅ | Dynamic Type fixes are FR-010/011. SF Symbols inherit `.symbolRenderingMode(.hierarchical)` and a11y labels. |

## Phases

1. **Persistence** (Priya) — `LessonStateStore`, `LessonStateSnapshot`, VM wiring, RootView resume integration, tests.
2. **Prosody** (Lucía) — `SpeechRate` enum + named-rate overload, dual-button pattern in three views, audit-test update, `SpeechRateTests`.
3. **Design tokens** (Mariana) — `DesignTokens.swift`, summary + writing-lesson surgical fixes, contract tests.
4. **Distractor fix** (Lucía) — builder recipe change, `feedbackHint` plumbed through service + Swift client + outcome model + feedback view, tests on both sides.
5. **Docs + release** — spec-kit artifacts, version bump, README, CLAUDE.md, OpenAPI.

## Risks

- **Risk**: Snapshot resume could surface a server-side already-completed lesson. **Mitigation**: load() is gated on `progress.resumable.lessonId == snapshot.lessonId`; stale snapshots are deleted on launch.
- **Risk**: `feedbackHint` localisation drift. **Mitigation**: Spanish copy is hardcoded for v1.8 (single locale); v1.9 will route through string catalog.
- **Risk**: `SpeechRate` enum value bikeshedding. **Mitigation**: pinned by tests + comment ties the value to the underlying `AVSpeechUtterance` constants.
