import { describe, it, expect } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';

/**
 * F008 Item 3 (v1.9.0). The false-friend belt round-trips through:
 *   data/cefr/*.json → corpusLoader → SQLite → WordRepository.byBase()
 *
 * Lucía's belt entries live in A2 (high-frequency cognates) and B1
 * (slightly later acquisition); the test confirms both files are loaded
 * and the column was added by migration 0004.
 */

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

describe('WordRepository — F008 falseFriendEs', () => {
  it('hydrates falseFriendEs from a2.json corpus entries', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    loadCorpusIfEmpty(db, CORPUS);
    const words = new WordRepository(db);
    const library = words.byBase('library');
    expect(library).toBeDefined();
    expect(library?.falseFriendEs).toBeDefined();
    expect(library?.falseFriendEs).toContain('librería');
  });

  it('hydrates falseFriendEs from b1.json corpus entries', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    loadCorpusIfEmpty(db, CORPUS);
    const words = new WordRepository(db);
    const embarrassed = words.byBase('embarrassed');
    expect(embarrassed).toBeDefined();
    expect(embarrassed?.falseFriendEs).toContain('embarazada');
  });

  it('leaves falseFriendEs undefined for the majority of words', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    loadCorpusIfEmpty(db, CORPUS);
    const words = new WordRepository(db);
    // `house` is the very first A1 entry — it has no false friend.
    const house = words.byBase('house');
    expect(house).toBeDefined();
    expect(house?.falseFriendEs).toBeUndefined();
  });
});
