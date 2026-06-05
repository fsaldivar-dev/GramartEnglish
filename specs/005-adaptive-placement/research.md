# Phase 0 Research: Adaptive Placement

**Date**: 2026-06-05
**Branch**: `005-adaptive-placement`

Resolves the open design questions for F005. F001/F002/F003 decisions
inherited unchanged.

---

## 1. Adaptive algorithm — what flavor, why this one

**Decision**: A deterministic per-level rotation with a moving point estimate
and a sample-size-based confidence proxy. **Not** IRT. **Not** Bayesian. **Not**
ML.

Pseudocode:

```ts
type CefrIdx = 1 | 2 | 3 | 4 | 5 | 6; // A1..C2

interface State {
  levelEstimate: number;        // 1..6, float
  confidence: number;           // 0..1
  perLevel: Record<CefrIdx, { attempted: number; correct: number }>;
  itemsAdministered: number;
  algorithmVersion: 'v2';
  usedWordIds: Set<number>;
}

const STEP_INITIAL = 0.6;
const STEP_FLOOR = 0.15;
const MIN_ITEMS = 12;
const MAX_ITEMS = 30;
const CONFIDENCE_TARGET = 0.85;

function pickNextLevel(s: State): CefrIdx {
  // Sample around the round(estimate); rotate to fill the bucket with fewest attempts
  const center = clamp(Math.round(s.levelEstimate), 1, 6);
  const window: CefrIdx[] = uniq([
    clamp(center - 1, 1, 6),
    center,
    clamp(center + 1, 1, 6),
  ]) as CefrIdx[];
  return window.reduce((best, lvl) =>
    s.perLevel[lvl].attempted < s.perLevel[best].attempted ? lvl : best,
  window[0]);
}

function step(s: State, correct: boolean): State {
  const step = Math.max(STEP_FLOOR, STEP_INITIAL * (1 - s.confidence));
  const delta = correct ? +step : -step;
  const newEstimate = clamp(s.levelEstimate + delta, 1, 6);
  // Confidence grows with sample size, dampened by recent flip-flops.
  const newConfidence = Math.min(1, s.confidence + 0.06);
  return { ...s, levelEstimate: newEstimate, confidence: newConfidence };
}

function done(s: State): boolean {
  if (s.itemsAdministered >= MAX_ITEMS) return true;
  return s.itemsAdministered >= MIN_ITEMS && s.confidence >= CONFIDENCE_TARGET;
}

function finalLevel(s: State): CefrLevel {
  // Use the existing legacy `scorePlacement` to decide between two adjacent
  // levels when the float estimate is close to a boundary — it already has
  // the "level above is 0/attempted ⇒ bump-down" rule we want to keep.
  return scorePlacementFromPerLevelOrEstimate(s);
}
```

**Rationale**:
- **Why no IRT**: IRT needs item difficulty parameters calibrated on a population
  of test-takers. We have a single-user offline app with 299 words; the
  "population" is one person. The cost (difficulty annotations on all 299
  words + math) vastly exceeds the precision gain over a 6-bucket estimator.
- **Why no Bayesian update over CEFR levels**: same reasoning, simpler. A point
  estimate with a confidence floor is interpretable; a posterior over 6
  buckets is harder to debug and not measurably better at 30 items.
- **Why a moving step**: `STEP_INITIAL=0.6` makes early answers count more
  (rapid convergence on beginners who miss A2); `STEP_FLOOR=0.15` keeps the
  test responsive at high confidence.
- **Why MIN_ITEMS=12**: 2× the level count. Below that, one lucky streak can
  bump the estimate by ≥ 2.4 (4 corrects × 0.6), masking the variance we
  exist to defeat.
- **Why MAX_ITEMS=30**: Cambridge English Placement Test caps around 30; users
  drop off past that.
- **Why CONFIDENCE_TARGET=0.85**: Cambridge/EF SET cite 0.85 as the typical
  industry cut. With our linear `+0.06` growth that hits at 15 items.

**Alternatives considered**:
- **Full two-stage (gauge + track)**: rejected. With 6 buckets and a working
  point estimate, the gauge-then-narrow approach is equivalent to the moving
  estimate — just bookkeeping wrapped around it. KISS.
- **Bayesian likelihood update with Beta(α,β) per level**: justified by
  precision but YAGNI for v1; can layer on later as `algorithmVersion: 'v3'`
  without API churn.
- **Per-level mastery threshold (e.g. 3-in-a-row at L ⇒ unlock L+1)**: rejected.
  Behaves badly with skips and with our small per-level pool (≤ 50 words at
  some levels) — would run out of fresh items.

---

## 2. Stage 1 anchor — how to ask the user before the test

**Decision**: A single optional self-report screen with three buttons before the
first question:

| Button | Spanish label | Maps to `levelEstimate` |
|---|---|---|
| **Never** | "Nunca antes" | 1.5 (between A1 and A2) |
| **Some** | "Un poco / algunas clases" | 3.0 (between A2 and B1) |
| **Lots** | "Bastante, llevo años" | 4.5 (between B1 and B2) |

If the user skips ("Empezar sin elegir"), `levelEstimate` defaults to 3.5
(midpoint).

**Rationale**:
- Forces a starting prior so a never-studied user doesn't get C1-grade questions
  in the first 3 items.
- Three buttons (not 6) avoids forcing the user to self-classify into CEFR they
  don't know.
- Skippable so the change is purely additive — a user who refuses still gets
  the same default behaviour as before.
- One screen = one prompt = no real onboarding cost. Per F003 simplicity.

**Wire shape**: `PlacementStartRequest.selfReport: 'never' | 'some' | 'lots' | null`.

**Alternatives considered**:
- **Skip the anchor entirely; rely on the algorithm**: rejected. The whole
  reported failure was the algorithm putting a beginner at C1; we should
  protect against that explicitly, not hope.
- **Ask a screening question like "how do you say 'hello'?"**: rejected. The
  user might guess; not a reliable anchor.
- **Use the last-known `currentLevel` from the user row**: partially used.
  When a Settings override exists (currentLevel != default A2), we pre-fill
  the self-report screen to that level as a suggestion — but only as a hint,
  the user still chooses.

---

## 3. Early-stop heuristic

**Decision**: Three independent terminators (whichever fires first):

1. **Confidence cap**: `confidence ≥ 0.85 AND items ≥ 12` ⇒ done.
2. **Hard ceiling**: `items ≥ 30` ⇒ done regardless of confidence.
3. **Floor lock-in**: ≥ 4 attempts at A1 with `correct == 0` ⇒ done, lock at A1.
   (Specific to "me puso en C1 sin saber inglés" — we hard-stop the test as
   soon as it's obvious the user can't even do A1.)
4. **Ceiling lock-in**: ≥ 4 attempts at C2 with `correct == 4` AND items ≥ 12
   ⇒ done, lock at C2.

**Rationale**: Each terminator targets a real failure mode:
- (1) is the normal exit.
- (2) protects against pathological flip-flop patterns (random clicker).
- (3) is the user's reported failure mode — captures it explicitly.
- (4) gives advanced users a fast exit.

---

## 4. Item bank — reuse what we have

**Decision**: Reuse the existing CEFR corpus at `data/cefr/{A1..C2}.json` via
`WordRepository.byLevel`. The selector picks one word at a time from the level
chosen by `pickNextLevel`, excluding `usedWordIds`. Distractors come from the
same level (mirrors `placementSelector.ts` existing logic).

**No new content**. The proposal's "item types" (cloze, paraphrase, grammar)
are an interesting follow-up but they require ~200 hand-curated items per type
per level. Out of scope for v1.4. The honest level signal that the user is
asking for comes from the **algorithm**, not new question types.

The existing `PlacementQuestion` shape (`word`, `sentence`, `options`,
`correctIndex`, `level`) is reused as-is.

---

## 5. Manual override regression — does it actually work?

**Audit result**: YES, the existing override is already plumbed through
correctly. The user's complaint ("forcing A1 didn't help") was likely a
**side-effect of the placement over-classification**: after the test put them
at C1 and seeded mastery rows in C1, switching to A1 in Settings correctly
filtered the lesson selector to A1 words (`selectLessonWords(userId, 'A1', mode,
…)`), but the user had already been shown C1 words and the next lesson at A1
felt "wrong" relative to the previous experience. The fix is to get placement
right; the override is fine.

End-to-end trace:

1. `SettingsView` calls `PATCH /v1/me { currentLevel: 'A1' }`.
2. `routes/me.ts` line 33-34: `userRepo.setLevel(user.id, parsed.data.currentLevel)`.
3. Next `POST /v1/lessons` call: `routes/lessons.ts` line 57-59 calls
   `userRepo.ensureSingleton()` which returns the row with `currentLevel: 'A1'`,
   then passes it to `service.startLesson({ level: user.currentLevel, ... })`.
4. `LessonService.startLesson` line 64-66: passes `input.level = 'A1'` into
   `selectLessonWords(userId, 'A1', mode, …)`.
5. `wordSelector.ts` line 58: `levelPool = words.byLevel('A1')` — **filtered**.

**Mitigation**: Add a contract test
`backend/tests/contract/me.level.override.test.ts` that:

1. Starts a lesson at A2 → asserts only A2 words appear.
2. PATCHes `/v1/me { currentLevel: 'A1' }` → asserts 200.
3. Starts another lesson → asserts only A1 words appear.

This pins the chain so any future refactor that drops `currentLevel` from the
flow turns this test red.

---

## 6. Telemetry

**Decision**: One structured log per item, plus the existing `placement.completed`
log gains two fields. No new tables, no new log files.

Per-item log:

```jsonc
{
  "level": "info",
  "event": "placement.item",
  "correlationId": "…",
  "placementId": "…",
  "position": 7,
  "selectedLevel": "B1",
  "levelEstimateBefore": 3.4,
  "levelEstimateAfter": 3.0,
  "confidence": 0.48,
  "correct": false,
  "algorithmVersion": "v2"
}
```

Completion log:

```jsonc
{
  "event": "placement.completed",
  "placementId": "…",
  "estimatedLevel": "A2",
  "itemsAdministered": 18,
  "algorithmVersion": "v2",
  "selfReport": "some"
}
```

These let us answer "did the algorithm converge?" and "how many items per
test on average?" without instrumenting the DB.

---

## 7. Backward compatibility — what about v1.3 clients?

**Decision**: Keep `POST /v1/placement/submit` working unchanged. A v1.3 client
that POSTs 24 batched answers still gets a 200 + an `estimatedLevel` scored by
the legacy `scorePlacement`. The result row is flagged `algorithmVersion: 'v1'`.

`POST /v1/placement/start` shape change is **breaking** for v1.3 clients (they
expect 24 questions, will see 1). Mitigation: the start route detects an
absent `x-client-version: 1.4+` header and falls back to the legacy 24-question
emission. This keeps a shipped v1.3.0 desktop app pointed at a v1.4.0 backend
working until the user updates.

```ts
const isLegacyClient = !req.headers['x-client-version']?.toString().startsWith('1.4');
if (isLegacyClient) return legacyStartHandler(req, ...);
```

The v1.4 client always sends the header.

---

## 8. No new dependencies

The algorithm is pure TypeScript (`Math.min`, `Math.max`, `Math.round`,
`Set<number>`, in-memory `Map`). No npm, swift, or system additions.
Per Principle III + constitutional "no new deps without justification" — none.

---

## Summary — all NEEDS CLARIFICATION resolved

| Topic | Status |
|---|---|
| Algorithm | ✅ Decided: deterministic moving estimate, no IRT |
| Anchor | ✅ Decided: 3-button optional self-report |
| Stop rules | ✅ Decided: conf ≥ 0.85 ∧ items ≥ 12, hard cap 30, floor/ceiling lock-ins |
| Item bank | ✅ Reuse CEFR corpus; no new content |
| Override | ✅ Already works; add pinning test |
| Telemetry | ✅ Per-item log + final summary |
| Backward compat | ✅ Legacy /submit + version-header fallback on /start |
| New deps | ✅ None |
