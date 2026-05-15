import { randomUUID } from 'node:crypto';
import type Database from 'better-sqlite3';
import type { CefrLevel, LessonMode } from '../domain/schemas.js';

export type LessonState = 'in_progress' | 'completed' | 'abandoned';

export interface LessonRow {
  id: string;
  userId: string;
  level: CefrLevel;
  state: LessonState;
  mode: LessonMode;
  startedAt: string;
  completedAt: string | null;
  score: number | null;
  correlationId: string;
}

export class LessonRepository {
  constructor(private db: Database.Database) {}

  create(input: {
    userId: string;
    level: CefrLevel;
    mode: LessonMode;
    correlationId: string;
  }): LessonRow {
    const row: LessonRow = {
      id: randomUUID(),
      userId: input.userId,
      level: input.level,
      state: 'in_progress',
      mode: input.mode,
      startedAt: new Date().toISOString(),
      completedAt: null,
      score: null,
      correlationId: input.correlationId,
    };
    this.db
      .prepare(
        `INSERT INTO lessons (id, userId, level, mode, state, startedAt, completedAt, score, correlationId)
         VALUES (@id, @userId, @level, @mode, @state, @startedAt, @completedAt, @score, @correlationId)`,
      )
      .run(row);
    return row;
  }

  byId(id: string): LessonRow | undefined {
    return this.db.prepare<[string], LessonRow>('SELECT * FROM lessons WHERE id = ?').get(id);
  }

  markCompleted(id: string, score: number): void {
    this.db
      .prepare("UPDATE lessons SET state = 'completed', completedAt = ?, score = ? WHERE id = ?")
      .run(new Date().toISOString(), score, id);
  }

  countCompletedForUser(userId: string): number {
    const row = this.db
      .prepare<[string], { c: number }>("SELECT COUNT(*) AS c FROM lessons WHERE userId = ? AND state = 'completed'")
      .get(userId);
    return row?.c ?? 0;
  }

  latestCompletedForUser(userId: string): LessonRow | undefined {
    return this.db
      .prepare<[string], LessonRow>(
        "SELECT * FROM lessons WHERE userId = ? AND state = 'completed' ORDER BY completedAt DESC LIMIT 1",
      )
      .get(userId);
  }

  latestInProgressForUser(userId: string): LessonRow | undefined {
    return this.db
      .prepare<[string], LessonRow>(
        "SELECT * FROM lessons WHERE userId = ? AND state = 'in_progress' ORDER BY startedAt DESC LIMIT 1",
      )
      .get(userId);
  }
}
