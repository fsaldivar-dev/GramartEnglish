import { randomUUID } from 'node:crypto';
import type { CefrLevel } from '../domain/schemas.js';
import type { VocabularyWordRow, WordRepository } from '../store/wordRepository.js';

export const ALL_LEVELS: readonly CefrLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
export const QUESTIONS_PER_LEVEL = 4;

export interface PlacementQuestion {
  id: string;
  wordId: number;
  word: string;
  /** A real sentence using the target word, drawn from the word's canonical
   *  examples. Empty if the word has no canonical example. */
  sentence: string;
  level: CefrLevel;
  options: string[];
  correctIndex: number;
}

export interface SelectorRandom {
  shuffle<T>(arr: T[]): T[];
  pick<T>(arr: T[], n: number): T[];
}

class Rng implements SelectorRandom {
  private state: number;
  constructor(seed?: number) {
    this.state = seed ?? Math.floor(Math.random() * 2 ** 32);
  }
  private next(): number {
    this.state = (this.state * 1664525 + 1013904223) >>> 0;
    return this.state / 2 ** 32;
  }
  shuffle<T>(arr: T[]): T[] {
    const out = [...arr];
    for (let i = out.length - 1; i > 0; i -= 1) {
      const j = Math.floor(this.next() * (i + 1));
      [out[i]!, out[j]!] = [out[j]!, out[i]!];
    }
    return out;
  }
  pick<T>(arr: T[], n: number): T[] {
    return this.shuffle(arr).slice(0, n);
  }
}

export interface SelectQuestionsOptions {
  questionsPerLevel?: number;
  seed?: number;
}

export function selectPlacementQuestions(
  repo: WordRepository,
  opts: SelectQuestionsOptions = {},
): PlacementQuestion[] {
  const perLevel = opts.questionsPerLevel ?? QUESTIONS_PER_LEVEL;
  const rng = new Rng(opts.seed);

  // Collect words per level once for distractor sourcing.
  const wordsByLevel = new Map<CefrLevel, VocabularyWordRow[]>();
  for (const lvl of ALL_LEVELS) wordsByLevel.set(lvl, repo.byLevel(lvl));

  const questions: PlacementQuestion[] = [];

  for (const lvl of ALL_LEVELS) {
    const pool = wordsByLevel.get(lvl) ?? [];
    if (pool.length < perLevel) continue; // not enough material at this level
    const targets = rng.pick(pool, perLevel);
    for (const target of targets) {
      // Distractors: 3 same-level entries excluding the target, falling back to
      // other levels if needed.
      const sameLevelDistractors = pool.filter((w) => w.id !== target.id && w.spanishOption !== target.spanishOption);
      let distractors: VocabularyWordRow[] = rng.pick(sameLevelDistractors, 3);
      if (distractors.length < 3) {
        const fallback: VocabularyWordRow[] = [];
        for (const other of ALL_LEVELS) {
          if (other === lvl) continue;
          fallback.push(...(wordsByLevel.get(other) ?? []).filter((w) => w.spanishOption !== target.spanishOption));
        }
        distractors = [...distractors, ...rng.pick(fallback, 3 - distractors.length)];
      }
      const optionsRaw = rng.shuffle([target.spanishOption, ...distractors.map((d) => d.spanishOption)]);
      const correctIndex = optionsRaw.indexOf(target.spanishOption);
      questions.push({
        id: randomUUID(),
        wordId: target.id,
        word: target.base,
        sentence: target.canonicalExamples[0] ?? '',
        level: target.level,
        options: optionsRaw,
        correctIndex,
      });
    }
  }

  return questions;
}
