import { randomUUID } from 'node:crypto';
import type Database from 'better-sqlite3';

export interface QuestionRow {
  id: string;
  lessonId: string;
  position: number;
  wordId: number;
  options: string[];
  correctIndex: number;
  selectedIndex: number | null;
  correct: boolean | null;
  answeredAt: string | null;
  answerMs: number | null;
  skipped: boolean;
  typedAnswer: string | null;
}

interface RawRow {
  id: string;
  lessonId: string;
  position: number;
  wordId: number;
  options: string;
  correctIndex: number;
  selectedIndex: number | null;
  correct: number | null;
  answeredAt: string | null;
  answerMs: number | null;
  skipped: number;
  typedAnswer: string | null;
}

function decode(row: RawRow): QuestionRow {
  return {
    ...row,
    options: JSON.parse(row.options) as string[],
    correct: row.correct === null ? null : row.correct === 1,
    skipped: row.skipped === 1,
  };
}

export interface NewQuestion {
  lessonId: string;
  position: number;
  wordId: number;
  options: string[];
  correctIndex: number;
}

export class QuestionRepository {
  constructor(private db: Database.Database) {}

  createMany(qs: NewQuestion[]): QuestionRow[] {
    const stmt = this.db.prepare(
      `INSERT INTO questions (id, lessonId, position, wordId, options, correctIndex)
       VALUES (@id, @lessonId, @position, @wordId, @options, @correctIndex)`,
    );
    const rows: QuestionRow[] = [];
    const tx = this.db.transaction(() => {
      for (const q of qs) {
        const id = randomUUID();
        stmt.run({ ...q, id, options: JSON.stringify(q.options) });
        rows.push({
          id,
          lessonId: q.lessonId,
          position: q.position,
          wordId: q.wordId,
          options: q.options,
          correctIndex: q.correctIndex,
          selectedIndex: null,
          correct: null,
          answeredAt: null,
          answerMs: null,
          skipped: false,
          typedAnswer: null,
        });
      }
    });
    tx();
    return rows;
  }

  byId(id: string): QuestionRow | undefined {
    const row = this.db.prepare<[string], RawRow>('SELECT * FROM questions WHERE id = ?').get(id);
    return row ? decode(row) : undefined;
  }

  byLessonId(lessonId: string): QuestionRow[] {
    const rows = this.db
      .prepare<[string], RawRow>('SELECT * FROM questions WHERE lessonId = ? ORDER BY position ASC')
      .all(lessonId);
    return rows.map(decode);
  }

  recordAnswer(input: {
    questionId: string;
    selectedIndex: number | null;
    correct: boolean;
    answerMs: number;
    typedAnswer?: string | null;
  }): void {
    this.db
      .prepare(
        `UPDATE questions
         SET selectedIndex = ?, correct = ?, answeredAt = ?, answerMs = ?, skipped = 0, typedAnswer = ?
         WHERE id = ?`,
      )
      .run(
        input.selectedIndex,
        input.correct ? 1 : 0,
        new Date().toISOString(),
        input.answerMs,
        input.typedAnswer ?? null,
        input.questionId,
      );
  }

  recordSkip(input: { questionId: string; answerMs: number }): void {
    this.db
      .prepare(
        `UPDATE questions
         SET selectedIndex = NULL, correct = 0, skipped = 1, answeredAt = ?, answerMs = ?
         WHERE id = ?`,
      )
      .run(new Date().toISOString(), input.answerMs, input.questionId);
  }
}
