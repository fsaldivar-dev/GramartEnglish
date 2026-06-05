# CEFR Vocabulary Corpus

This directory holds the curated vocabulary lists used by GramartEnglish.

## Files

- `a1.json`, `a2.json`, `b1.json`, `b2.json`, `c1.json`, `c2.json` — one file per
  CEFR level, each an array of word entries.
- `examples/` — optional canonical example sentences per word, keyed by lemma.
- `verbs.json` — F004 (v1.6.0): hand-curated verb table with conjugation
  metadata used by `conjugate_pick_form` lessons. Each entry's `base` MUST also
  appear in the corresponding level JSON above (so `vocabulary_words(id)` exists
  for the FK on `word_mastery` / `lessons.questions.wordId`).

## Word entry schema

```json
{
  "base": "ephemeral",
  "pos": "adjective",
  "canonicalDefinition": "Lasting for a very short time.",
  "canonicalExamples": [
    "The beauty of cherry blossoms is ephemeral."
  ],
  "sourceTag": "author"
}
```

- `base` — the lemma form (lowercase).
- `pos` — part of speech: `noun`, `verb`, `adjective`, `adverb`, etc.
- `canonicalDefinition` — author-written, ≤ 200 chars, no copyright issues.
- `canonicalExamples` — optional array of 0–3 example sentences (author-written
  or sourced from CC-licensed corpora).
- `sourceTag` — provenance: `cefr-j`, `evp`, `tatoeba`, or `author`.

## Verb entry schema (`verbs.json`)

```json
{
  "id": "verb_go",
  "base": "go",
  "es": "ir",
  "level": "A2",
  "simple_past": "went",
  "past_participle": "gone",
  "irregular": true,
  "audio_base": "go.mp3",
  "audio_past": "went.mp3"
}
```

- `id` — stable verb identifier (`verb_<base>`), used in logs and provenance.
- `base` — English infinitive (lowercase). Must exist as a `vocabulary_words.base` row.
- `es` — Spanish infinitive, shown in the prompt "Pasado simple de **<es>**".
- `level` — conjugation-skill level (A2 or B1 for v1.6.0). Independent of where
  the word's vocabulary entry lives — e.g. `eat` is an A1 vocab word but its
  conjugation drill is A2.
- `simple_past` — canonical English past form (the answer key for `conjugate_pick_form`).
- `past_participle` — canonical English participle (used as one of the distractors).
- `irregular` — `true` when `simple_past` is NOT formed by an `-ed` rule.
- `audio_base` / `audio_past` — filename hints for TTS (forward-compat; not used by v1.6.0).

The v1.6.0 corpus ships **60 verbs**: 40 A2 (20 irregular, 20 regular) + 20 B1
(10 irregular, 10 regular). See `specs/004-verb-conjugation/data-model.md` for
the rationale.

## Sources & licensing

This corpus is assembled from these openly licensed inputs:

| Source | License | Use |
|--------|---------|-----|
| [CEFR-J Wordlist](https://www.cefr-j.org/) | CC BY-SA 4.0 | Word→CEFR level mapping |
| English Vocabulary Profile (EVP) | Open access for research / non-commercial | Secondary level mapping & coverage |
| [Tatoeba](https://tatoeba.org/) | CC BY 2.0 FR | Source of example sentences |
| Author contributions | MIT / public domain | Paraphrased definitions, original examples |

**Important**: Definitions are paraphrased or author-written. Do **NOT** copy
verbatim from copyrighted dictionaries (Oxford, Merriam-Webster, Cambridge,
Collins). When in doubt, write a fresh definition from understanding rather
than reword an existing one.

## MVP target

≥ 50 author-reviewed words per CEFR level (≥ 300 total). See task T115 in
`specs/001-vocabulary-lesson-mvp/tasks.md`.

The seed files committed during scaffolding are placeholders for pipeline
exercising and **must be replaced** before MVP launch.
