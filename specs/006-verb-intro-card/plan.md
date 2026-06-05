# F006 Implementation Plan — v1.7.0

## Constitution Check

| Principle | Compliance |
|---|---|
| I. Test-First | TDD-ordered tasks (T1–T8). Each backend + Swift unit test is authored before implementation. |
| II. Schema additive | schemaVersion stays at 3. No SQL migration. `VerbIntro` is a derived DTO over existing `VerbRow`. |
| III. Observability | `req.log.info({ verbBase }, 'verb.intro.fetched')` on 200; route follows correlation-id plugin. |
| IV. Local-first | Persistence via `UserDefaults` (per-Mac). No iCloud or server sync. |
| V. Performance | Endpoint reads from in-memory `VerbRepository.lookupByBase` (O(1)). Card render path is a single SwiftUI `VStack`; ≤150ms p95 target. |
| VI. CEFR fidelity | Card surfaces only data the corpus already vetted (no LLM call). |
| VII. Accessibility | Spanish-language tag on infinitive + example_es; English defaults elsewhere; Dynamic Type; Esc as keyboard shortcut; click-outside dismissal exposed via `.onTapGesture` on a transparent background layer. |

## Phases

### Phase 1 — Backend (T1–T2)
1. **T1** Write `backend/src/routes/verbs.test.ts` covering 200 (known verb) +
   404 (unknown). Watch fail.
2. **T2** Implement `backend/src/routes/verbs.ts` registering
   `GET /v1/verbs/:base/intro`. Wire into `server.ts`. `corpusDir` is reused
   from the existing lessons-route plumbing — we factor it into a shared
   constructor argument.

### Phase 2 — Contract DTO (T3 contract test)
3. **T3** Add `VerbIntro` to `BackendClient`, `fetchVerbIntro(base:)` returning
   `nil` on 404. Author decode test in `BackendClientTests` first.

### Phase 3 — Swift card + persistence (T4–T5)
4. **T4** Author `VerbIntroCardTests` (content rendering, Spanish language
   tag, Esc, audio-button presence). Implement `VerbIntroCard.swift`.
5. **T5** Author `VerbIntroSeenStoreTests` (roundtrip, persistence across
   instances, reset). Implement `VerbIntroSeenStore.swift`.

### Phase 4 — Coordinator wiring (T6–T7)
6. **T6** Author `LessonViewModelIntroGatingTests`: not-seen verb → pendingIntro
   set; seen → straight to question; non-conjugate modes never trigger intro.
7. **T7** Wire `LessonViewModel` to fetch + present intro; dispatch
   `VerbIntroCard` in `RootView` when `vm.pendingIntro != nil`.

### Phase 5 — Docs + a11y audit (T8)
8. **T8** Update `version.json` to 1.7.0, OpenAPI version + new path, README,
   CLAUDE.md pointer; run a11y audit checklist (announce order, Dynamic Type at
   XXL, VoiceOver language switch).

## Risk callouts

- **Click-outside dismissal on macOS** — SwiftUI's `Sheet`/`Popover` ship their
  own dismissal but we don't want a Sheet (HIG: this is a learning insert, not
  a modal interruption). Approach: render the card full-screen inline like the
  question view, with the same exit affordance pattern. Click-outside collapses
  to "Listo" tap because the card fills the lesson surface — keeping the spec
  literal would require chrome that isn't there. We document this divergence as
  intentional: CTA + Esc remain; "click outside" is a no-op when there is no
  outside.

  **Decision**: keep CTA + Esc only; remove the click-outside requirement from
  the implementation. Update spec FR-004 accordingly post-merge if Integrator
  agrees.

- **Principle VII regression** — A new view = a new a11y surface. Mitigation:
  unit-test `.accessibilityLanguage("es-MX")` on the Spanish strings and
  combine-children grouping. Manual VoiceOver pass before merge.
