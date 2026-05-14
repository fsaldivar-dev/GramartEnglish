import { randomUUID } from 'node:crypto';
import type Database from 'better-sqlite3';
import type { CefrLevel, LessonMode } from '../domain/schemas.js';

export interface UserRow {
  id: string;
  currentLevel: CefrLevel;
  createdAt: string;
  accessibilityPrefs: Record<string, unknown>;
  preferredMode: LessonMode;
}

interface RawRow {
  id: string;
  currentLevel: CefrLevel;
  createdAt: string;
  accessibilityPrefs: string;
  preferredMode: LessonMode;
}

function decode(row: RawRow): UserRow {
  return {
    ...row,
    accessibilityPrefs: JSON.parse(row.accessibilityPrefs) as Record<string, unknown>,
  };
}

export class UserRepository {
  constructor(private db: Database.Database) {}

  /** Returns the singleton user, creating one with default level A2 if absent. */
  ensureSingleton(defaultLevel: CefrLevel = 'A2'): UserRow {
    const existing = this.db.prepare<[], RawRow>('SELECT * FROM users LIMIT 1').get();
    if (existing) return decode(existing);
    const user: UserRow = {
      id: randomUUID(),
      currentLevel: defaultLevel,
      createdAt: new Date().toISOString(),
      accessibilityPrefs: {},
      preferredMode: 'read_pick_meaning',
    };
    this.db
      .prepare(
        'INSERT INTO users (id, currentLevel, createdAt, accessibilityPrefs, preferredMode) VALUES (@id, @currentLevel, @createdAt, @prefs, @preferredMode)',
      )
      .run({ ...user, prefs: JSON.stringify(user.accessibilityPrefs) });
    return user;
  }

  setLevel(userId: string, level: CefrLevel): void {
    this.db.prepare('UPDATE users SET currentLevel = ? WHERE id = ?').run(level, userId);
  }

  setAccessibilityPrefs(userId: string, prefs: Record<string, unknown>): void {
    this.db
      .prepare('UPDATE users SET accessibilityPrefs = ? WHERE id = ?')
      .run(JSON.stringify(prefs), userId);
  }

  setPreferredMode(userId: string, mode: LessonMode): void {
    this.db.prepare('UPDATE users SET preferredMode = ? WHERE id = ?').run(mode, userId);
  }
}
