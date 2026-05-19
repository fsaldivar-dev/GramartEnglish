# Proposal — Feature 002: Adaptive placement test

**Status**: Drafted as a future-feature proposal. NOT in MVP scope.
**Why**: The current placement (24 questions, 4 per CEFR level, multiple-choice on word meaning) consistently over-classifies beginner/intermediate users as advanced. A single user reported getting C1 / B2 / C2 across three runs of equivalent skill. This proposal collects what real tests do and translates it into a concrete design for GramartEnglish v2.

## Problem statement

1. **High variance**: 4 questions/level gives wide swings. ≥50% threshold means 2/4 correct = pass that level — and 2/4 is easily achievable by elimination/guessing on the 4 Spanish options.
2. **Single modality**: We only test "given a word in context, pick the Spanish meaning." A real C2 distinction requires testing collocation, paraphrase, productive use, and grammar — not just receptive translation.
3. **Linear, not adaptive**: We show 4 questions at every level regardless of performance. A beginner who fails A1 should never see C2 questions; an advanced learner shouldn't waste 8 questions on A1/A2.

## What real tests do

| Test | Length | Strategy |
|------|--------|---------|
| **Cambridge English Placement Test** | ~30 min | Adaptive two-stage |
| **EF SET** | 50 min | Adaptive; reading + listening |
| **Pearson Versant** | 17 min | Adaptive; speaking + listening + reading |
| **Oxford Placement Test** | ~30 min | Adaptive grammar + listening |

Common pattern (per Clarity English, ETS, Cambridge):

1. **Gauge phase** (10–20 items, broad spread A1–C2)
   - Goal: place the test-taker into a track: **A** (A1–A2), **B** (B1–B2), or **C** (C1–C2)
   - Difficulty alternates: each item is easier or harder than the last depending on the previous answer
2. **Track phase** (20–30 items, narrow spread within the gauge result)
   - Goal: pinpoint exact level (A1 vs A2; B1 vs B2; C1 vs C2)
   - Item difficulty fine-tunes around the running estimate

Bayesian item-response theory (IRT) underlies the algorithm. We don't need full IRT — a simple "two-stage adaptive" is enough.

## Vocabulary thresholds (research consensus)

| Level | Receptive vocabulary (word families) |
|-------|--------------------------------------|
| A1 | ~500 |
| A2 | ~1,000 |
| B1 | ~2,000 |
| B2 | ~3,250 |
| C1 | ~5,000 |
| C2 | ~7,000–9,000+ |

Sources: Milton (2009) using X-Lex; CEFR-J Wordlist; English Vocabulary Profile.

For *receptive* vocabulary (what our app currently tests), being at C2 means the user
can recognize most of the 7k–9k most-common English words — a high bar, not "got
half right on 4 C2 questions."

## Item types worth adding

Currently we have **one** item type: "see word in sentence, pick Spanish meaning." Real tests use:

1. **Cloze** — sentence with a blank; pick the word/phrase that fits
   > "The cherry blossoms are ___ — gone in a week."
   > A: durable B: ephemeral C: ancient D: noisy
   - Tests usage + collocation, not just translation
2. **Paraphrase choice** — read a short sentence; pick the option that means the same
   > "He gave a perfunctory nod."
   > A: He nodded with great enthusiasm
   > B: He nodded out of obligation, without warmth
   > C: He refused to nod
   > D: He nodded after long thought
   - Tests deep comprehension, not surface translation
3. **Spot the error** — sentence with one grammatical mistake; pick where
   > "She **has been** living **in there** since 2018."
   - Tests grammar, not vocabulary
4. **Best continuation** — incomplete sentence; pick the natural continuation
   > "If I had known about the meeting, I ___ ."
   > A: will come B: would have come C: am coming D: come
   - Tests grammar + register

## Proposed design for feature 002

### Algorithm (no IRT required)

State:
- `levelEstimate: float` initialised to 3.5 (midpoint of A1=1..C2=6)
- `confidence: float` starts at 0; increases with each consistent answer
- `itemBank: { id, level: 1..6, difficulty: -1..+1 inside level }[]` precomputed

Each turn:
1. Pick the next item whose `level + difficulty` is closest to `levelEstimate`
2. After answer: move `levelEstimate` by ±0.2–0.5 (step shrinks as confidence grows)
3. Stop when `confidence >= 0.85` OR after `maxItems` (default 30)
4. Return final level = round(`levelEstimate`)

### UI

- Bigger window for the gauge phase (~30 questions visible-progress)
- A subtle indicator: "Calibrando…" while in gauge, "Afinando…" while in track
- Don't tell the user the running estimate — that biases them

### Corpus changes

- Add `difficulty: -1..+1` to each `VocabularyWord` (where it sits *within* its CEFR level)
- Curate a separate `placement-bank.json` with 5–10 items per level per item-type (cloze, paraphrase, grammar) — separate from lesson corpus

### Migration

- New `placement_v2_items` table (cloze, paraphrase, grammar items)
- Backward-compatible: the v1 placement (current 24-question word-meaning test) still works for users who want a fast estimate

## Effort estimate

- ~3 days of work
- 200+ curated placement items across types and levels (significant content effort)
- New routes, new VM, new view, new tests
- Could ship as **feature 002 — Adaptive placement & richer testing**

## Decision

**Deferred to feature 002.** Current placement is "good enough" for the MVP — it gets you in the ballpark. For honest level estimation, this proposal is the answer. Track in [tasks-002.md] when ready to start.

## References

- [Clarity English: Why an adaptive test is the only answer](https://blog.clarityenglish.com/adaptive-test-answer/)
- [Cambridge English Placement Test — Teachers Guide (PDF)](https://www.cambridgeenglish.org/Images/181158-cambridge-english-placement-test-for-young-learners-teachers-guide.pdf)
- [Pearson Versant Placement Test relating to CEFR (PDF)](https://www.pearson.com/content/dam/one-dot-com/one-dot-com/english/versant-test/Relating-VEPT-to-the-CEFR.pdf)
- [EF SET CEFR C2 reference](https://www.efset.org/cefr/c2/)
- [Milton (2009): Vocabulary breadth across CEFR levels (PDF)](https://eurosla.org/monographs/EM01/211-232Milton.pdf)
- [Paul Nation: Vocabulary and the CEFR](https://www.wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-lists/vocabulary-cefr-and-word-family-size/vocabulary-and-the-cefr-docx)
- [BOOKR: Adaptive English placement test](https://bookrclass.com/blog/english-placement-test/)
