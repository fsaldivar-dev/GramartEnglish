import type { CefrLevel, LessonMode } from '../domain/schemas.js';
import type { VocabularyWordRow, WordRepository } from '../store/wordRepository.js';
import { ALL_LEVELS } from './placementSelector.js';

export interface BuiltOptions {
  options: string[];
  correctIndex: number;
}

/**
 * Picks the option-text axis for a given mode:
 *   - read_pick_meaning, listen_pick_meaning → Spanish meaning (`spanishOption`)
 *   - listen_pick_word                       → English word (`base`)
 *   - listen_type                            → English word (used internally; the
 *     view ignores `options` and shows a text field instead).
 */
function optionTextFor(word: VocabularyWordRow, mode: LessonMode): string {
  switch (mode) {
    case 'listen_pick_word':
    case 'listen_type':
      return word.base;
    case 'read_pick_meaning':
    case 'listen_pick_meaning':
      return word.spanishOption;
  }
}

interface Rng {
  shuffle<T>(arr: T[]): T[];
}

function makeRng(seed?: number): Rng {
  let s = seed ?? Math.floor(Math.random() * 2 ** 32);
  return {
    shuffle<T>(arr: T[]): T[] {
      const out = [...arr];
      for (let i = out.length - 1; i > 0; i -= 1) {
        s = (s * 1664525 + 1013904223) >>> 0;
        const j = s % (i + 1);
        [out[i]!, out[j]!] = [out[j]!, out[i]!];
      }
      return out;
    },
  };
}

/**
 * Builds 4 options for a target word: its canonical definition + 3 distractor
 * definitions drawn from the same CEFR level, falling back to neighboring
 * levels when not enough material is available. All 4 options are distinct.
 */
export function buildOptions(
  target: VocabularyWordRow,
  words: WordRepository,
  opts: { seed?: number; mode?: LessonMode } = {},
): BuiltOptions {
  const rng = makeRng(opts.seed);
  const mode: LessonMode = opts.mode ?? 'read_pick_meaning';
  const correctText = optionTextFor(target, mode);

  const sameLevel = words
    .byLevel(target.level)
    .filter((w) => w.id !== target.id && optionTextFor(w, mode) !== correctText);
  let distractorCandidates: VocabularyWordRow[] = rng.shuffle(sameLevel);

  if (distractorCandidates.length < 3) {
    const targetIdx = ALL_LEVELS.indexOf(target.level);
    const neighbors: CefrLevel[] = [];
    for (let offset = 1; offset < ALL_LEVELS.length; offset += 1) {
      const down = ALL_LEVELS[targetIdx - offset];
      const up = ALL_LEVELS[targetIdx + offset];
      if (down) neighbors.push(down);
      if (up) neighbors.push(up);
    }
    for (const lvl of neighbors) {
      if (distractorCandidates.length >= 3) break;
      const more = words
        .byLevel(lvl)
        .filter((w) => optionTextFor(w, mode) !== correctText);
      distractorCandidates = [...distractorCandidates, ...rng.shuffle(more)];
    }
  }

  const distractorTexts: string[] = [];
  for (const w of distractorCandidates) {
    if (distractorTexts.length >= 3) break;
    const text = optionTextFor(w, mode);
    if (distractorTexts.includes(text)) continue;
    distractorTexts.push(text);
  }
  if (distractorTexts.length < 3) {
    throw new Error(`Not enough distractor material for word "${target.base}" (${target.level})`);
  }

  const optionsRaw = rng.shuffle([correctText, ...distractorTexts]);
  const correctIndex = optionsRaw.indexOf(correctText);
  return { options: optionsRaw, correctIndex };
}
