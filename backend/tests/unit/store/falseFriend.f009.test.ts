import { describe, it, expect } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';

/**
 * F009 (v1.10.0). The five-panel review locked these six new belt entries
 * (A1 ×4, B1 ×2) and the A2 `success` copy fix. Lucía's pedagogical
 * rationale lives in `specs/009-falsefriend-bias-darkmode-assets/spec.md`.
 *
 * Pinning the round-trip through the loader catches three regressions at
 * once: a missing entry, a snake_case typo (`false_friend_es`), and a
 * stray English gloss in the copy that v1.9.0 left in `success`.
 */

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

function setup(): WordRepository {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  return new WordRepository(db);
}

describe('F009 — A1 false-friend additions', () => {
  it.each([
    ['large', 'A1', 'largo'],
    ['rope', 'A1', 'ropa'],
    ['once', 'A1', 'eleven'],
    ['soap', 'A1', 'sopa'],
  ] as const)('loads %s at %s with the trap-word in the warning', (base, level, trap) => {
    const w = setup().byBase(base);
    expect(w, `${base} should be in the corpus`).toBeDefined();
    expect(w?.level).toBe(level);
    expect(w?.falseFriendEs, `${base} should carry a falseFriendEs warning`).toBeDefined();
    expect(w?.falseFriendEs).toContain(trap);
  });
});

describe('F009 — B1 false-friend additions', () => {
  it('loads constipated at B1 with the resfriado warning', () => {
    const w = setup().byBase('constipated');
    expect(w).toBeDefined();
    expect(w?.level).toBe('B1');
    expect(w?.falseFriendEs).toContain('resfriado');
  });

  it('loads molest at B1 with the abuse-vs-bother warning', () => {
    const w = setup().byBase('molest');
    expect(w).toBeDefined();
    expect(w?.level).toBe('B1');
    expect(w?.falseFriendEs).toContain('abusar');
    expect(w?.falseFriendEs).toContain('to bother');
  });
});

describe('F009 — A2 success copy fix', () => {
  it('uses Spanish gloss "(un evento o noticia)" rather than English "(event)"', () => {
    const w = setup().byBase('success');
    expect(w).toBeDefined();
    expect(w?.falseFriendEs).toContain('un evento o noticia');
    // The v1.9.0 ship had a stray "(event)" — regression-pin.
    expect(w?.falseFriendEs).not.toMatch(/\(event\)/);
  });
});
