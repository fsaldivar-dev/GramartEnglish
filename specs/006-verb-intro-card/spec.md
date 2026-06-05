# F006 — "Conoce el verbo" pre-conjugation micro-card (v1.7.0)

## Problem

`conjugate_pick_form` (F004, v1.6.0) immediately asks the learner to pick the
past-simple of a verb whose Spanish meaning + English base they may have never
seen. Cold-start mistakes feel like a test, not a lesson. We need a micro-pause
that grounds the verb in form-meaning before the first question.

## Locked scope (v1.7.0)

- ONE pre-question micro-card before the FIRST `conjugate_pick_form` question
  of each verb the user has not seen on this Mac.
- Card content (locked):
  - Spanish infinitive (es), large
  - English base, medium
  - Audio button → `SpeechService.shared.speakEnglish(base, isUserInitiated: true)`
  - ONE bilingual example: `exampleEs` (Spanish, slot already filled) +
    `exampleEn` (English with verb in base form)
  - Primary CTA "Listo, vamos" — dismisses + advances to the question.
- Dismissal paths (all mark the verb as seen):
  - "Listo, vamos" tap
  - Esc key
  - Click outside the card area
- Persistence: per-Mac via `UserDefaults` under
  `gramart.verbIntro.seen` storing a `Set<String>` of verb `base` forms.
  Survives app restart; cleared by reset-me.
- After first dismissal, the card never auto-shows again for that verb.

## Deferred (NOT in v1.7.0)

- Gramática sidebar tab — F007.
- Paradigm-internal distractors — F008.
- Smart-tip-on-mistake — F009.

## User Stories

### US1 — First encounter with a new verb (P0)

**As** a learner running a `conjugate_pick_form` lesson,
**when** the next question targets a verb whose base I have never seen on this
Mac,
**I see** the "Conoce el verbo" card with the Spanish infinitive, English base,
audio button, and ONE bilingual example,
**so that** I can ground form-meaning before I'm asked to pick the past form.

Acceptance:
1. The card appears EXACTLY ONCE per `(macInstall, verbBase)` pair.
2. The card never appears for non-`conjugate_pick_form` modes.
3. Dismissal via any of {CTA, Esc, click-outside} marks the verb seen and
   advances to the question.
4. Re-running a lesson with the same verb goes straight to the question.

### US2 — Three new verbs in one session (P0)

**Given** a session with three previously-unseen verbs,
**when** I play all three through `conjugate_pick_form`,
**I see** the intro card three times — once per verb — and never twice for the
same verb.

## Functional Requirements

- **FR-001 Gating predicate** — Before transitioning to `.answering` for a
  `conjugate_pick_form` question, the coordinator MUST check
  `VerbIntroSeenStore.hasSeen(question.verbBase)`. If false, fetch the intro
  payload and present `VerbIntroCard`; if true, present the question directly.
- **FR-002 Endpoint** — `GET /v1/verbs/{base}/intro` returns
  `{ base, es, exampleEs, exampleEn, audioBase }`. 404 if base not in the
  corpus.
- **FR-003 Persistence** — On dismissal, the verb base is added to
  `gramart.verbIntro.seen` (UserDefaults) BEFORE the next question is shown.
- **FR-004 Dismissal parity** — CTA, Esc, and click-outside all invoke the
  same dismiss callback. No code path advances to the question without marking
  seen.
- **FR-005 Mode scope** — Other modes (read, listen, write) MUST never trigger
  the intro card, even when their question is built around a verb.
- **FR-006 Audio** — The speaker button taps `speakEnglish(base, isUserInitiated: true)` (mute-bypass per F2 policy).
- **FR-007 Accessibility (Principle VII)** —
  - Spanish text carries `.accessibilityLanguage("es-MX")`.
  - English base + audio button default to system English.
  - The card is a single focusable group with combined a11y children where
    grouping aids comprehension.
  - Dynamic Type respected (no hardcoded point sizes).

## Success Criteria

- **SC-001** ≥3 distinct verbs introduced per session for a fresh install.
- **SC-002** No user sees the intro for the same verb twice (asserted by
  `VerbIntroSeenStore` round-trip test).
- **SC-003** Card render ≤150ms p95 from gate-check to first paint.
- **SC-004** All conjugation tests still pass; gating is invisible when the
  verb has been seen.

## Out of scope

- Any conjugation paradigm display beyond the single bilingual example.
- Server-side persistence of `seen` state (local-only by design).
- Resetting the seen set from in-app UI (only via reset-me).
