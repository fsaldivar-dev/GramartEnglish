import type { CefrLevel, LessonMode } from '../domain/schemas.js';
import type { WordRepository, VocabularyWordRow } from '../store/wordRepository.js';
import type { MasteryRepository, WordMasteryRow } from '../store/masteryRepository.js';

export const LESSON_SIZE = 10;
// FR-013a — 50% new, 30% recently failed, 20% mastered-to-refresh.
export const TARGET_NEW = 5;
export const TARGET_FAILED = 3;
export const TARGET_REFRESH = 2;

export interface SelectorOpts {
  size?: number;
  seed?: number;
  refreshMinAgeMs?: number;
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

export interface SelectorRepos {
  words: WordRepository;
  mastery: MasteryRepository;
}

/**
 * Returns up to `size` vocabulary words for a lesson at the given level,
 * applying the 50/30/20 mix and falling back to "new" pool when a category
 * lacks material. Never returns duplicate wordIds within the same call.
 */
export function selectLessonWords(
  userId: string,
  level: CefrLevel,
  mode: LessonMode,
  deps: SelectorRepos,
  opts: SelectorOpts = {},
): VocabularyWordRow[] {
  const size = opts.size ?? LESSON_SIZE;
  const rng = makeRng(opts.seed);
  const refreshMinAge = opts.refreshMinAgeMs ?? 0;
  const now = Date.now();

  const levelPool = deps.words.byLevel(level);
  if (levelPool.length === 0) return [];

  // Mastery is per-(word, mode). Filter to this mode only — a word mastered
  // in another mode is "new" for this mode.
  const masteryRows = deps.mastery.allForUser(userId, mode);
  const masteryByWord = new Map<number, WordMasteryRow>(masteryRows.map((m) => [m.wordId, m]));

  const isAtLevel = new Set(levelPool.map((w) => w.id));

  const newPool: VocabularyWordRow[] = levelPool.filter((w) => !masteryByWord.has(w.id));

  // "In-progress" pool: any word the user has SEEN but NOT mastered yet.
  // This covers three sub-cases that used to fall through:
  //   1. Failed or skipped (the original meaning of "to review")
  //   2. Correct once but not twice yet — still needs reinforcement
  //   3. Mastered then later failed — back to "in progress"
  // Without this, words got stuck in limbo after one correct answer and the
  // selector eventually couldn't assemble 10 questions ⇒ 409.
  const failedPool: VocabularyWordRow[] = levelPool
    .filter((w) => {
      const m = masteryByWord.get(w.id);
      return m !== undefined && !m.mastered;
    })
    .sort((a, b) => {
      const ma = masteryByWord.get(a.id)!.lastSeenAt;
      const mb = masteryByWord.get(b.id)!.lastSeenAt;
      return mb.localeCompare(ma); // most recent first
    });

  const refreshPool: VocabularyWordRow[] = levelPool
    .filter((w) => {
      const m = masteryByWord.get(w.id);
      if (!m || !m.mastered) return false;
      if (refreshMinAge > 0) {
        const age = now - new Date(m.lastSeenAt).getTime();
        return age >= refreshMinAge;
      }
      return true;
    })
    .sort((a, b) => {
      const ma = masteryByWord.get(a.id)!.lastSeenAt;
      const mb = masteryByWord.get(b.id)!.lastSeenAt;
      return ma.localeCompare(mb); // oldest first
    });

  const targets = [
    { pool: newPool, take: Math.round(size * 0.5) },
    { pool: failedPool, take: Math.round(size * 0.3) },
    { pool: refreshPool, take: size - Math.round(size * 0.5) - Math.round(size * 0.3) },
  ];

  const chosenIds = new Set<number>();
  const chosen: VocabularyWordRow[] = [];

  for (const t of targets) {
    const shuffled = rng.shuffle(t.pool.filter((w) => !chosenIds.has(w.id)));
    for (let i = 0; i < t.take && shuffled[i]; i += 1) {
      chosenIds.add(shuffled[i]!.id);
      chosen.push(shuffled[i]!);
    }
  }

  // Fill any shortfall from the union of pools, preferring "new" then "failed" then "refresh".
  if (chosen.length < size) {
    const combinedFallback = [
      ...rng.shuffle(newPool),
      ...rng.shuffle(failedPool),
      ...rng.shuffle(refreshPool),
    ];
    for (const w of combinedFallback) {
      if (chosen.length >= size) break;
      if (chosenIds.has(w.id)) continue;
      if (!isAtLevel.has(w.id)) continue;
      chosenIds.add(w.id);
      chosen.push(w);
    }
  }

  return chosen.slice(0, size);
}
