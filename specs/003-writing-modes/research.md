# Phase 0 Research: Writing Modes

**Date**: 2026-05-19
**Branch**: `003-writing-modes`

Decisions specific to F003. F001/F002 decisions are inherited unchanged.

---

## 1. `write_fill_gaps` gap pattern (US3, P3)

**Decision**: For a word of length N, produce a masked version that:

1. Always keeps the **first letter** visible (anchors the user; FR-006 explicit requirement).
2. Removes **vowels first** (`a`, `e`, `i`, `o`, `u`), counting `y` as a vowel only when it's the last character.
3. If the resulting gap ratio is < 40 %, additionally remove **weak consonants** (`h`, `w`, `y`) until ≥ 40 %.
4. Gap ratio caps at **50 %** — never remove more than half the letters of a word.
5. For words ≤ 3 letters: keep all letters; this mode auto-promotes to plain `write_type_word` (gaps would leave one letter visible, defeats the point).

**Rationale**:
- Vowels-first matches how Spanish speakers struggle with English vowel sounds — that's the pedagogical sweet spot.
- Keeping the first letter eliminates the "what word is this" ambiguity and turns the exercise into pure spelling recall.
- 40-50 % range is the literature-supported "productive scaffolding" window; below 30 % is too easy, above 60 % feels like blind production (use `write_type_word` for that).
- Auto-promoting short words avoids a degenerate UX (`c_t` showing only `c` for "cat" is the same as typing "cat" from scratch).

**Alternatives considered**:
- **Random-position gaps** (40 % uniformly chosen): rejected. Some words become unsolvable (`_e_t_e_` for "weather" has 3 valid letters and asks the user to guess too much).
- **Keep last letter too**: rejected. The last letter is rarely the hard part; vowels in the middle are.
- **Adaptive gaps based on past mistakes**: out of scope. Defer to F005 (mistake-driven SRS).

**Example masking output** (for documentation; actual implementation is in `backend/src/lessons/gapMasker.ts`):

| Word | Masked | Gap ratio |
|---|---|---|
| weather | `w__th_r` | 3/7 = 43 % |
| dangerous | `d_ng_r__s` | 4/9 = 44 % |
| language | `l_ng__g_` | 4/8 = 50 % (capped) |
| eat | `eat` | 0 % (auto-promoted to `write_type_word`) |

US3 is **P3 / deferred** in the F003 task list — landing v1.3 with US1+US2 first. The masking logic + spec are captured here so US3 can land in v1.4 without re-research.

**Note on the cap (added v1.5.0 post-PR-#7 review)**: rules 2 and 3
("vowels first, then weak consonants `h w y`") are a removal *menu*, not a
guarantee that 40 % is always reached. If a word has no removable weak
consonants after the vowel pass and the gap ratio is still below 40 %,
the algorithm stops there — the 50 % cap (rule 4) and the "preserve
non-weak consonants" implicit invariant win. Example: `opportunity`
masks to `opp_rt_n_t_` (4/11 ≈ 36 %), below the 40 % target but stable
because removing `p`, `r`, or `t` would push past the cap on the next
pass. This is documentation completeness, not a defect — the algorithm
is unchanged.

---

## 2. Hint button mastery accounting (FR-009)

**Decision**: When the user clicks "Pista" in `write_type_word`:

1. The view reveals one letter at a time (incremental — same as F002's listen_type behavior).
2. Submitting an answer after **any** hint usage sends `{ typedAnswer, hintUsed: true }` to the backend.
3. Backend, on `hintUsed: true`:
   - Marks the answer `correct` if the typed text matches (Levenshtein ≤ 1 still applies).
   - Sets `consecutiveCorrect = 0` on the mastery row (resets the streak).
   - Records a synthetic `hintUsed` field on the question row for analytics.
   - Does NOT mark the word `mastered`, even if it was on its way (2 consecutive corrects).
4. Mastery semantics: a word can be mastered ONLY if the user answers correctly **without using hints** twice in a row.

**Rationale**:
- The user said the spec wants "no mastery credit but still advances" (FR-009). Reset + advance achieves that without inventing a new outcome type.
- Recording `hintUsed` separately lets SC-004 query "hint frequency over 5 lessons" without adding a new event log.
- Keeping the existing `correct/incorrect/skipped` enum unchanged means no client code paths fork. The hint flag is metadata, not a fourth outcome.

**Alternatives considered**:
- **Add a fourth outcome `correct_with_hint`**: rejected. Forks every existing switch on outcome across backend + app. Cost > benefit when a boolean flag suffices.
- **Track hint count per word in a new table**: rejected. The aggregate (question-level) record is sufficient for SC-004; per-word hint history is YAGNI.
- **Treat hint use as `skipped`**: rejected. The user *did* answer; counting as skip both inflates the skip rate and loses the spelling-attempt signal.

---

## 3. `prompt` field on `LessonQuestion` DTO

**Decision**: Extend `LessonQuestion` with an optional `prompt: string`. Backend populates it ONLY for write modes (`write_pick_word`, `write_type_word`, `write_fill_gaps`). Client renders it in place of `word` when present; falls back to current `word`-based rendering when absent.

**Rationale**:
- The semantic mismatch in write mode: `word` is still the canonical English (used for TTS + answer matching), but the UI must DISPLAY the Spanish meaning. Without a separate field, the client would have to look up the Spanish elsewhere (it doesn't have a corpus index) or the backend would have to put Spanish in `word` and break TTS.
- Optional field = backward compatible. v1.2 clients ignore it and keep working for the listening modes. New clients use it for the new modes.

**Wire example**:

```json
{
  "id": "q-uuid",
  "word": "weather",
  "prompt": "clima / tiempo",
  "options": ["weather", "kitchen", "market", "advice"],
  "position": 0
}
```

For `write_type_word`, `options` is empty (or omitted) and `prompt` carries the Spanish; the typed input goes through the same `/v1/lessons/{id}/answers` endpoint as `listen_type`.

**Alternatives considered**:
- **Separate endpoint `/v1/lessons` with a richer DTO shape per mode**: rejected. Duplicates serialization for no real gain.
- **Embed Spanish in `word` for write modes**: rejected. Breaks TTS + answer matching. Hacky.
- **Client fetches Spanish via a second endpoint**: rejected. Extra round-trip per question kills perf budget.

---

## Summary — all NEEDS CLARIFICATION resolved

| Topic | Status |
|-------|--------|
| `write_fill_gaps` gap pattern | ✅ vowels-first, first letter preserved, 40-50 % ratio |
| Hint button mastery accounting | ✅ resets streak, records `hintUsed` flag |
| Spanish prompt on the wire | ✅ optional `prompt: string` on `LessonQuestion` DTO |
