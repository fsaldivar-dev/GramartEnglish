# F004 v1.6.0 — Data Model Delta

## Persistent storage — UNCHANGED

`schemaVersion` stays at **3**. No new tables, no column changes, no migration. The existing per-mode mastery axis `(userId, wordId, mode)` is reused as-is.

## New in-memory entity — `VerbRow`

Source: `data/cefr/verbs.json`. Loaded once at server boot via `loadVerbCorpus(corpusDir, wordRepository)`.

```ts
interface VerbRow {
  id: string;          // "verb_<base>", e.g. "verb_go"
  wordId: number;      // FK into vocabulary_words.id (resolved at load time)
  base: string;        // English infinitive (lowercase)
  es: string;          // Spanish infinitive ("ir", "comer", ...)
  level: CefrLevel;    // A2 | B1 (v1.6.0 corpus)
  simplePast: string;  // canonical English past form ("went", "ate", ...)
  pastParticiple: string;
  irregular: boolean;
  audioBase: string;   // forward-compat (TTS file hint, not used by v1.6.0)
  audioPast: string;   //   "
}
```

### Invariants

1. Every `VerbRow.base` MUST correspond to an existing `vocabulary_words.base`. Verbs whose base is missing are silently skipped at load (defensive); the `verbConjugationBuilder.test.ts` corpus invariant asserts `wordId > 0` for every loaded verb.
2. `id` is stable across releases — once shipped, never renamed.
3. `level` is the **conjugation-skill** level, independent of the verb's vocabulary level. (`eat` is A1 vocab, A2 conjugation.)

### v1.6.0 corpus snapshot

- A2: 40 verbs (20 irregular, 20 regular).
- B1: 20 verbs (10 irregular, 10 regular).
- Total: 60 verbs, 30 irregular (50%).

A complete list lives in `data/cefr/verbs.json`. Provenance: author-curated, cross-referencing the existing A1+A2+B1 vocabulary rows; the 21 verb bases not previously in the corpus were added to `a2.json` / `b1.json` in this release.

## DTO delta — `LessonQuestion`

Two new **optional** fields:

```yaml
verbBase:    string?          # English base form, e.g. "go"
targetTense: "simple_past"?   # v1.6.0 ships this single value
```

Both fields are `null` / omitted for non-conjugation modes. Existing clients that ignore unknown fields continue to work.

The on-the-wire prompt for `conjugate_pick_form` is `prompt: "Pasado simple de **<es>**"` — the same `prompt` field added in F003 for write modes is reused.

## Mastery semantics — UNCHANGED, REUSED

A conjugation question records mastery on `(userId, verbWordId, "conjugate_pick_form")`:
- 2 consecutive corrects → `mastered = true` (per F002 rule).
- Mastery in `conjugate_pick_form` does NOT affect mastery in `read_pick_meaning` for the same word, by design (per-mode axis).

`MasteryRepository` and `modeRecommender` work unchanged. The recommender's "pending = level_pool − mastered_in_mode" formula uses `vocabulary_words` for the level pool, which correctly includes all verbs that were added to a2.json/b1.json.

## No new endpoints

`POST /v1/lessons` with `mode: "conjugate_pick_form"` is the only delta surface. The existing `/answers`, `/skip`, `/complete`, and `/v1/progress` endpoints work without changes.
