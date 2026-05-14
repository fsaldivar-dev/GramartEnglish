import type Database from 'better-sqlite3';
import type { LessonMode } from '../domain/schemas.js';

export type AnswerOutcome = 'correct' | 'incorrect' | 'skipped';

export interface WordMasteryRow {
  userId: string;
  wordId: number;
  mode: LessonMode;
  consecutiveCorrect: number;
  totalCorrect: number;
  totalIncorrect: number;
  totalSkipped: number;
  lastSeenAt: string;
  mastered: boolean;
}

interface RawRow {
  userId: string;
  wordId: number;
  mode: LessonMode;
  consecutiveCorrect: number;
  totalCorrect: number;
  totalIncorrect: number;
  totalSkipped: number;
  lastSeenAt: string;
  mastered: number;
}

function decode(row: RawRow): WordMasteryRow {
  return { ...row, mastered: row.mastered === 1 };
}

const DEFAULT_MODE: LessonMode = 'read_pick_meaning';

export class MasteryRepository {
  constructor(private db: Database.Database) {}

  byUserAndWord(userId: string, wordId: number, mode: LessonMode = DEFAULT_MODE): WordMasteryRow | undefined {
    const row = this.db
      .prepare<[string, number, LessonMode], RawRow>(
        'SELECT * FROM word_mastery WHERE userId = ? AND wordId = ? AND mode = ?',
      )
      .get(userId, wordId, mode);
    return row ? decode(row) : undefined;
  }

  /** Returns all mastery rows for a user. If `mode` is given, filtered by it. */
  allForUser(userId: string, mode?: LessonMode): WordMasteryRow[] {
    const rows = mode
      ? this.db
          .prepare<[string, LessonMode], RawRow>('SELECT * FROM word_mastery WHERE userId = ? AND mode = ?')
          .all(userId, mode)
      : this.db
          .prepare<[string], RawRow>('SELECT * FROM word_mastery WHERE userId = ?')
          .all(userId);
    return rows.map(decode);
  }

  countToReview(userId: string, mode?: LessonMode): number {
    if (mode) {
      const row = this.db
        .prepare<[string, LessonMode], { c: number }>(
          'SELECT COUNT(*) AS c FROM word_mastery WHERE userId = ? AND mode = ? AND mastered = 0',
        )
        .get(userId, mode);
      return row?.c ?? 0;
    }
    const row = this.db
      .prepare<[string], { c: number }>(
        'SELECT COUNT(*) AS c FROM word_mastery WHERE userId = ? AND mastered = 0',
      )
      .get(userId);
    return row?.c ?? 0;
  }

  countMastered(userId: string, mode?: LessonMode): number {
    if (mode) {
      const row = this.db
        .prepare<[string, LessonMode], { c: number }>(
          'SELECT COUNT(*) AS c FROM word_mastery WHERE userId = ? AND mastered = 1 AND mode = ?',
        )
        .get(userId, mode);
      return row?.c ?? 0;
    }
    const row = this.db
      .prepare<[string], { c: number }>('SELECT COUNT(*) AS c FROM word_mastery WHERE userId = ? AND mastered = 1')
      .get(userId);
    return row?.c ?? 0;
  }

  /** Latest `lastSeenAt` for any row of (userId, mode). Null if no rows. */
  lastSeenForMode(userId: string, mode: LessonMode): string | null {
    const row = this.db
      .prepare<[string, LessonMode], { ls: string | null }>(
        'SELECT MAX(lastSeenAt) AS ls FROM word_mastery WHERE userId = ? AND mode = ?',
      )
      .get(userId, mode);
    return row?.ls ?? null;
  }

  /** Apply an answer event for (userId, wordId, mode). Returns the updated row. */
  apply(input: { userId: string; wordId: number; mode: LessonMode; outcome: AnswerOutcome }): WordMasteryRow {
    const existing = this.byUserAndWord(input.userId, input.wordId, input.mode);
    const now = new Date().toISOString();
    const correct = input.outcome === 'correct';
    const incorrect = input.outcome === 'incorrect';
    const skipped = input.outcome === 'skipped';

    if (!existing) {
      const row: WordMasteryRow = {
        userId: input.userId,
        wordId: input.wordId,
        mode: input.mode,
        consecutiveCorrect: correct ? 1 : 0,
        totalCorrect: correct ? 1 : 0,
        totalIncorrect: incorrect ? 1 : 0,
        totalSkipped: skipped ? 1 : 0,
        lastSeenAt: now,
        mastered: false,
      };
      this.db
        .prepare(
          `INSERT INTO word_mastery
            (userId, wordId, mode, consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered)
           VALUES (@userId, @wordId, @mode, @consecutiveCorrect, @totalCorrect, @totalIncorrect, @totalSkipped, @lastSeenAt, @mastered)`,
        )
        .run({ ...row, mastered: row.mastered ? 1 : 0 });
      return row;
    }

    const consecutiveCorrect = correct ? existing.consecutiveCorrect + 1 : 0;
    const updated: WordMasteryRow = {
      ...existing,
      consecutiveCorrect,
      totalCorrect: existing.totalCorrect + (correct ? 1 : 0),
      totalIncorrect: existing.totalIncorrect + (incorrect ? 1 : 0),
      totalSkipped: existing.totalSkipped + (skipped ? 1 : 0),
      lastSeenAt: now,
      mastered: consecutiveCorrect >= 2,
    };
    this.db
      .prepare(
        `UPDATE word_mastery
         SET consecutiveCorrect = ?, totalCorrect = ?, totalIncorrect = ?, totalSkipped = ?, lastSeenAt = ?, mastered = ?
         WHERE userId = ? AND wordId = ? AND mode = ?`,
      )
      .run(
        updated.consecutiveCorrect,
        updated.totalCorrect,
        updated.totalIncorrect,
        updated.totalSkipped,
        updated.lastSeenAt,
        updated.mastered ? 1 : 0,
        updated.userId,
        updated.wordId,
        updated.mode,
      );
    return updated;
  }
}
