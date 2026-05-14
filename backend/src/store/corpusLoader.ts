import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { z } from 'zod';
import type Database from 'better-sqlite3';
import { CefrLevel } from '../domain/schemas.js';
import { WordRepository, type VocabularyWordRow } from './wordRepository.js';

const WordFile = z.array(
  z.object({
    base: z.string(),
    pos: z.string(),
    level: CefrLevel,
    canonicalDefinition: z.string().min(1).max(200),
    canonicalExamples: z.array(z.string()).default([]),
    sourceTag: z.string(),
    spanishOption: z.string().min(1).max(80),
    spanishDefinition: z.string().max(200).default(''),
  }),
);

const LEVELS: ('a1' | 'a2' | 'b1' | 'b2' | 'c1' | 'c2')[] = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'];

export interface LoadResult {
  inserted: number;
  skipped: number;
  total: number;
}

export function loadCorpusIfEmpty(db: Database.Database, corpusDir: string): LoadResult {
  const repo = new WordRepository(db);
  const before = repo.countAll();
  if (before > 0) {
    return { inserted: 0, skipped: 0, total: before };
  }

  const collected: Omit<VocabularyWordRow, 'id'>[] = [];
  const addedAt = new Date().toISOString();

  for (const lvl of LEVELS) {
    const path = join(corpusDir, `${lvl}.json`);
    if (!existsSync(path)) continue;
    const raw = readFileSync(path, 'utf8');
    if (!raw.trim()) continue;
    const parsed = WordFile.parse(JSON.parse(raw));
    for (const w of parsed) {
      collected.push({
        ...w,
        addedAt,
      });
    }
  }

  repo.insertMany(collected);
  const after = repo.countAll();
  return { inserted: after - before, skipped: collected.length - (after - before), total: after };
}
