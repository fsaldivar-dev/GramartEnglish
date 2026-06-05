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
  /** F005 — optional, hydrated from the `_meta` sentinel inside the JSON envelope. */
  algorithmVersion?: 'v1' | 'v2';
  itemsAdministered?: number;
}

interface RawRow {
  id: string;
  userId: string;
  takenAt: string;
  perLevelScores: string;
  estimatedLevel: CefrLevel;
  userOverride: CefrLevel | null;
}

interface MetaEnvelope {
  algorithmVersion?: 'v1' | 'v2';
  itemsAdministered?: number;
}

const CEFR_LEVELS: readonly CefrLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

function decode(row: RawRow): PlacementResultRow {
  const parsed = JSON.parse(row.perLevelScores) as Record<string, unknown>;
  const meta: MetaEnvelope | undefined =
    parsed && typeof parsed === 'object' && '_meta' in parsed
      ? ((parsed as Record<string, unknown>)._meta as MetaEnvelope)
      : undefined;
  const perLevelScores: Record<CefrLevel, PerLevelScore> = {
    A1: { attempted: 0, correct: 0 },
    A2: { attempted: 0, correct: 0 },
    B1: { attempted: 0, correct: 0 },
    B2: { attempted: 0, correct: 0 },
    C1: { attempted: 0, correct: 0 },
    C2: { attempted: 0, correct: 0 },
  };
  for (const lvl of CEFR_LEVELS) {
    const v = parsed[lvl] as PerLevelScore | undefined;
    if (v) perLevelScores[lvl] = v;
  }
  const out: PlacementResultRow = {
    id: row.id,
    userId: row.userId,
    takenAt: row.takenAt,
    perLevelScores,
    estimatedLevel: row.estimatedLevel,
    userOverride: row.userOverride,
  };
  if (meta?.algorithmVersion) out.algorithmVersion = meta.algorithmVersion;
  if (typeof meta?.itemsAdministered === 'number') out.itemsAdministered = meta.itemsAdministered;
  return out;
}

function encode(row: PlacementResultRow): string {
  const envelope: Record<string, unknown> = { ...row.perLevelScores };
  if (row.algorithmVersion !== undefined || row.itemsAdministered !== undefined) {
    const meta: MetaEnvelope = {};
    if (row.algorithmVersion !== undefined) meta.algorithmVersion = row.algorithmVersion;
    if (row.itemsAdministered !== undefined) meta.itemsAdministered = row.itemsAdministered;
    envelope._meta = meta;
  }
  return JSON.stringify(envelope);
}

export class PlacementRepository {
  constructor(private db: Database.Database) {}

  create(
    input: Omit<PlacementResultRow, 'id' | 'takenAt'> & { id?: string; takenAt?: string },
  ): PlacementResultRow {
    const row: PlacementResultRow = {
      id: input.id ?? randomUUID(),
      userId: input.userId,
      takenAt: input.takenAt ?? new Date().toISOString(),
      perLevelScores: input.perLevelScores,
      estimatedLevel: input.estimatedLevel,
      userOverride: input.userOverride ?? null,
      ...(input.algorithmVersion !== undefined ? { algorithmVersion: input.algorithmVersion } : {}),
      ...(input.itemsAdministered !== undefined ? { itemsAdministered: input.itemsAdministered } : {}),
    };
    this.db
      .prepare(
        `INSERT INTO placement_results (id, userId, takenAt, perLevelScores, estimatedLevel, userOverride)
         VALUES (@id, @userId, @takenAt, @perLevelScores, @estimatedLevel, @userOverride)`,
      )
      .run({ ...row, perLevelScores: encode(row) });
    return row;
  }

  latestForUser(userId: string): PlacementResultRow | undefined {
    const row = this.db
      .prepare<[string], RawRow>('SELECT * FROM placement_results WHERE userId = ? ORDER BY takenAt DESC LIMIT 1')
      .get(userId);
    return row ? decode(row) : undefined;
  }
}
