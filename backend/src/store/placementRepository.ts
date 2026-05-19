import { randomUUID } from 'node:crypto';
import type Database from 'better-sqlite3';
import type { CefrLevel } from '../domain/schemas.js';

export interface PerLevelScore {
  attempted: number;
  correct: number;
}

export interface PlacementResultRow {
  id: string;
  userId: string;
  takenAt: string;
  perLevelScores: Record<CefrLevel, PerLevelScore>;
  estimatedLevel: CefrLevel;
  userOverride: CefrLevel | null;
}

interface RawRow {
  id: string;
  userId: string;
  takenAt: string;
  perLevelScores: string;
  estimatedLevel: CefrLevel;
  userOverride: CefrLevel | null;
}

function decode(row: RawRow): PlacementResultRow {
  return {
    ...row,
    perLevelScores: JSON.parse(row.perLevelScores) as Record<CefrLevel, PerLevelScore>,
  };
}

export class PlacementRepository {
  constructor(private db: Database.Database) {}

  create(input: Omit<PlacementResultRow, 'id' | 'takenAt'> & { id?: string; takenAt?: string }): PlacementResultRow {
    const row: PlacementResultRow = {
      id: input.id ?? randomUUID(),
      userId: input.userId,
      takenAt: input.takenAt ?? new Date().toISOString(),
      perLevelScores: input.perLevelScores,
      estimatedLevel: input.estimatedLevel,
      userOverride: input.userOverride ?? null,
    };
    this.db
      .prepare(
        `INSERT INTO placement_results (id, userId, takenAt, perLevelScores, estimatedLevel, userOverride)
         VALUES (@id, @userId, @takenAt, @perLevelScores, @estimatedLevel, @userOverride)`,
      )
      .run({ ...row, perLevelScores: JSON.stringify(row.perLevelScores) });
    return row;
  }

  latestForUser(userId: string): PlacementResultRow | undefined {
    const row = this.db
      .prepare<[string], RawRow>('SELECT * FROM placement_results WHERE userId = ? ORDER BY takenAt DESC LIMIT 1')
      .get(userId);
    return row ? decode(row) : undefined;
  }
}
