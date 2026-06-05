# F004 v1.6.0 — Research Notes

## R1. Why a side-channel JSON instead of a `verbs` SQL table?

**Option A — promote to a real `verbs` table** (the original F004 draft's plan).
- Pros: type-clean, easy to query at scale, can add `examples`, `alternates`.
- Cons: requires migration 0004, schemaVersion → 4, rollback path, mastery FK either widens to (`userId, verbId, mode`) (new PK) or keeps `wordId` (denormalized). New entity ⇒ +1 repo + +1 fake + +1 migration test.

**Option B — overlay JSON on `vocabulary_words`** (chosen).
- Each verb's English `base` is added to (or already in) `vocabulary_words`. The mastery FK uses the same `wordId`. Verb-specific metadata lives in `verbs.json`, loaded into a `Map` once at boot.
- Pros: zero migration, `schemaVersion` stays at 3, mastery axis reused with no widening.
- Cons: verb metadata is technically in-memory only (rebuild = re-read JSON), but the corpus is 60 entries so reload cost is < 1 ms.

**Decision**: B for v1.6.0. The original F004 draft anticipated ≥ 80 verbs × 4 tenses × ≥ 1 example each = 320+ entries; at that scale Option A becomes more attractive. v1.6.0's 60 × 1 tense × 0 examples scale firmly stays in B's sweet spot.

If F004 US2 (`conjugate_type_form`) adds the other 3 tenses or starts requiring example sentences per `(verb, tense)`, promote to a real table in a follow-up migration.

## R2. Distractor recipe — picking the right wrong answers

PO+TL lock: `[over_regularized, base_form, past_participle, +1 random_same_level_past]`.

The rationale per slot:
- **over_regularized** (`"goed"`). Targets the canonical L2 mistake: applying the regular `-ed` rule to an irregular base. Spanish-speaking learners reach for this form almost every time they forget the irregular form.
- **base_form** (`"go"`). Targets the second-most-common mistake: leaving the verb un-conjugated when uncertain ("yesterday I go to the store").
- **past_participle** (`"gone"`). Targets the third confusion: in Spanish there's no morphological distinction between past simple and past participle for many verbs (`comí` vs `comido`); learners often substitute the participle for the simple past.
- **+1 random same-level past** (e.g. `"saw"`). Catches the lucky-guess case where all three structured distractors collide with the answer (regular verbs).

**Collision handling** is deliberate: when slots collapse onto the same string we don't pad with garbage — we draw additional same-level past forms. The L2 mistakes those random-past distractors target are weaker, but the question still functions as a 4-MCQ.

## R3. Why is `overRegularize` so naïve?

The function returns `base + "ed"`. No silent-e dedup (`bake → bakeed` not `baked`). No consonant doubling (`stop → stoped` not `stopped`). No `y → ied` (`try → tryed` not `tried`).

This is *correct* for our use case. We're modelling the L2 mistake, not the linguist's spelling rule. A student who doesn't yet know "stopped" doesn't know the consonant-doubling rule either — they reach for `stoped`. Showing them `stopped` as a distractor would either reinforce confusion (it looks right) or be answerable by spell-checking instinct (defeating the point of the question).

Where the naïve rule produces the *correct* English form (e.g. for true regular verbs where `traveled = traveled`), the collision fallback in `buildVerbQuestion` handles it.

## R4. Spanish prompt copy lock

`"Pasado simple de **<es>**"`. Trade-offs considered:
- `"Conjuga en pasado: <es>"` — too verb-y; the student must figure out what "conjugate" means before they answer.
- `"Pasado de <es>"` — ambiguous between simple past and other past tenses.
- `"Pasado simple de **<es>**"` — explicit tense, explicit verb, markdown emphasis on the verb itself so the prompt scans as "<grammatical concept> de <thing>". Locked by PO+TL.

Tests pin the exact string in both backend (`Pasado simple de **ir**`) and Swift (`ConjugationLessonViewTests`). Changing the copy requires updating both.

## R5. Why is `conjugate_pick_form` NOT classified as a `isWriting` mode?

F003's `isWriting` flag means: *Spanish prompt → English vocabulary answer, axis = noun/adjective/verb-as-lemma*. Conjugation's axis is different — it's *Spanish verb → English form*. Mixing the two would force `WritingLessonView` to either branch internally or be renamed.

Cleaner: add a parallel `isConjugation` flag. `WritingLessonView` stays single-axis; `ConjugationLessonView` is a separate ~80-LOC view. The two share `OptionCard` and `ProgressHeader` but diverge in copy + prompt-hero rendering.

## R6. Why bump to **MINOR** 1.6.0 and not PATCH 1.5.4?

Per Constitution V — a new shipped LessonMode that the client surfaces on Home and that adds DTO fields is unambiguously additive-feature territory. PATCH is reserved for bug fixes + polish. MINOR is correct.

## R7. v1.6.0 patch: exclude `base === simple_past` verbs from `conjugate_pick_form`

USER (Marisol, A2) hit `verb_read` in her first lesson: the prompt was
"Pasado simple de **leer**" with options that included `read` (correct
past) and `read` (base) — visually identical, unanswerable without audio.

**Rule**: any verb where `base.toLowerCase() === simple_past.toLowerCase()`
is excluded from the `conjugate_pick_form` selector. Other modes
(`read_pick_meaning`, `write_*`, `listen_*`) are unaffected — those modes
key on meaning + audio, not on tense form.

The English verbs caught by this rule (not all of which ship in our
corpus): `read`, `cut`, `put`, `hit`, `let`, `set`, `cost`, `hurt`,
`bet`, `quit`, `shut`, `spread`. We deleted `verb_read` from
`data/cefr/verbs.json` in this patch. Corpus dropped from 60 → 59
verbs (A2: 40 → 39, B1: 20 unchanged). Both pools remain comfortably
above the `LESSON_SIZE = 10` floor.

The predicate is exposed as `isAmbiguousForPickForm()` in
`verbConjugationBuilder.ts` so future additions to `verbs.json` are
guarded by a test (`verbConjugationBuilder.test.ts` → "excludes verbs
whose base equals simple_past from conjugate_pick_form").

## R8. v1.6.0 patch: per-verb example sentences to disambiguate tense

Spanish distinguishes preterite (`comí`) from imperfect (`comía`); English
collapses both to `ate`. A learner can mentally answer "comía → eated"
and feel cheated when the app marks them correct for the "wrong" reason
(or wrong for the "right" reason). Adding the temporal-marker example
("Ayer ___ tacos.") anchors the answer to past simple specifically.

Each verb in `verbs.json` ships:
- `example_es`: Spanish sentence with `___` for the verb slot, anchored
  by a temporal marker (ayer, anoche, la semana pasada, el año pasado,
  el verano pasado, el mes pasado).
- `example_en`: English translation with the verb already conjugated,
  revealed post-answer for reinforcement.

The Spanish example renders below the "Pasado simple de **<es>**" hero
in a secondary style. The blank `___` IS the disambiguator — it tells
the learner exactly where the answer belongs.
