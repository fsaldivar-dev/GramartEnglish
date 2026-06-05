# Data Model: Writing Modes

**Feature**: 003-writing-modes
**Status**: Final
**Migration**: NONE — `schemaVersion` stays at **3**

F003 changes **no tables**. Per-mode mastery already lives at `(userId, wordId, mode)` since F002's migration 0003.

The only data-shape additions are at the **DTO** layer (in-memory + wire).

---

## DTO additions

### `LessonMode` (TS + Swift enum)

Three new raw values; the SHIPPED_MODES list grows from 4 → 6 (or 7 if US3 ships in v1.3):

```diff
 export const LessonMode = z.enum([
   'read_pick_meaning',
   'listen_pick_word',
   'listen_pick_meaning',
   'listen_type',
+  'write_pick_word',
+  'write_type_word',
+  'write_fill_gaps',   // P3 / deferred; ships in v1.4 unless time allows
 ]);

 export const SHIPPED_MODES: readonly LessonMode[] = [
   'read_pick_meaning',
   'listen_pick_word',
   'listen_pick_meaning',
   'listen_type',
+  'write_pick_word',
+  'write_type_word',
 ];
```

Swift mirrors this in `app/Packages/LessonKit/Sources/LessonKit/LessonMode.swift`:
- Promote `writePickWord` and `writeTypeWord` from `ComingSoonMode` to `LessonMode`.
- Differentiate `displaySubtitle`:
  - `writePickWord` → "Escribir — reconoce en inglés"
  - `writeTypeWord` → "Escribir — escribe la palabra"
- Keep `writeFillGaps` in `ComingSoonMode` (or add a new `LessonMode` case that the UI excludes from `SHIPPED_MODES` until US3 ships).

### `LessonQuestion` DTO (wire + Swift)

```diff
 export const LessonQuestion = z.object({
   id: z.string().uuid(),
   word: z.string(),
+  prompt: z.string().optional(),   // Spanish meaning, populated for write modes
   options: z.array(z.string()).length(4),
   position: z.number().int(),
 });
```

**Population rules** (server-side):

| Mode | `word` (always) | `prompt` (added) | `options` |
|---|---|---|---|
| `read_pick_meaning` | English canonical | _absent_ | 4 Spanish meanings |
| `listen_pick_word` | English canonical | _absent_ | 4 English words |
| `listen_pick_meaning` | English canonical | _absent_ | 4 Spanish meanings |
| `listen_type` | English canonical | _absent_ | _absent (typed mode)_ |
| **`write_pick_word`** | English canonical | **Spanish meaning** | 4 English words |
| **`write_type_word`** | English canonical | **Spanish meaning** | _absent_ |
| **`write_fill_gaps`** | English canonical | **Spanish meaning + gap-masked English** | _absent_ |

For `write_fill_gaps` the `prompt` becomes a 2-line concatenation: Spanish meaning + masked English (e.g. `"clima · w__th_r"`). The exact UI rendering is the client's responsibility.

### `AnswerLessonRequest` (wire)

```diff
 export const AnswerLessonRequest = z.object({
   questionId: z.string().uuid(),
   optionIndex: z.number().int().min(0).max(3).optional(),
   typedAnswer: z.string().trim().min(1).max(80).optional(),
+  hintUsed: z.boolean().optional(),
   answerMs: z.number().int().nonnegative(),
 });
```

`hintUsed: true` causes the backend to zero `consecutiveCorrect` even on a correct answer (FR-009). Optional — defaults to `false`.

### `questions` table (no schema change, but new in-memory column)

The existing `questions` table has `typedAnswer` from F002. We optionally store `hintUsed: 0|1` on the row going forward — but **adding a column would require migration 0004**. To avoid a migration in F003:

- **Decision**: keep `hintUsed` in-memory only for the lifetime of the response. Don't persist it to `questions`. SC-004 ("hint frequency drops over time") is computed from a **log query** against the structured log stream (we already log `lesson.answered` events with arbitrary fields). Adding `hintUsed` to that log entry is a non-schema change.

If product later needs SQL-queryable hint history, F004's migration can add the column without retroactive backfill.

---

## Constraints

- All DTO additions are **optional fields** (zod `.optional()` and Swift `String?`). v1.2 clients keep working.
- `schemaVersion` stays at **3**. No `0004_*.sql` migration in this feature.
- `version.json` bumps to `1.3.0` (MINOR per Principle V — new feature, backward compatible).

## Rollback

There is no DB rollback because there is no DB change. To roll back F003:

1. `git revert` the F003 merge commit.
2. Old clients (v1.2) keep working against the new backend AND old backend works against v1.3 clients (graceful degradation: a v1.2 backend won't emit `prompt`, the v1.3 client falls back to `word`-based rendering — which displays English instead of Spanish for write modes, a clear "this server is too old" hint to the user).

Cross-version compatibility:

| Client | Backend | Behavior |
|---|---|---|
| v1.2 | v1.2 | All listening + read modes work. |
| v1.2 | v1.3 | Same as v1.2 + v1.2 (client doesn't see new modes). |
| v1.3 | v1.2 | Write mode cards are visible, but selecting one fails server-side (zod rejects the unknown enum value → 400 → app shows error). |
| v1.3 | v1.3 | Full feature. |
