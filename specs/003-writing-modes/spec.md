# Feature Specification: Writing Modes

**Feature Branch**: `003-writing-modes`
**Created**: 2026-05-14
**Status**: Draft
**Depends on**: 001-vocabulary-lesson-mvp + 002-listening-modes (uses `LessonMode` enum, per-mode mastery, mode selector, text-input UI)

## Why this feature

Recognizing the meaning of a word is **passive**. Producing it from your mother tongue is **active recall** — the harder, more durable skill. This feature reverses the lesson: prompt is Spanish, answer must be the English word.

## User Scenarios *(mandatory)*

### US1 — See Spanish, pick English from 4 options (Priority: P1)

Student picks "Modo: Escribir → Reconocer". 10 questions where the prompt is the Spanish meaning (e.g., "clima / tiempo") and 4 options are English words (`weather, kitchen, market, advice`).

**Why P1**: Smallest jump from existing read mode. Reuses the entire option-card UI; only the data direction flips.

**Independent Test**: Pick "Reconocer EN" → 10 Spanish prompts → 4 English options → score at end.

**Acceptance**:
1. **Given** a lesson started in this mode, **When** the question appears, **Then** prompt is the Spanish meaning (big, centered) and options are 4 English words.
2. **Given** the student picks an option, **When** correct, **Then** badge "¡Correcto!" + 🔊 plays the English word audio.
3. **Given** wrong/skipped, **Then** correct English word highlighted + 🔊.

### US2 — See Spanish, type the English word (Priority: P2)

Productive mode: text field, no options. Tolerates Levenshtein 1 typo.

**Acceptance**:
1. Spanish prompt + monospaced text field + 🔊 disabled until reveal.
2. Submit on `↩`. Hint button reveals first letter (counts as half-correct: no mastery credit, but advances).
3. Skip = "No lo sé". On reveal: shows correct spelling + plays audio.

### US3 — Autocomplete the missing letters (Priority: P3)

Hybrid between recognition and production. Shows the English word with ~40% of letters replaced by gaps (`e_phem_r_l`). Student types into the gaps.

**Why P3**: Variant of US2 with scaffolding. Useful for early productive practice but lower priority — US1 and US2 cover the same skill spectrum.

**Acceptance**:
1. Prompt is the Spanish meaning + the scaffolded English word with gaps.
2. Single text field that fills the gaps in order; submit on `↩`.
3. Pattern keeps consonants and removes vowels for words ≤ 6 letters; mixed for longer ones.

### Edge Cases

- User types uppercase: case-insensitive compare.
- User types with leading/trailing whitespace: trimmed.
- User types in Spanish accidentally: rejected as incorrect (same as wrong English).
- Typed answer is empty: counted as Skip, not Wrong.

## Functional Requirements *(mandatory)*

- **FR-001**: System MUST support `LessonMode` values: `write_pick_word`, `write_type_word`, `write_fill_gaps`.
- **FR-002**: `write_pick_word` distractors are 3 same-level English words distinct from the target (`base`).
- **FR-003**: `write_type_word` MUST accept correct spelling AND single-character typos (Levenshtein ≤ 1) as correct; 2+ char distance is incorrect.
- **FR-004**: A typed answer that becomes correct after lowercasing and trimming counts as correct.
- **FR-005**: An empty typed answer or pressing the Skip button MUST be treated as `outcome: skipped`, not `outcome: incorrect`.
- **FR-006**: `write_fill_gaps` MUST keep first letter visible and remove vowels first (a/e/i/o/u), then consonants if needed to reach the gap-ratio target.
- **FR-007**: Mastery counts as in read/listening modes: 2 consecutive correct (no skips, no typos) = mastered for this mode.
- **FR-008**: After answer, the reveal MUST show the canonical English spelling, the Spanish meaning that was the prompt, and play the audio.
- **FR-009**: Hint button reveals the first letter; using a hint disables mastery credit for that question (but still advances).

## Success Criteria

- **SC-001**: A student can complete a 10-question writing lesson (any sub-mode) in ≤ 5 minutes.
- **SC-002**: `write_type_word` accepts ≥ 90% of single-character typos on a 20-word test set without false positives (a wholly different word never accepted).
- **SC-003**: Per-mode mastery shows divergence: at least 30% of words mastered in `read_pick_meaning` are NOT yet mastered in `write_type_word` for the same user (this is the "I recognize but can't produce" gap, validating the feature).
- **SC-004**: Hint usage decreases over 5 lessons for the same word (the user learns the spelling, hint frequency drops).

## Assumptions

- The text input field receives keyboard focus automatically on question appear.
- Levenshtein-1 is permissive enough to handle real typos without becoming too lenient. Validated on a 20-word curated test set.
- Users on macOS have a comfortable English keyboard layout. Localized input methods (e.g. Spanish accents) are not blocking.

## Out of scope

- Verb conjugation forms (past tense, etc.) → Feature 004
- Full-sentence writing (compose a sentence with the word) → potential Feature 007
- Pronunciation grading (record-and-compare) → not on roadmap
- Auto-correct dictionary integration → would change product behavior; explicitly out

## Migration plan

No migration needed beyond Feature 002's `0003_lesson_modes.sql` (the `mode` axis already exists). Only new code, no new schema.

## Reuses from Feature 002

- `LessonMode` enum
- `word_mastery.mode` column
- Mode selector on Home
- Per-mode `wordSelector` logic
- Text-input UI component (built in 002 for `listen_type`, reused here for `write_type_word`)
- Levenshtein distance helper (built in 002, reused here)
