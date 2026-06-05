import { describe, it, expect, beforeAll } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { loadVerbCorpus, type VerbRepository } from '../../../src/store/verbRepository.js';
import {
  buildVerbQuestion,
  overRegularize,
  isAmbiguousForPickForm,
} from '../../../src/lessons/verbConjugationBuilder.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

let verbs: VerbRepository;

beforeAll(() => {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  verbs = loadVerbCorpus(CORPUS, new WordRepository(db));
});

describe('overRegularize', () => {
  it('appends "ed" to every base — no spelling-rule cleanups', () => {
    expect(overRegularize('go')).toBe('goed');
    expect(overRegularize('eat')).toBe('eated');
    // v1.6.0 patch (Polish B): no consonant doubling — comment used to say
    // "runned" but code produces "runed". Locked: A2 learners haven't seen
    // the CVC doubling rule, so "runed" is the believable wrong form.
    expect(overRegularize('run')).toBe('runed');
    // Regular verbs collide deliberately; collision fallback handles it.
    expect(overRegularize('travel')).toBe('traveled');
    // Trailing-e is NOT deduped — the over-regularized form is the naïve mistake.
    expect(overRegularize('bake')).toBe('bakeed');
  });
});

describe('buildVerbQuestion', () => {
  it('returns exactly 4 distinct options with correctIndex pointing at simple_past', () => {
    const go = verbs.lookupByBase('go')!;
    const q = buildVerbQuestion(go, verbs, { level: 'A2', seed: 1 });
    expect(q.options).toHaveLength(4);
    expect(new Set(q.options).size).toBe(4);
    expect(q.options[q.correctIndex]).toBe('went');
  });

  it('prompt uses the Spanish infinitive with markdown emphasis', () => {
    const go = verbs.lookupByBase('go')!;
    const q = buildVerbQuestion(go, verbs, { level: 'A2', seed: 1 });
    expect(q.prompt).toBe('Pasado simple de **ir**');
  });

  it('emits verbBase and targetTense for the client renderer', () => {
    const eat = verbs.lookupByBase('eat')!;
    const q = buildVerbQuestion(eat, verbs, { level: 'A2', seed: 2 });
    expect(q.verbBase).toBe('eat');
    expect(q.targetTense).toBe('simple_past');
  });

  // F007 (v1.8.0): the over-regularized form is NO LONGER a visible
  // distractor — see verbConjugationBuilder doc header. The recipe now
  // ships base + past_participle + 1 random-other-past-at-level as the
  // three distractors alongside the correct simple_past.
  it('builds the v1.8.0 recipe: base + past_participle + 1 random valid past', () => {
    const go = verbs.lookupByBase('go')!;
    const q = buildVerbQuestion(go, verbs, { level: 'A2', seed: 3 });
    expect(q.options).toContain('go');   // base_form
    expect(q.options).toContain('gone'); // past_participle
    expect(q.options).toContain('went'); // correct simple_past
    // The 4th option must be SOME other A2 verb's simple_past.
    const filler = q.options.filter((o) => o !== 'go' && o !== 'gone' && o !== 'went');
    expect(filler).toHaveLength(1);
    const isOtherPast = verbs
      .atLevel('A2')
      .some((v) => v.simplePast === filler[0] && v.base !== 'go');
    expect(isOtherPast, `${filler[0]} must be some other A2 verb's simple_past`).toBe(true);
  });

  // F007 (v1.8.0) regression guard. We saw a real injury pattern where
  // showing `goed`/`runed`/`eated` as MCQ options taught the L1 error by
  // exposing the wrong spelling on every reading. The over-regularized
  // form must NEVER appear as a visible option for an irregular verb.
  it('NEVER surfaces the over-regularized form as an MCQ option (irregular verbs)', () => {
    const irregulars = ['go', 'eat', 'see', 'run', 'come', 'know', 'take', 'give'];
    for (const base of irregulars) {
      const verb = verbs.lookupByBase(base);
      if (!verb) continue; // not all bases present at every level
      for (let seed = 0; seed < 20; seed += 1) {
        const q = buildVerbQuestion(verb, verbs, { level: verb.level, seed });
        const over = `${verb.base}ed`;
        // The over-regularized form being equal to the canonical past
        // happens only for regular verbs; for those it's fine because
        // it's the right answer. For irregular verbs it must be absent.
        if (over === verb.simplePast) continue;
        expect(
          q.options.includes(over),
          `seed=${seed} verb=${verb.base}: options ${JSON.stringify(q.options)} must NOT contain over-regularized "${over}"`,
        ).toBe(false);
      }
    }
  });

  it('falls back to other-verb past forms when distractors collide with the answer (regular verbs)', () => {
    const traveled = verbs.lookupByBase('travel')!;
    // For "travel", simple_past === past_participle === over_regularized === "traveled".
    // Only base ("travel") survives; the builder must top up with 2 other-verb past forms.
    const q = buildVerbQuestion(traveled, verbs, { level: 'A2', seed: 7 });
    expect(q.options).toHaveLength(4);
    expect(new Set(q.options).size).toBe(4);
    expect(q.options).toContain('traveled');
    expect(q.options).toContain('travel');
    // The other two must come from the same-level past-form pool.
    const filler = q.options.filter((o) => o !== 'traveled' && o !== 'travel');
    expect(filler).toHaveLength(2);
    for (const f of filler) {
      // Each filler is some other A2 verb's simple_past.
      const matches = verbs.atLevel('A2').some((v) => v.simplePast === f && v.base !== 'travel');
      expect(matches, `${f} should match an A2 verb's simple_past`).toBe(true);
    }
  });

  it('is deterministic for a fixed seed', () => {
    const see = verbs.lookupByBase('see')!;
    const a = buildVerbQuestion(see, verbs, { level: 'A2', seed: 42 });
    const b = buildVerbQuestion(see, verbs, { level: 'A2', seed: 42 });
    expect(a.options).toEqual(b.options);
    expect(a.correctIndex).toBe(b.correctIndex);
  });
});

describe('verbs corpus invariants', () => {
  it('loads ≥ 10 verbs at A2 and ≥ 10 at B1 (LESSON_SIZE floor)', () => {
    expect(verbs.countByLevel('A2')).toBeGreaterThanOrEqual(10);
    expect(verbs.countByLevel('B1')).toBeGreaterThanOrEqual(10);
  });

  it('every verb resolves to a vocabulary_words row (wordId > 0)', () => {
    for (const v of verbs.atLevel('A2')) expect(v.wordId).toBeGreaterThan(0);
    for (const v of verbs.atLevel('B1')) expect(v.wordId).toBeGreaterThan(0);
  });

  // v1.6.0 patch (Blocker 2): every verb in the production corpus must
  // ship a Spanish example sentence with a `___` slot and an English
  // translation. The slot is what disambiguates preterite/imperfect.
  it('every verb provides example_es with the `___` slot and example_en', () => {
    for (const level of ['A2', 'B1'] as const) {
      for (const v of verbs.atLevel(level)) {
        expect(v.exampleEs, `${v.base} missing exampleEs`).toBeTruthy();
        expect(v.exampleEs).toContain('___');
        expect(v.exampleEn, `${v.base} missing exampleEn`).toBeTruthy();
        expect(v.exampleEn.length).toBeGreaterThan(0);
      }
    }
  });
});

// v1.6.0 patch (Blocker 1): English verbs where the base spells identically
// to the simple past (read/read, cut/cut, put/put, hit/hit, let/let,
// set/set, cost/cost, hurt/hurt) make `conjugate_pick_form` unanswerable
// as MCQ — the correct option and the "base form" distractor are the same
// string. They must be excluded from selection.
describe('isAmbiguousForPickForm', () => {
  it('flags verbs whose base equals simple_past (case-insensitive)', () => {
    expect(isAmbiguousForPickForm({ base: 'read', simplePast: 'read' })).toBe(true);
    expect(isAmbiguousForPickForm({ base: 'cut', simplePast: 'cut' })).toBe(true);
    expect(isAmbiguousForPickForm({ base: 'put', simplePast: 'put' })).toBe(true);
    expect(isAmbiguousForPickForm({ base: 'Hit', simplePast: 'hit' })).toBe(true);
  });

  it('does NOT flag verbs where the past differs from the base', () => {
    expect(isAmbiguousForPickForm({ base: 'go', simplePast: 'went' })).toBe(false);
    expect(isAmbiguousForPickForm({ base: 'eat', simplePast: 'ate' })).toBe(false);
    expect(isAmbiguousForPickForm({ base: 'travel', simplePast: 'traveled' })).toBe(false);
  });

  it('excludes verbs whose base equals simple_past from conjugate_pick_form (production corpus)', () => {
    // The production corpus must not ship any base==simple_past verb (we
    // deleted verb_read in v1.6.0 patch; future additions are guarded by
    // this test).
    for (const v of verbs.atLevel('A2')) {
      expect(isAmbiguousForPickForm(v), `${v.base}: base spells identically to simple_past`).toBe(false);
    }
    for (const v of verbs.atLevel('B1')) {
      expect(isAmbiguousForPickForm(v), `${v.base}: base spells identically to simple_past`).toBe(false);
    }
  });
});

// v1.6.0 patch (Blocker 2): the builder must surface example_es and
// example_en on the BuiltConjugationQuestion so the client can render
// the disambiguating Spanish sentence beneath the prompt header.
describe('buildVerbQuestion — example sentences', () => {
  it('includes exampleEs with a `___` slot and exampleEn with the verb conjugated', () => {
    const eat = verbs.lookupByBase('eat')!;
    const q = buildVerbQuestion(eat, verbs, { level: 'A2', seed: 11 });
    expect(q.exampleEs).toBeTruthy();
    expect(q.exampleEs).toContain('___');
    expect(q.exampleEn).toBeTruthy();
    // The English example uses the simple past, not the base form.
    expect(q.exampleEn.toLowerCase()).toContain('ate');
  });
});
