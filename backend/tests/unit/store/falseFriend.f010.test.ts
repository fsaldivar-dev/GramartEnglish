import { describe, it, expect } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';

/**
 * F010 (v1.11.0). Lucía's four new A2-B1 false-friend traps —
 * `embarrassed`/`record` at A2 and `attend`/`discuss` at B1. The
 * `embarrassed` row was already present at A2 in v1.9 but with copy
 * Lucía later refined ("pregnant — el falso amigo más peligroso
 * socialmente"). The B1 mirror was kept and updated to match.
 *
 * The same round-trip guard as the F009 belt test: a missing entry,
 * a snake_case typo, or a drift in Lucía's locked copy all fail here.
 */

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

function setup(): WordRepository {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  return new WordRepository(db);
}

describe('F010 — A2 false-friend additions', () => {
  it('loads embarrassed at A2 with the refined "pregnant" copy', () => {
    const w = setup().byBase('embarrassed');
    expect(w).toBeDefined();
    expect(w?.level).toBe('A2');
    expect(w?.falseFriendEs).toContain('pregnant');
    expect(w?.falseFriendEs).toContain('socialmente');
  });

  it('loads record at A2 with the grabar-vs-recordar warning', () => {
    const w = setup().byBase('record');
    expect(w).toBeDefined();
    expect(w?.level).toBe('A2');
    expect(w?.falseFriendEs).toContain('grabar');
    expect(w?.falseFriendEs).toContain('to remember');
  });
});

describe('F010 — B1 false-friend additions', () => {
  it('loads attend at B1 with the asistir-vs-atender warning', () => {
    const w = setup().byBase('attend');
    expect(w).toBeDefined();
    expect(w?.level).toBe('B1');
    expect(w?.falseFriendEs).toContain('asistir');
    expect(w?.falseFriendEs).toContain('to serve');
  });

  it('loads discuss at B1 with the conversar-vs-pelear warning', () => {
    const w = setup().byBase('discuss');
    expect(w).toBeDefined();
    expect(w?.level).toBe('B1');
    expect(w?.falseFriendEs).toContain('conversar');
    expect(w?.falseFriendEs).toContain('to argue');
  });
});
