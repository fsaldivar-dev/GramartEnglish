# F003 v1.5.0 Delta — `write_fill_gaps`

**Status**: Implemented on branch `007-write-fill-gaps`.
**Scope**: Ship US3 of F003 with the locked masking algorithm and the
PO+TL-locked a11y bar. No schema migration, no new dependencies.

## Pointers

- US3 acceptance criteria: [`../spec.md`](../spec.md) (US3 — Autocomplete the
  missing letters; FR-001, FR-006, FR-007, FR-008).
- Locked masking algorithm: [`../research.md`](../research.md) §1
  (`write_fill_gaps` gap pattern).
- Implementation: `backend/src/lessons/gapMasker.ts`,
  `backend/src/lessons/lessonService.ts`,
  `app/GramartEnglish/Sources/Features/Lesson/WritingLessonView.swift`.

## Hint button is OUT of scope

The masking IS the scaffold for US3. No hint reveal button is added in this
delta — the `hintUsed` plumbing inherited from US2 (`write_type_word`)
remains untouched. The view does not surface a hint affordance for
`write_fill_gaps`.

## A11y items locked by PO+TL (pre-required, all 7 in)

1. Masked scaffold uses `.font(.system(.title2, design: .monospaced))` so
   gaps and letters align visually.
2. `.minimumScaleFactor(0.7)` so long words still fit on narrow trait
   collections without truncation.
3. VoiceOver label replaces every `_` with `" espacio "` (e.g.
   `w__th_r` → `"Completa la palabra: w espacio espacio th espacio r"`).
   The Spanish word is intentional: the label prefix is Spanish, so the
   Spanish-locale VoiceOver synthesizer (es-MX) would otherwise pronounce
   the English token `"blank"` awkwardly for hispanohablantes. PO+TL
   originally locked `"blank"`; Marisol's review on PR #7 caught the
   regression and we re-locked to `"espacio"` (Principle VII).
4. VoiceOver hint: `"Escribe la palabra completa en inglés"`.
5. `.accessibilityElement(children: .combine)` on the scaffold container so
   VoiceOver doesn't fragment the prompt + mask into multiple stops.
6. Scaffold renders ABOVE the existing `TypedAnswerInputView` — preserves
   the focus flow established in v1.3 for `write_type_word`.
7. Dynamic Type respected via the system text style; no fixed-point sizes
   on the scaffold (the `44pt` Spanish prompt above it is unchanged).

## Out of scope (explicitly named)

- Hint reveal button.
- Mastery tuning (FR-007 semantics unchanged from v1.3).
- Distractor work (write_fill_gaps doesn't show options).
- Locale rules beyond English (y-as-vowel-word-final is the only locale
  carve-out).
- Schema migration (`schemaVersion` stays at 3).
- Telemetry events.
- Home card reordering (the existing `SHIPPED_MODES` order is preserved —
  `write_fill_gaps` is appended at the end of the array).

## Auto-promotion decision (server-side, opaque to client)

For words with length ≤ 3, the masker returns `autoPromoted: true` and
`lessonService` OMITS `maskedWord` from the response. The lesson row
**stays at `mode = write_fill_gaps`** so mastery accumulates on the
write_fill_gaps axis — this preserves FR-007's per-mode mastery promise.
The client, seeing `maskedWord == nil` for a `write_fill_gaps` question,
falls back to the same rendering it uses for `write_type_word`: Spanish
prompt + typed input, no scaffold.

## Tasks for this delta (mirrors locked scope)

- [x] `backend/src/lessons/gapMasker.ts` — pure function implementing the
  research §1 algorithm.
- [x] `backend/src/lessons/lessonService.ts` — populate `maskedWord` on
  write_fill_gaps responses; honor auto-promotion via field omission.
- [x] `backend/src/domain/schemas.ts` + `backend/src/routes/progress.ts` —
  add `write_fill_gaps` to `SHIPPED_MODES` and the `perModeMastered` map.
- [x] `specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml` — document
  the optional `maskedWord` field on `LessonQuestion`.
- [x] `app/Packages/LessonKit/Sources/LessonKit/LessonMode.swift` — move
  `.writeFillGaps` out of `ComingSoonMode` and into `SHIPPED_MODES`.
- [x] `app/Packages/LessonKit/Sources/LessonKit/LessonKit.swift` +
  `app/Packages/BackendClient/Sources/BackendClient/BackendClient.swift` —
  add `maskedWord: String?` to `LessonQuestion` and `LessonQuestionDTO`;
  bump `clientVersion` to `"1.5.0"`.
- [x] `app/GramartEnglish/Sources/Features/Lesson/LessonViewModel.swift` —
  forward `maskedWord` from DTO to `LessonQuestion`.
- [x] `app/GramartEnglish/Sources/Features/Lesson/WritingLessonView.swift`
  — render the scaffold above the typed input with the locked a11y items.
- [x] `version.json` → `1.5.0`.
