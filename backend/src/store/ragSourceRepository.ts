import type Database from 'better-sqlite3';
import type { CefrLevel } from '../domain/schemas.js';

export type RagKind = 'definition' | 'example' | 'usage_note';

export interface RagSourceRow {
  id: number;
  kind: RagKind;
  wordId: number | null;
  level: CefrLevel | null;
  content: string;
  embedding: Float32Array | null;
  embeddingModel: string;
  schemaVersion: number;
  addedAt: string;
}

interface RawRow {
  id: number;
  kind: RagKind;
  wordId: number | null;
  level: CefrLevel | null;
  content: string;
  embedding: Buffer | null;
  embeddingModel: string;
  schemaVersion: number;
  addedAt: string;
}

function decode(row: RawRow): RagSourceRow {
  return {
    ...row,
    embedding: row.embedding ? new Float32Array(row.embedding.buffer, row.embedding.byteOffset, row.embedding.byteLength / 4) : null,
  };
}

function encode(embedding: number[] | null): Buffer | null {
  if (!embedding) return null;
  const arr = new Float32Array(embedding);
  return Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength);
}

export interface NewRagSource {
  kind: RagKind;
  wordId: number | null;
  level: CefrLevel | null;
  content: string;
  embedding: number[] | null;
  embeddingModel: string;
  schemaVersion: number;
}

export class RagSourceRepository {
  constructor(private db: Database.Database) {}

  insertMany(rows: NewRagSource[]): number[] {
    const stmt = this.db.prepare(
      `INSERT INTO rag_sources (kind, wordId, level, content, embedding, embeddingModel, schemaVersion, addedAt)
       VALUES (@kind, @wordId, @level, @content, @embedding, @embeddingModel, @schemaVersion, @addedAt)`,
    );
    const ids: number[] = [];
    const tx = this.db.transaction(() => {
      const now = new Date().toISOString();
      for (const r of rows) {
        const info = stmt.run({
          ...r,
          embedding: encode(r.embedding),
          addedAt: now,
        });
        ids.push(Number(info.lastInsertRowid));
      }
    });
    tx();
    return ids;
  }

  countBySchema(schemaVersion: number): number {
    const row = this.db
      .prepare<[number], { c: number }>('SELECT COUNT(*) AS c FROM rag_sources WHERE schemaVersion = ?')
      .get(schemaVersion);
    return row?.c ?? 0;
  }

  bySchema(schemaVersion: number): RagSourceRow[] {
    const rows = this.db
      .prepare<[number], RawRow>('SELECT * FROM rag_sources WHERE schemaVersion = ?')
      .all(schemaVersion);
    return rows.map(decode);
  }

  byIds(ids: readonly number[]): RagSourceRow[] {
    if (ids.length === 0) return [];
    const placeholders = ids.map(() => '?').join(',');
    const rows = this.db
      .prepare<number[], RawRow>(`SELECT * FROM rag_sources WHERE id IN (${placeholders})`)
      .all(...ids);
    return rows.map(decode);
  }

  byWordId(wordId: number): RagSourceRow[] {
    const rows = this.db
      .prepare<[number], RawRow>('SELECT * FROM rag_sources WHERE wordId = ?')
      .all(wordId);
    return rows.map(decode);
  }

  truncateAll(): void {
    this.db.exec('DELETE FROM rag_sources');
  }
}
