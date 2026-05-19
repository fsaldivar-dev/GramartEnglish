# Phase 0 Research: Listening Modes

**Date**: 2026-05-14
**Branch**: `002-listening-modes`

Decisions specific to this feature. All MVP-wide decisions inherit from `specs/001-vocabulary-lesson-mvp/research.md` and are not repeated.

---

## 1. Levenshtein helper implementation

**Decision**: Implement Levenshtein in-repo as a ~20-LOC pure function. One copy in Swift inside `LessonKit/Sources/LessonKit/Levenshtein.swift`, one copy in TypeScript inside `backend/src/lessons/levenshtein.ts`.

**Rationale**:
- For tolerance ≤ 1 we only need a yes/no on "distance ≤ k". Even a naive O(m*n) DP is sub-millisecond for vocabulary words (< 20 chars).
- Adding `js-levenshtein` or `fast-levenshtein` brings a transitive dependency for code we can write in one screen.
- Honors Constitution III (Simplicity) and VI (Supply-chain hygiene).
- Trivially testable: a 10-case unit test covers the boundary perfectly.

**Alternatives considered**:
- `js-levenshtein` npm package — fine but unnecessary.
- Damerau-Levenshtein (handles transpositions like "form" → "from") — rejected for v1; the user's reported typos in vocabulary practice are overwhelmingly single-character substitutions, not transpositions. Revisit if data shows otherwise.

---

## 2. "Recomendado para ti" heuristic

**Decision**: `recommendedMode = argmax over modes of (pendingWordsForMode)` with `least-recently-used` as the tiebreaker.

`pendingWordsForMode` = words at user's current CEFR level that have a `word_mastery` row for this mode with `mastered = false`, plus words at the level with no row for this mode (never seen).

`lastSeen` = `MAX(word_mastery.lastSeenAt) WHERE userId = ? AND mode = ?` — null is treated as "very long ago", so a mode never practiced wins ties.

**Brand-new user (all modes tied)**: When pending counts are identical across all modes AND every `lastSeen` is null, the recommended mode is **`listen_pick_word`**. Rationale: it's the flagship of F002, the most novel skill vs the MVP (the user already used read mode through placement), and has the lowest friction (no typing). Deterministic so the recommendation is reproducible across launches.

**Disabled / coming-soon modes**: Modes whose feature hasn't shipped (`write_*` until F003, `conjugate_*` until F004) MUST be excluded from the argmax candidate set. The UI shows them as "Próximamente" but they cannot win the "Recomendado para ti" tag.

**Rationale**:
- Explainable to the user ("este modo tiene más palabras por dominar").
- Deterministic given current state — no randomness, no SRS curves.
- Reuses data we already have. No new tables.
- Drives the user toward the mode that needs work most, which matches the pedagogical goal.

**Alternatives considered**:
- Pure recency ("hace más tiempo que no haces este modo") — too easy to abuse and doesn't reflect learning need.
- Spaced-repetition forgetting curve — out of scope and explicitly noted as a future feature in 001.
- Round-robin — ignores actual progress; would recommend a mode the user just mastered everything in.

---

## 3. Audio caching strategy for TTS

**Decision**: **No caching.** `AVSpeechSynthesizer` re-synthesizes each utterance on demand.

**Rationale**:
- Empirical: on M1 (the baseline Mac per F001), single-word synthesis is < 50 ms wall-clock. Sentence-level (~10 words) is < 200 ms. Within the SC-003 ≤ 300 ms budget.
- Caching to disk would need invalidation on voice changes, accent changes, and version bumps — complexity for marginal gain.
- The `SpeechService.speakEnglish(_:)` already cancels in-flight playback when re-tapped, so rapid-tap latency is unchanged.

**Alternatives considered**:
- In-memory audio buffer cache — would help marginally on the same lesson but cleared on app restart; not worth the implementation.
- Pre-render the 10 words of a lesson at lesson-start — would shift latency from "per question" to "lesson load", possibly hiding total cost. Rejected: lesson load is already > 200 ms (network round-trip), no perceived improvement.

---

## 4. Mode icons (SF Symbols)

**Decision**: Lock in these SF Symbols:

| Mode | Icon | Reason |
|------|------|--------|
| Read | `book` | Universally read = reading |
| Listen | `ear` | Direct, single-word semantic |
| Write | `pencil` | Production / handwriting metaphor |
| Conjugate | `arrow.triangle.2.circlepath` | Cyclic transformation, fits verb forms |

**Rationale**:
- All are present in SF Symbols 4 (macOS 13+), zero dep risk on macOS 14 baseline.
- Each renders cleanly in tints and Dark Mode.

**Alternatives considered**:
- Emoji 📖 👂 ✏️ 🔁 — Pro: clearly visible. Con: not Dynamic-Type-aware, harder to tint. Rejected, but emoji can still appear in tooltips and accessibility labels per the clarifications.

---

## 5. `listen_type` reveal UX when typo accepted

**Decision**: Show user's typed answer above and canonical spelling below, with a short note:

```
Casi — la palabra es:
weather        ← canonical, large, bold, accent color
wether         ← user's input, smaller, muted, struck-through
```

**Rationale**:
- Makes the correction immediately visible without ambiguity.
- Mastery is still credited (Levenshtein ≤ 1 = correct) but the user learns the right spelling for next time.
- Matches FR-007a in the spec.

**Alternatives considered**:
- Inline highlighting of the wrong character — clever but harder to read at a glance.
- Just show the canonical with no echo — loses the teaching moment.

---

## Summary — all NEEDS CLARIFICATION resolved

| Topic | Status |
|-------|--------|
| Levenshtein impl | ✅ Pure helpers, in-repo (~20 LOC each) |
| Recommended-mode heuristic | ✅ `argmax(pending) + LRU` |
| Audio caching | ✅ None |
| Mode icons | ✅ SF Symbols locked |
| `listen_type` reveal layout | ✅ Two-line side-by-side with strike-through on typo |
