# Proposal — Feature 003: Lesson modes (listening + writing)

**Status**: Drafted. Awaiting decision on which mode ships first.
**Why**: The MVP only exercises *receptive reading* (see English word, pick Spanish meaning). That's recognition of vocabulary, but not the same as listening comprehension or productive recall. A real learner needs multiple modes to develop balanced skill.

## The skill matrix

| Mode | Stimulus | Response | Skill trained | Difficulty |
|------|----------|----------|---------------|------------|
| **Read (current)** | EN word + context | Pick ES meaning | Reading + receptive vocab | 🟢 |
| **L1** | Audio of EN word | Pick ES meaning | Listening + receptive vocab | 🟢 |
| **L2** | Audio of EN word | Pick EN word from 4 | Listening only | 🟢 |
| **L3** | Audio of EN word | Type the word | Listening + spelling (productive) | 🔴 |
| **W1** | EN word with gaps (`h_us_`) | Fill in letters | Assisted recall | 🟡 |
| **W2** | ES word | Pick EN word from 4 | Active recall (passive→productive) | 🟡 |
| **W3** | ES word | Type EN word | Full productive recall | 🔴 |

## Recommended phase order

The order minimises engineering work AND maps to a sane pedagogy ladder.

| Phase | Mode | Why this position |
|-------|------|-------------------|
| **A — first** | L2 (listen → pick EN written) | Reuses TTS, multi-choice, corpus, mastery 100%. Closes the "I can read but not hear it" gap most learners have. |
| B | W2 (ES → pick EN) | Mirror of current quiz. Active recall. Same data, swapped roles. |
| C | W3 (ES → type EN) | Introduces a typed-input UI. First "productive" mode. |
| D | L3 (listen → type) | Combines L2 + W3 mechanics. |
| E | W1 (autocomplete gaps) | Variant on W3 with letter scaffolding. |

Each phase ~½–1 day of work after the first one (which establishes shared infra).

## Shared infrastructure to build in Phase A

- **`LessonMode` enum** in `LessonKit`: `.readPickMeaning | .listenPickWord | …`
- **Backend `POST /v1/lessons`** accepts `mode: LessonMode`
- **`LessonQuestion`** model gains optional fields:
  - `audioOnly: Bool` (hide the word text)
  - `expectedInput: "choice" | "text"` (whether to render a text field vs option cards)
- **Mode selector on Home**: a segmented control or pill row showing the modes the user has unlocked
- **Mastery is per-(word, mode)** — knowing "weather=clima" by reading ≠ knowing it by ear

## What changes per mode (concrete shape)

### Phase A — L2 (listening → pick English word)

- `LessonQuestionView`:
  - Hides the big word; shows a large 🔊 button instead
  - 4 options are English words (`weather / favorite / village / kitchen`), not Spanish
  - Auto-plays on appear; `S` repeats; speed ×0.75 on `⌘S` (helpful for fast speech)
- Distractors: same-level English words from `vocabulary_words.base`
- Correct answer: `target.base`

### Phase B — W2 (ES → pick EN)

- Shows the **Spanish text** as the prompt
- 4 options are English words (`weather` etc.)
- Pure inverse of current mode; auto-speaks correct answer on reveal

### Phase C — W3 (ES → type EN)

- Shows Spanish prompt
- Single text field, monospaced, with autocorrect/autocapitalize off
- Accepts: case-insensitive exact match OR known inflection (re-use `containsWord` morphology rules from output validator)
- Hint button: reveals first letter
- Skip button: same as today

### Phase D — L3 (listen → type)

- Combines C's text field with L2's audio prompt
- Spelling correction tolerates minor typos within Levenshtein distance 1 (so "wether" still counts as `weather`, with a note "casi — la palabra es **weather**")

### Phase E — W1 (autocomplete gaps)

- Shows EN word with ~30% of letters replaced by underscores: `e_ph_meral`
- User types in the gaps; on submit checks the full word
- Probably ship as a variant of W3 rather than a standalone mode

## Mastery split

A user who has "weather" mastered in *read mode* doesn't necessarily know it by ear. We split mastery per-mode:

```sql
ALTER TABLE word_mastery ADD COLUMN mode TEXT NOT NULL DEFAULT 'read';
-- composite PK becomes (userId, wordId, mode)
```

The Home "Dominadas: N" can show per-mode breakdown OR sum across modes (TBD with UX).

## Data work needed for Phase A

**None.** L2 uses the same 300 curated words. The audio comes from macOS TTS (already built).

## Data work needed for Phase E (autocomplete)

The corpus needs `letterPattern` precomputed per word (e.g., for "weather" → `w__th_r` keeping the harder consonants). Could be done at corpus load time.

## Verb conjugation (Feature 004, separate)

Conjugation is a different beast and deserves its own feature:

- New entity: `verb` with `base`, `pastSimple`, `pastParticiple`, `gerund`, `thirdPerson`
- Forms for ~80 irregular verbs in MVP, ~20 regular (rule-based for the rest)
- New screens: tense picker, person picker
- New mode: `pickConjugatedForm` and `typeConjugatedForm`

Estimated 3× the work of Feature 003. Defer until F003 is stable.

## Concrete decision needed

Pick the entry phase for Feature 003:

- ✅ **Recommended: Phase A (L2 — listen → pick English written)**
- Alternative: Phase B (W2 — ES → pick EN)
- Alternative: Phase C (W3 — ES → type EN, productive)

Once the entry phase is chosen, run `/speckit-specify` for Feature 003 with that as US1 and the rest as later user stories.

## References

- Carries forward the bilingual MVP architecture: word entry has `base`, `spanishOption`, `canonicalDefinition`, `canonicalExamples` — all reusable.
- Mastery model already separates `consecutiveCorrect`, `totalSkipped` — only needs a `mode` axis.
- TTS infrastructure is fully built in `SpeechService.swift`.
