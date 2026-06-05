# Data Model: Adaptive Placement

**Feature**: 005-adaptive-placement
**Status**: Final
**Migration**: NONE — `schemaVersion` stays at **3**

F005 changes **no tables**. The existing `placement_results` row already stores
`perLevelScores` (JSON) + `estimatedLevel`; we keep writing the same columns.

The only data-shape additions are at the **DTO layer** (in-memory + wire) and
two new optional fields on the persisted JSON envelope.

---

## DTO additions

### `PlacementStartRequest` (wire)

```diff
 export const PlacementStartRequest = z.object({
   seed: z.number().int().optional(),
+  selfReport: z.enum(['never', 'some', 'lots']).nullish(),
 }).partial().optional();
```

`null` and `undefined` both mean "skipped"; algorithm defaults to estimate 3.5.

### `PlacementStartResponse` (wire) — **shape change**

```diff
 // v1.3 (legacy)
 // { placementId, questions: PlacementQuestion[] }   // 24 items, all upfront

 // v1.4+ (adaptive)
 {
   placementId: string,
   question: PlacementQuestion,       // ONE question
   progress: { current: 1, max: 30 }, // hint for the UI
   algorithmVersion: 'v2'
 }
```

A v1.3 client that doesn't send `x-client-version: 1.4+` still gets the legacy
24-question shape (see research §7).

### `PlacementAnswerRequest` (wire) — **NEW**

```ts
export const PlacementAnswerRequest = z.object({
  placementId: Uuid,
  questionId: Uuid,
  optionIndex: z.number().int().min(-1).max(3),  // -1 = "no lo sé"
});
```

### `PlacementAnswerResponse` (wire) — **NEW**

A discriminated union:

```ts
type PlacementAnswerResponse =
  | {
      kind: 'continue';
      question: PlacementQuestion;
      progress: { current: number; max: number };
    }
  | {
      kind: 'done';
      result: PlacementResultResponse;
    };
```

### `PlacementResultResponse` (wire) — additive

```diff
 export const PlacementResultResponse = z.object({
   estimatedLevel: CefrLevel,
   perLevelScores: PerLevelScoresMap,
+  algorithmVersion: z.enum(['v1', 'v2']).optional(),
+  itemsAdministered: z.number().int().optional(),
 });
```

Both new fields are **optional** — v1.3 clients ignore them.

### `PlacementSubmitRequest/Response` (legacy)

**Unchanged.** Kept verbatim so v1.3 clients keep working. Routes to the legacy
`scorePlacement` flow and writes `algorithmVersion: 'v1'`.

---

## In-memory `InFlightPlacement` (server-side)

The current map `placements: Map<string, InFlightPlacement>` keeps its shape
plus adaptive state:

```diff
 interface InFlightPlacement {
   id: string;
-  questions: PlacementQuestion[];
+  /** v1.4 adaptive state. Legacy v1.3 placements have algorithmVersion='v1'
+   *  and use the `questions` array only. */
+  algorithmVersion: 'v1' | 'v2';
+  // v2 only:
+  state?: AdaptivePlacementState;
+  // v1 only:
+  questions?: PlacementQuestion[];
+  // both:
+  delivered: PlacementQuestion[];     // every question shown so far (for /answer lookup)
+  startedAt: number;                  // ms epoch for TTL eviction
 }
```

`AdaptivePlacementState` lives in `backend/src/lessons/adaptivePlacement.ts`:

```ts
export interface AdaptivePlacementState {
  levelEstimate: number;        // 1..6
  confidence: number;           // 0..1
  perLevel: Record<CefrIdx, { attempted: number; correct: number }>;
  itemsAdministered: number;
  usedWordIds: Set<number>;
  algorithmVersion: 'v2';
}
```

In-memory only — no persistence, no migration.

---

## Persisted JSON envelope

The `placement_results.perLevelScores` column is JSON-typed (TEXT in SQLite).
Today it stores `Record<CefrLevel, {attempted, correct}>`. We keep that shape
**unchanged** to avoid breaking the existing `PerLevelScore` typed reads.

The new `algorithmVersion` and `itemsAdministered` go into a sibling field via
a tiny envelope-extension on the in-memory row before encoding:

```ts
interface PlacementResultRow {
  // existing
  id: string;
  userId: string;
  takenAt: string;
  perLevelScores: Record<CefrLevel, PerLevelScore>;
  estimatedLevel: CefrLevel;
  userOverride: CefrLevel | null;
  // F005 — read off `perLevelScores._meta` if present, undefined otherwise
  algorithmVersion?: 'v1' | 'v2';
  itemsAdministered?: number;
}
```

We persist by stashing the metadata under the reserved sentinel key `_meta`
inside the JSON column:

```jsonc
{
  "A1": { "attempted": 3, "correct": 2 },
  "A2": { "attempted": 4, "correct": 3 },
  "_meta": { "algorithmVersion": "v2", "itemsAdministered": 18 }
}
```

The repository's existing decode treats unknown keys as no-op; the new
`algorithmVersion` reader filters out `_meta` before iterating. **No migration**.

---

## Constraints

- All DTO additions are **optional fields** (zod `.optional()` / `.nullish()`,
  Swift `String?` / `Int?`). v1.3 clients keep working unchanged.
- `schemaVersion` stays at **3**.
- `version.json` bumps to **1.4.0** (MINOR per Principle V — new feature,
  backward compatible).

## Rollback

There is no DB rollback because there is no DB change. To roll back F005:

1. `git revert` the F005 merge commit.
2. Existing `placement_results` rows with `_meta` keep working — the legacy
   decoder simply doesn't read it.

Cross-version compatibility:

| Client | Backend | Behavior |
|---|---|---|
| v1.3 | v1.3 | Existing 24-question linear placement. |
| v1.3 | v1.4 | Legacy `/start` (24 questions) + `/submit` works thanks to header sniff. |
| v1.4 | v1.3 | Client sends `selfReport`, gets old 24-question shape; client must fall back to batch flow. Acceptable because v1.4 ships its app + backend together. |
| v1.4 | v1.4 | Full adaptive feature. |
