# Feature Specification: Verb Conjugation

**Feature Branch**: `004-verb-conjugation`
**Created**: 2026-05-14
**Status**: Draft
**Depends on**: 001 + 002 + 003 (uses corpus, LessonMode, mastery, text input)

## Why this feature

Up to Feature 003 the app trains **vocabulary**. Conjugation is the next gap: knowing "run" ≠ knowing "ran / running / runs / has run". For Spanish speakers learning English, irregular past tenses (`go → went`, `bring → brought`) are a recurring stumbling block.

## User Scenarios *(mandatory)*

### US1 — See verb base + tense, pick the right form (Priority: P1)

Student picks "Modo: Conjugación → Reconocer". Each question shows an English verb base + a tense indicator (e.g., **eat** · *past simple*) and 4 form options (`eaten / ate / eating / eats`). Pick the correct one.

**Acceptance**:
1. **Given** a conjugation lesson started, **When** the question appears, **Then** prompts shows verb base + a clear tense badge + 4 form options.
2. **Given** the student picks an option, **When** correct, **Then** reveals the correct form + an example sentence using it (from the verb's `forms.examples`).
3. **Given** wrong, **Then** highlights the correct form + plays audio of the form.

### US2 — See verb base + tense, type the form (Priority: P2)

Same as US1 but text input instead of options. Levenshtein 1 tolerance from Feature 003.

**Acceptance**:
1. Prompt: verb base + tense badge + monospaced text field.
2. Submit on `↩`. Hint reveals first letter.
3. On reveal: correct form, an example sentence, and audio.

### US3 — Listening: hear the conjugated form, pick the verb base (Priority: P3)

Audio plays a conjugated form ("went"). Student picks the base ("go") from 4 options. Tests reverse-recognition of irregular forms.

**Acceptance**:
1. 🔊 plays automatically; no written prompt.
2. 4 base-form options shown.
3. Reveal explains the relationship: "Oíste **went**, que es el pasado simple de **go**."

### Edge Cases

- Verb with multiple valid past forms (`learn → learned / learnt`). System accepts either.
- Spelling variants (`travel → traveled` US / `travelled` UK). System accepts both.
- Regular verbs are NOT in the curated bank if they only follow the +ed/+ing rules; rule-based engine generates them.

## Functional Requirements *(mandatory)*

- **FR-001**: System MUST support a `Verb` entity with fields: `base`, `pastSimple`, `pastParticiple`, `gerund`, `thirdPersonSingular`, `examples: { tense: string, sentence: string }[]`, `irregular: boolean`, `level: CefrLevel`, `alternates: string[]` (for accepted variants).
- **FR-002**: The MVP for this feature MUST ship ≥ 80 curated irregular verbs across CEFR levels (per-level minimum: A1=20, A2=15, B1=15, B2=10, C1=10, C2=10).
- **FR-003**: For regular verbs not in the curated bank, the system MUST generate forms via rules (`-ed`, `-ing`, doubling rules, `-y → -ies`, etc.).
- **FR-004**: `LessonMode` enum MUST gain values: `conjugate_pick_form`, `conjugate_type_form`, `conjugate_listen_pick_base`.
- **FR-005**: Mastery tracks `(userId, verbId, tense, mode)` — a user might know `eat → eating` (gerund) but not `eat → ate` (past simple).
- **FR-006**: A "tense" axis is added to the mode: each question targets one tense from `{past_simple, past_participle, gerund, third_person}` for MVP.
- **FR-007**: Reveal screen MUST show the canonical form + an example sentence using that exact form + audio.
- **FR-008**: Distractor forms MUST be plausible: other tense forms of the SAME verb (`eat → eating / eats / ate / eaten`) so the user actually has to identify the right tense, not just any English word.
- **FR-009**: The selector picks verbs at the user's current CEFR level by default; settings allow narrowing to a specific tense ("solo past simple") for focused practice.

## Success Criteria

- **SC-001**: A student can complete a 10-question conjugation lesson in ≤ 5 minutes.
- **SC-002**: After 5 lessons targeting "past simple of irregular verbs", per-verb-mastery on the past-simple tense improves measurably (≥ 60% of attempted verbs mastered).
- **SC-003**: The rules engine generates regular-verb forms correctly for ≥ 95% of a curated 50-regular-verb test set.
- **SC-004**: All 80 curated irregular verbs have author-reviewed example sentences for all 4 tenses (320 sentence-form pairs).

## Assumptions

- "Tense" in this feature means the four MVP tenses: past simple, past participle, gerund (-ing), third person singular (-s/-es). Future, conditional, perfect-progressive are deferred.
- Tense selection is shown to the student in Spanish ("pasado simple", "gerundio", "tercera persona") for clarity at low levels.
- The curated irregular-verb list aligns with widely-taught lists (e.g., the ~100 most common English irregular verbs).

## Out of scope

- Modal verbs (`should`, `would`, `must` …)
- Phrasal verbs (`get up`, `look after`) — possible Feature 005
- Subject-verb agreement beyond third-person-singular `-s` (full agreement = much bigger)
- Auxiliary verb forms (`have been`, `had been`, etc.) — too complex for this MVP
- Pronunciation tests for forms

## New entities

- `Verb` table (separate from `vocabulary_words` because verbs need richer forms)
- `verb_mastery` table (similar to `word_mastery` but keyed by tense)
- `verb_forms_rules.ts` for regular-verb generation

## Migration plan

`0004_verbs.sql`:
- `CREATE TABLE verbs (id, base, pastSimple, pastParticiple, gerund, thirdPersonSingular, examples, irregular, level, alternates)`
- `CREATE TABLE verb_mastery (userId, verbId, tense, mode, consecutiveCorrect, …)`

## Reuses from Features 002–003

- `LessonMode` enum (extend with conjugation modes)
- Mode selector on Home
- Per-mode mastery infrastructure
- Text-input UI for `conjugate_type_form`
- TTS for audio reveal
- Levenshtein distance for typo tolerance

## Effort estimate

- ~3 days work + significant content curation (80 verbs × 4 tenses × 1+ example sentences = 320+ curated entries)
- The rules engine for regular verbs is ~2 hours; the bulk is data + UI
