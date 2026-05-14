# CEFR Vocabulary Corpus

This directory holds the curated vocabulary lists used by GramartEnglish.

## Files

- `a1.json`, `a2.json`, `b1.json`, `b2.json`, `c1.json`, `c2.json` — one file per
  CEFR level, each an array of word entries.
- `examples/` — optional canonical example sentences per word, keyed by lemma.

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
