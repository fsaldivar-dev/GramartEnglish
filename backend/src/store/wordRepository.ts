import type Database from 'better-sqlite3';
import type { CefrLevel } from '../domain/schemas.js';

export interface VocabularyWordRow {
  id: number;
  base: string;
  pos: string;
  level: CefrLevel;
  canonicalDefinition: string;
  canonicalExamples: string[];
  sourceTag: string;
  addedAt: string;
  spanishOption: string;
  spanishDefinition: string;
  /** F008 Item 3 (v1.9.0). Optional Spanish warning surfaced when the word
   *  has a high-frequency Spanish look-alike with a different meaning (e.g.
   *  "realize" → "OJO: no es 'realizar' (do/carry out)"). Populated only for
   *  the ~10-12 belt entries Lucía curated; absent for everything else. */
  falseFriendEs?: string;
}

interface RawRow {
  id: number;
  base: string;
  pos: string;
  level: CefrLevel;
  canonicalDefinition: string;
  canonicalExamples: string;
  sourceTag: string;
  addedAt: string;
  spanishOption: string;
  spanishDefinition: string;
  falseFriendEs: string | null;
}

function decode(row: RawRow): VocabularyWordRow {
  const { falseFriendEs, ...rest } = row;
  return {
    ...rest,
    canonicalExamples: JSON.parse(row.canonicalExamples) as string[],
    ...(falseFriendEs ? { falseFriendEs } : {}),
  };
}

export class WordRepository {
  constructor(private db: Database.Database) {}

  countByLevel(level: CefrLevel): number {
    const row = this.db
      .prepare<[CefrLevel], { c: number }>('SELECT COUNT(*) AS c FROM vocabulary_words WHERE level = ?')
      .get(level);
    return row?.c ?? 0;
  }

  byLevel(level: CefrLevel): VocabularyWordRow[] {
    const rows = this.db
      .prepare<[CefrLevel], RawRow>('SELECT * FROM vocabulary_words WHERE level = ?')
      .all(level);
    return rows.map(decode);
  }

  byId(id: number): VocabularyWordRow | undefined {
    const row = this.db.prepare<[number], RawRow>('SELECT * FROM vocabulary_words WHERE id = ?').get(id);
    return row ? decode(row) : undefined;
  }

  byIds(ids: readonly number[]): VocabularyWordRow[] {
    if (ids.length === 0) return [];
    const placeholders = ids.map(() => '?').join(',');
    const rows = this.db
      .prepare<number[], RawRow>(`SELECT * FROM vocabulary_words WHERE id IN (${placeholders})`)
      .all(...ids);
    return rows.map(decode);
  }

  byBase(base: string): VocabularyWordRow | undefined {
    const row = this.db.prepare<[string], RawRow>('SELECT * FROM vocabulary_words WHERE base = ?').get(base);
    return row ? decode(row) : undefined;
  }

  /** Random sample of `n` words at a given level. */
  randomByLevel(level: CefrLevel, n: number): VocabularyWordRow[] {
    const rows = this.db
      .prepare<[CefrLevel, number], RawRow>(
        'SELECT * FROM vocabulary_words WHERE level = ? ORDER BY random() LIMIT ?',
      )
      .all(level, n);
    return rows.map(decode);
  }

  countAll(): number {
    const row = this.db.prepare<[], { c: number }>('SELECT COUNT(*) AS c FROM vocabulary_words').get();
    return row?.c ?? 0;
  }

  insertMany(words: Omit<VocabularyWordRow, 'id'>[]): void {
    const stmt = this.db.prepare(
      // F008 Item 3 (v1.9.0): falseFriendEs column (nullable, additive).
      `INSERT INTO vocabulary_words (base, pos, level, canonicalDefinition, canonicalExamples, sourceTag, addedAt, spanishOption, spanishDefinition, falseFriendEs)
       VALUES (@base, @pos, @level, @canonicalDefinition, @canonicalExamples, @sourceTag, @addedAt, @spanishOption, @spanishDefinition, @falseFriendEs)
       ON CONFLICT(base) DO NOTHING`,
    );
    const tx = this.db.transaction((rows: typeof words) => {
      for (const w of rows) {
        stmt.run({
          ...w,
          canonicalExamples: JSON.stringify(w.canonicalExamples),
          falseFriendEs: w.falseFriendEs ?? null,
        });
      }
    });
    tx(words);
  }
}
