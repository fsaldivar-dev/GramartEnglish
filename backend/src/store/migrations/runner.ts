import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type Database from 'better-sqlite3';

const MIGRATIONS_DIR = dirname(fileURLToPath(import.meta.url));

export interface Migration {
  version: number;
  name: string;
  sql: string;
}

export function loadMigrations(dir: string = MIGRATIONS_DIR): Migration[] {
  return readdirSync(dir)
    .filter((f) => f.endsWith('.sql') && !f.endsWith('_rollback.sql'))
    .map((file) => {
      const match = /^(\d+)_(.+)\.sql$/.exec(file);
      if (!match) throw new Error(`Invalid migration filename: ${file}`);
      return {
        version: Number.parseInt(match[1]!, 10),
        name: match[2]!,
        sql: readFileSync(join(dir, file), 'utf8'),
      };
    })
    .sort((a, b) => a.version - b.version);
}

export function getCurrentVersion(db: Database.Database): number {
  const row = db.pragma('user_version', { simple: true }) as number;
  return row;
}

export function loadRollback(version: number, dir: string = MIGRATIONS_DIR): string | null {
  const padded = String(version).padStart(4, '0');
  const matches = readdirSync(dir).filter(
    (f) => f.startsWith(padded + '_') && f.endsWith('_rollback.sql'),
  );
  if (matches.length === 0) return null;
  return readFileSync(join(dir, matches[0]!), 'utf8');
}

export function rollbackTo(db: Database.Database, targetVersion: number): boolean {
  const current = getCurrentVersion(db);
  if (current <= targetVersion) return false;
  const sql = loadRollback(current);
  if (!sql) throw new Error(`No rollback script found for version ${current}`);
  db.exec(sql);
  return true;
}

export function runMigrations(db: Database.Database, migrations?: Migration[]): number {
  const all = migrations ?? loadMigrations();
  const current = getCurrentVersion(db);
  let applied = 0;
  for (const m of all) {
    if (m.version <= current) continue;
    db.exec('BEGIN');
    try {
      db.exec(m.sql);
      db.exec('COMMIT');
      applied += 1;
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
  }
  return applied;
}
