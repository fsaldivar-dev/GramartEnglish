import { describe, it, expect } from 'vitest';
import Database from 'better-sqlite3';
import { getCurrentVersion, loadMigrations, runMigrations } from '../../../src/store/migrations/runner.js';

interface PragmaInfo {
  name: string;
  pk: number;
  notnull: number;
  dflt_value: string | null;
}

describe('migration 0003_lesson_modes', () => {
  it('bumps user_version to 3', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    expect(getCurrentVersion(db)).toBe(3);
    db.close();
  });

  it('adds preferredMode to users with default read_pick_meaning', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    const cols = db.pragma('table_info(users)') as PragmaInfo[];
    const pref = cols.find((c) => c.name === 'preferredMode');
    expect(pref).toBeDefined();
    expect(pref?.notnull).toBe(1);
    expect(pref?.dflt_value).toContain('read_pick_meaning');
    db.close();
  });

  it('adds mode column to lessons + typedAnswer to questions', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    const lessonCols = (db.pragma('table_info(lessons)') as PragmaInfo[]).map((c) => c.name);
    expect(lessonCols).toContain('mode');
    const qCols = (db.pragma('table_info(questions)') as PragmaInfo[]).map((c) => c.name);
    expect(qCols).toContain('typedAnswer');
    db.close();
  });

  it('rebuilds word_mastery with composite PK (userId, wordId, mode)', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    const cols = db.pragma('table_info(word_mastery)') as PragmaInfo[];
    const pkCols = cols.filter((c) => c.pk > 0).sort((a, b) => a.pk - b.pk).map((c) => c.name);
    expect(pkCols).toEqual(['userId', 'wordId', 'mode']);
    const totalSkipped = cols.find((c) => c.name === 'totalSkipped');
    expect(totalSkipped).toBeDefined();
    db.close();
  });

  it('preserves existing word_mastery rows with mode = read_pick_meaning', () => {
    const db = new Database(':memory:');
    // Run only migrations 0001 + 0002 (the pre-0003 state).
    const all = loadMigrations().filter((m) => m.version < 3);
    runMigrations(db, all);
    // Seed user + word + a mastery row.
    db.exec(`
      INSERT INTO users (id, currentLevel, createdAt, accessibilityPrefs) VALUES ('u', 'A1', '2026-01-01', '{}');
      INSERT INTO vocabulary_words (base, pos, level, canonicalDefinition, canonicalExamples, sourceTag, addedAt, spanishOption, spanishDefinition)
        VALUES ('eat','verb','A1','To eat','[]','test','2026-01-01','comer','');
      INSERT INTO word_mastery (userId, wordId, consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered)
        VALUES ('u', 1, 2, 5, 1, 0, '2026-01-02', 1);
    `);
    // Now run 0003.
    const m3 = loadMigrations().filter((m) => m.version === 3);
    runMigrations(db, m3);
    const rows = db.prepare('SELECT * FROM word_mastery').all() as Array<{ mode: string; mastered: number; totalCorrect: number }>;
    expect(rows).toHaveLength(1);
    expect(rows[0]?.mode).toBe('read_pick_meaning');
    expect(rows[0]?.mastered).toBe(1);
    expect(rows[0]?.totalCorrect).toBe(5);
    db.close();
  });
});
