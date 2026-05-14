import { describe, it, expect } from 'vitest';
import Database from 'better-sqlite3';
import { getCurrentVersion, runMigrations, rollbackTo } from '../../../src/store/migrations/runner.js';

interface PragmaInfo {
  name: string;
  pk: number;
}

describe('migration 0003 rollback', () => {
  it('drops non-read mastery rows and restores v2 PK on word_mastery', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    expect(getCurrentVersion(db)).toBe(3);

    // Seed two mastery rows: one in read mode, one in listen mode.
    db.exec(`
      INSERT INTO users (id, currentLevel, createdAt, accessibilityPrefs) VALUES ('u', 'A1', '2026-01-01', '{}');
      INSERT INTO vocabulary_words (base, pos, level, canonicalDefinition, canonicalExamples, sourceTag, addedAt, spanishOption, spanishDefinition)
        VALUES ('eat','verb','A1','To eat','[]','test','2026-01-01','comer','');
      INSERT INTO word_mastery (userId, wordId, mode, consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered)
        VALUES ('u', 1, 'read_pick_meaning', 2, 5, 0, 0, '2026-01-02', 1),
               ('u', 1, 'listen_pick_word',  1, 1, 0, 0, '2026-01-02', 0);
    `);

    rollbackTo(db, 2);
    expect(getCurrentVersion(db)).toBe(2);

    // word_mastery PK is now (userId, wordId).
    const cols = db.pragma('table_info(word_mastery)') as PragmaInfo[];
    const pkCols = cols.filter((c) => c.pk > 0).sort((a, b) => a.pk - b.pk).map((c) => c.name);
    expect(pkCols).toEqual(['userId', 'wordId']);

    // Only the read row survived.
    const rows = db.prepare('SELECT * FROM word_mastery').all() as Array<{ totalCorrect: number }>;
    expect(rows).toHaveLength(1);
    expect(rows[0]?.totalCorrect).toBe(5);

    // Added columns are gone.
    const lessonCols = (db.pragma('table_info(lessons)') as PragmaInfo[]).map((c) => c.name);
    expect(lessonCols).not.toContain('mode');
    const userCols = (db.pragma('table_info(users)') as PragmaInfo[]).map((c) => c.name);
    expect(userCols).not.toContain('preferredMode');
    const qCols = (db.pragma('table_info(questions)') as PragmaInfo[]).map((c) => c.name);
    expect(qCols).not.toContain('typedAnswer');

    db.close();
  });
});
