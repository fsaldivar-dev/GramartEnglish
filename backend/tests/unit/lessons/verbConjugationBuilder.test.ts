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
    // No consonant doubling — the L2 mistake doesn't apply that rule either.
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

  it('includes the over-regularized distractor for irregular verbs', () => {
    const go = verbs.lookupByBase('go')!;
    const q = buildVerbQuestion(go, verbs, { level: 'A2', seed: 3 });
    expect(q.options).toContain('goed'); // over_regularized
    expect(q.options).toContain('go');   // base_form
    expect(q.options).toContain('gone'); // past_participle
    expect(q.options).toContain('went'); // correct simple_past
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
});
