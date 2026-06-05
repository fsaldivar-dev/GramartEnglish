import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { z } from 'zod';
import { CefrLevel } from '../domain/schemas.js';
import type { WordRepository, VocabularyWordRow } from './wordRepository.js';

/**
 * F004 (v1.6.0): VerbRepository overlays conjugation metadata onto the
 * existing `vocabulary_words` table.
 *
 * Why a side-channel JSON instead of a new SQL table?
 * - schemaVersion is locked at 3 (additive-only). A new `verbs` table would
 *   force a migration to keep mastery FK semantics clean (`(userId, wordId,
 *   mode)` already gives us the per-mode axis for free).
 * - Each verb's `base` is already a row in `vocabulary_words`, so the
 *   mastery row PK works unchanged: the question stores `wordId = words.byBase(verb.base).id`.
 * - `verbs.json` is loaded once at startup into a Map and never re-read.
 *   It is the single source of truth for `simple_past`, `past_participle`,
 *   and the `irregular` flag.
 *
 * If F004 grows beyond the v1.6.0 single-mode scope (e.g. F004 US2 adds
 * `conjugate_type_form` with multiple tenses), promote this to a real table
 * via migration 0004 and keep the JSON only as the seed source.
 */
export interface VerbRow {
  id: string;          // "verb_<base>", stable across releases
  wordId: number;      // foreign key into vocabulary_words.id
  base: string;        // English infinitive (lowercase)
  es: string;          // Spanish infinitive
  level: CefrLevel;    // conjugation-skill level (A2 or B1 in v1.6.0)
  simplePast: string;  // canonical English past form
  pastParticiple: string;
  irregular: boolean;
  audioBase: string;
  audioPast: string;
  /** v1.6.0 patch (Blocker 2): Spanish example sentence with `___` marking
   *  the verb slot, e.g. "Ayer ___ tacos." The blank disambiguates tenses
   *  that Spanish distinguishes (preterite vs imperfect) but English
   *  collapses (both → "ate"). Temporal markers (ayer, anoche, la semana
   *  pasada, el año pasado) anchor the answer to past simple. */
  exampleEs: string;
  /** v1.6.0 patch (Blocker 2): the English translation of `exampleEs` with
   *  the verb already conjugated — shown after the user answers as a
   *  reinforcement, never as a hint before they choose. */
  exampleEn: string;
}

const VerbFile = z.array(
  z.object({
    id: z.string().regex(/^verb_[a-z]+$/),
    base: z.string().min(1),
    es: z.string().min(1),
    level: CefrLevel,
    simple_past: z.string().min(1),
    past_participle: z.string().min(1),
    irregular: z.boolean(),
    audio_base: z.string().min(1),
    audio_past: z.string().min(1),
    example_es: z.string().min(1),
    example_en: z.string().min(1),
  }),
);

export class VerbRepository {
  private readonly byBase = new Map<string, VerbRow>();
  private readonly byLevel = new Map<CefrLevel, VerbRow[]>();
  private readonly byWordId = new Map<number, VerbRow>();

  constructor(rows: VerbRow[]) {
    for (const r of rows) {
      this.byBase.set(r.base, r);
      this.byWordId.set(r.wordId, r);
      const list = this.byLevel.get(r.level) ?? [];
      list.push(r);
      this.byLevel.set(r.level, list);
    }
  }

  /** Number of verbs at the given conjugation level. */
  countByLevel(level: CefrLevel): number {
    return this.byLevel.get(level)?.length ?? 0;
  }

  /** All verbs at a level. Stable ordering: insertion order from verbs.json. */
  atLevel(level: CefrLevel): VerbRow[] {
    return [...(this.byLevel.get(level) ?? [])];
  }

  /** Lookup by English base form. */
  lookupByBase(base: string): VerbRow | undefined {
    return this.byBase.get(base);
  }

  /** Lookup by vocabulary_words.id — used by lessonService when resolving a
   *  conjugate_pick_form question's wordId back to verb metadata. */
  lookupByWordId(wordId: number): VerbRow | undefined {
    return this.byWordId.get(wordId);
  }

  /** Random sample of `n` verbs at a level, drawn via the supplied shuffler. */
  sample(level: CefrLevel, n: number, shuffle: <T>(arr: T[]) => T[]): VerbRow[] {
    return shuffle(this.atLevel(level)).slice(0, n);
  }
}

/**
 * Load `verbs.json` from the corpus directory and resolve each verb's wordId
 * via the existing WordRepository. Verbs whose `base` has no matching row in
 * vocabulary_words are skipped with a warning — this should never happen in
 * production, but the defensive guard keeps a corpus typo from crashing boot.
 */
export function loadVerbCorpus(corpusDir: string, words: WordRepository): VerbRepository {
  const path = join(corpusDir, 'verbs.json');
  if (!existsSync(path)) return new VerbRepository([]);
  const raw = readFileSync(path, 'utf8');
  if (!raw.trim()) return new VerbRepository([]);
  const parsed = VerbFile.parse(JSON.parse(raw));
  const rows: VerbRow[] = [];
  for (const v of parsed) {
    const w: VocabularyWordRow | undefined = words.byBase(v.base);
    if (!w) {
      // Defensive: skip the row but keep loading. A test asserts wordId
      // resolution for every verb in the production corpus.
      continue;
    }
    rows.push({
      id: v.id,
      wordId: w.id,
      base: v.base,
      es: v.es,
      level: v.level,
      simplePast: v.simple_past,
      pastParticiple: v.past_participle,
      irregular: v.irregular,
      audioBase: v.audio_base,
      audioPast: v.audio_past,
      exampleEs: v.example_es,
      exampleEn: v.example_en,
    });
  }
  return new VerbRepository(rows);
}
