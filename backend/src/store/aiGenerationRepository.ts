import { randomUUID } from 'node:crypto';
import type Database from 'better-sqlite3';
import type { CefrLevel } from '../domain/schemas.js';

export type AiKind = 'examples' | 'contextual_definition';

export interface AiGenerationRow {
  id: string;
  correlationId: string;
  wordId: number | null;
  kind: AiKind;
  targetLevel: CefrLevel;
  model: string;
  promptHash: string;
  ragSourceIds: number[];
  output: string;
  firstTokenMs: number;
  totalMs: number;
  createdAt: string;
}

export interface NewAiGeneration {
  correlationId: string;
  wordId: number | null;
  kind: AiKind;
  targetLevel: CefrLevel;
  model: string;
  promptHash: string;
  ragSourceIds: number[];
  output: string;
  firstTokenMs: number;
  totalMs: number;
}

export class AiGenerationRepository {
  constructor(private db: Database.Database) {}

  insert(input: NewAiGeneration): AiGenerationRow {
    const row: AiGenerationRow = {
      ...input,
      id: randomUUID(),
      createdAt: new Date().toISOString(),
    };
    this.db
      .prepare(
        `INSERT INTO ai_generations
         (id, correlationId, wordId, kind, targetLevel, model, promptHash, ragSourceIds, output, firstTokenMs, totalMs, createdAt)
         VALUES (@id, @correlationId, @wordId, @kind, @targetLevel, @model, @promptHash, @ragSourceIds, @output, @firstTokenMs, @totalMs, @createdAt)`,
      )
      .run({ ...row, ragSourceIds: JSON.stringify(row.ragSourceIds) });
    return row;
  }

  byCorrelationId(correlationId: string): AiGenerationRow[] {
    interface Raw extends Omit<AiGenerationRow, 'ragSourceIds'> {
      ragSourceIds: string;
    }
    const rows = this.db
      .prepare<[string], Raw>('SELECT * FROM ai_generations WHERE correlationId = ?')
      .all(correlationId);
    return rows.map((r) => ({ ...r, ragSourceIds: JSON.parse(r.ragSourceIds) as number[] }));
  }
}
