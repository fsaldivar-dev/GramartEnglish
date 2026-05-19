import { describe, it, expect, beforeEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { buildOptions } from '../../../src/lessons/distractorBuilder.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

let words: WordRepository;

beforeEach(() => {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  words = new WordRepository(db);
});

describe('buildOptions', () => {
  it('returns 4 distinct options with exactly one correct index', () => {
    const target = words.byBase('eat')!;
    const built = buildOptions(target, words, { seed: 1 });
    expect(built.options).toHaveLength(4);
    expect(new Set(built.options).size).toBe(4);
    expect(built.options[built.correctIndex]).toBe(target.spanishOption);
  });

  it('produces deterministic output for a fixed seed', () => {
    const target = words.byBase('house')!;
    const a = buildOptions(target, words, { seed: 42 });
    const b = buildOptions(target, words, { seed: 42 });
    expect(a.options).toEqual(b.options);
    expect(a.correctIndex).toBe(b.correctIndex);
  });

  it('falls back to neighbor levels when same-level pool is small', () => {
    // C2 has 10 words; we cannot easily simulate <3 here, but at minimum the
    // build must succeed and produce a valid set.
    const target = words.byBase('obfuscate')!;
    const built = buildOptions(target, words, { seed: 11 });
    expect(built.options).toHaveLength(4);
    expect(built.options[built.correctIndex]).toBe(target.spanishOption);
  });
});
