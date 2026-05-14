import Database from 'better-sqlite3';
import { runMigrations } from './migrations/runner.js';

export interface DbOptions {
  filename: string;
  readonly?: boolean;
}

export function openDb(opts: DbOptions): Database.Database {
  const db = new Database(opts.filename, { readonly: opts.readonly ?? false });
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.pragma('busy_timeout = 5000');
  if (!opts.readonly) runMigrations(db);
  return db;
}
