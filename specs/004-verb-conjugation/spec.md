# Feature Specification: Verb Conjugation (v1.6.0 scope)

**Feature Branch**: `004-verb-conjugation`
**Created**: 2026-05-14
**Last updated**: 2026-06-05 (PO+TL scope lock for v1.6.0)
**Status**: v1.6.0 shipping
**Depends on**: 001 + 002 + 003 + 005 (uses corpus, LessonMode, mastery)

## Why this feature

Vocabulary modes (F001–F003) teach `eat`. They do **not** teach `eat → ate`. For Spanish-speaking learners, irregular past forms are the single most common L2-production error past A2 ("I goed", "she eated"). F004 closes that gap.

## v1.6.0 scope (locked by PO + TL)

The original F004 spec proposed 3 sub-modes × 4 tenses × ≥80 verbs. PO+TL deliberation locked the v1.6.0 release to a **minimum viable conjugation drill** so the change ships in one sprint without blocking later expansions:

| Axis | v1.6.0 | Deferred |
|---|---|---|
| Modes | `conjugate_pick_form` (MCQ) | `conjugate_type_form`, `conjugate_listen_pick_base` |
| Tenses | `simple_past` only | `past_participle`, `gerund`, `third_person` |
| Levels | A2 + B1 | A1, B2, C1, C2 |
| Verbs | 60 hand-curated (≈40 A2 + 20 B1; ~50% irregular) | scale to ≥ 80 at A1+ |
| Distractors | `[over_regularized, base, past_participle, +1 same-level past]` minus collisions | rules-engine generation for regulars |
| Storage | side-channel `data/cefr/verbs.json` overlaying existing `vocabulary_words` rows; **no new SQL table** | promote to `verbs` table in F004 US2 if needed |
| `schemaVersion` | stays at **3** (additive only — no migration) | n/a |

The full F004 vision in the original draft below remains the long-term target.

## User Scenarios *(mandatory)*

### US1 — See verb base + tense, pick the right form (Priority: P1, **v1.6.0**)

Student picks "Modo: Conjugar". Each question shows **"Pasado simple de _ir_"** and 4 English-form options (`went / goed / go / gone`). Pick the correct one.

**Acceptance**:
1. **Given** a conjugation lesson started, **When** the question appears, **Then** the prompt shows `Pasado simple de **<spanish_infinitive>**` and 4 English options.
2. **Given** the student picks an option, **When** correct, **Then** the AnswerFeedbackView reveals correctness (reused from F001).
3. **Given** wrong, **Then** highlights the correct form (same reuse path).
4. **Given** the verb is regular and all canonical distractor slots collide with the answer (e.g. `travel` → `traveled / traveled / traveled`), **When** the question is built, **Then** the recipe degrades to ≤ 1 collision + 2 random same-level past forms.

### US2 — Type the form (Priority: P2, **deferred past v1.6.0**)

Reserved for F004 US2. Same prompt, text input instead of options. Will reuse `TypedAnswerInputView` and the Levenshtein-1 tolerance from F002/F003.

### US3 — Listening: hear → pick base (Priority: P3, **deferred past v1.6.0**)

Reserved for F004 US3.

### Edge Cases (in v1.6.0 scope)

- **Verb with the same past_participle as simple_past** (e.g. `meet → met → met`): the past_participle distractor slot collides with the answer; recipe falls back to 1 other-verb past form.
- **Regular verb where over_regularized = simple_past = past_participle** (e.g. `travel → traveled`): 2 of 3 desired distractors collide; recipe tops up with 2 other-verb past forms.
- **Multiple valid past spellings** (e.g. `learn → learned / learnt`): v1.6.0 ships ONE canonical form per verb (`learned`). v1.6.x can add an `alternates` field once F004 US2 ships.

## Functional Requirements (v1.6.0)

- **FR-001 (v1.6.0)**: System MUST load a curated `verbs.json` corpus with 60 verbs at A2+B1, ≥ 50% irregular.
- **FR-002 (v1.6.0)**: `LessonMode` enum MUST include `conjugate_pick_form`. SHIPPED_MODES count goes 7 → 8.
- **FR-003 (v1.6.0)**: Each verb MUST have an English `base`, Spanish infinitive (`es`), `simple_past`, `past_participle`, `level`, and `irregular: boolean`.
- **FR-004 (v1.6.0)**: Distractor recipe MUST be `[over_regularized, base_form, past_participle, +1 random_same_level_past]`, minus collisions with the answer.
- **FR-005 (v1.6.0)**: Mastery axis MUST reuse the existing `(userId, wordId, mode)` PK. Each verb's `base` MUST resolve to an existing `vocabulary_words.id` so the FK holds without a new table.
- **FR-006 (v1.6.0)**: The `LessonQuestion` DTO gains 2 optional fields: `verbBase: string?` and `targetTense: "simple_past"?`. Other modes leave them `nil`.
- **FR-007 (v1.6.0)**: Spanish prompt copy is locked to `"Pasado simple de **<es>**"` (markdown emphasis on the Spanish infinitive).
- **FR-008 (v1.6.0, deferred from original FR-009)**: User-facing tense-filter setting is **not** in v1.6.0 — only `simple_past` ships, so there is nothing to filter.

## Success Criteria (v1.6.0)

- **SC-001**: A student completes a 10-question `conjugate_pick_form` A2 lesson in ≤ 5 minutes.
- **SC-002**: The 60-verb corpus produces a valid 4-option question for every verb at its level (no `lesson_unavailable` errors at A2 or B1).
- **SC-003**: Backend unit tests cover the over-regularization rule and the collision-fallback path with deterministic seeds.

## Out of scope (v1.6.0 only — full F004 remains the long-term target)

- The other 2 sub-modes (`conjugate_type_form`, `conjugate_listen_pick_base`).
- Tenses other than `simple_past`.
- Rules engine for unseen regular verbs (60-verb hand-curation is sufficient at v1.6.0 scale).
- Modal/phrasal verbs.
- Pronunciation tests for forms.
- Multi-valid spellings (`learned / learnt`).

## Reuses from F001–F003

- `LessonMode` enum (one new case).
- Per-mode mastery infrastructure unchanged.
- `OptionCard` from `PlacementQuestionView` (4-card option layout).
- `AnswerFeedbackView`, `LessonSummaryView`, `ProgressHeader`.
- `ModeCard` (the existing `comingSoon: .conjugatePickForm` slot is promoted to a shipped LessonMode card).

## Effort estimate

- v1.6.0 delta: ~1 day (60-verb curation + 1 view + the builder + tests). The bulk of the work was in the original F004 draft's vision; the scope-locked v1.6.0 slice is intentionally small.
