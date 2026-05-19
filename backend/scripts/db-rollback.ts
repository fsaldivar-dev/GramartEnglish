#!/usr/bin/env tsx
/**
 * Usage:  pnpm run db:rollback [targetVersion]
 *
 * Rolls back one migration (the most recently applied). If targetVersion is
 * provided, rolls back successively until user_version == targetVersion.
 *
 * SAFETY: take a copy of the SQLite file first. This is destructive.
 */
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openDb } from '../src/store/db.js';
import { getCurrentVersion, rollbackTo } from '../src/store/migrations/runner.js';

const REPO_ROOT = join(fileURLToPath(import.meta.url), '..', '..', '..');
const target = Number.parseInt(process.argv[2] ?? '0', 10);

const dbFilename = process.env.GRAMART_DB ?? join(REPO_ROOT, '.gramart', 'app.db');
const db = openDb({ filename: dbFilename });

let current = getCurrentVersion(db);
process.stdout.write(`current version: ${current}\n`);

while (current > target) {
  const rolled = rollbackTo(db, current - 1);
  if (!rolled) break;
  current = getCurrentVersion(db);
  process.stdout.write(`rolled back to: ${current}\n`);
}

process.stdout.write(`final version: ${current}\n`);
db.close();
