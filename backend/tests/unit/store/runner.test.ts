import { describe, it, expect } from 'vitest';
import Database from 'better-sqlite3';
import { loadMigrations, runMigrations, getCurrentVersion } from '../../../src/store/migrations/runner.js';

describe('migration runner', () => {
  it('loads built-in migrations in order', () => {
    const migrations = loadMigrations();
    expect(migrations.length).toBeGreaterThan(0);
    expect(migrations[0]?.version).toBe(1);
    for (let i = 1; i < migrations.length; i += 1) {
      expect(migrations[i]!.version).toBeGreaterThan(migrations[i - 1]!.version);
    }
  });

  it('applies migrations and bumps user_version', () => {
    const db = new Database(':memory:');
    expect(getCurrentVersion(db)).toBe(0);
    const applied = runMigrations(db);
    expect(applied).toBeGreaterThan(0);
    expect(getCurrentVersion(db)).toBeGreaterThanOrEqual(1);
    db.close();
  });

  it('is idempotent on re-run', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    const second = runMigrations(db);
    expect(second).toBe(0);
    db.close();
  });

  it('creates all expected tables', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    const rows = db
      .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
      .all() as { name: string }[];
    const names = rows.map((r) => r.name).sort();
    expect(names).toContain('users');
    expect(names).toContain('vocabulary_words');
    expect(names).toContain('lessons');
    expect(names).toContain('questions');
    expect(names).toContain('word_mastery');
    expect(names).toContain('placement_results');
    expect(names).toContain('rag_sources');
    expect(names).toContain('ai_generations');
    db.close();
  });
});
