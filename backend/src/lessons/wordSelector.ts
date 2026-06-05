import type { CefrLevel, LessonMode } from '../domain/schemas.js';
import type { WordRepository, VocabularyWordRow } from '../store/wordRepository.js';
import type { MasteryRepository, WordMasteryRow } from '../store/masteryRepository.js';

export const LESSON_SIZE = 10;
// FR-013a — 50% new, 30% recently failed, 20% mastered-to-refresh.
export const TARGET_NEW = 5;
export const TARGET_FAILED = 3;
export const TARGET_REFRESH = 2;

/**
 * F009 (v1.10.0). Multiplicative selection-weight bias applied to
 * candidate words that:
 *   1. carry a `falseFriendEs` warning (Lucía's belt), AND
 *   2. are NOT yet mastered in the current mode for this user.
 *
 * Pedagogical rationale: the belt only fires its "OJO" chip at the
 * moment of recall, so a learner who never sees the false-friend word
 * during practice never gets the disambiguation. A flat 15% lift
 * surfaces roughly +1 false-friend per ~7 lessons on a balanced corpus
 * without dominating review lessons. The bias is uncompounded — once
 * the word is mastered in the mode, its weight returns to baseline,
 * so streak distortion is bounded.
 *
 * Why 1.15 specifically (vs 1.10 or 1.25):
 *   - 1.10 is below the noise floor of a 40-word level pool — the
 *     bias test would flake on small samples.
 *   - 1.25 over-represents the belt in mixed-level review lessons.
 *   - 1.15 hits Lucía's "OJO cue ≈ once per week" target.
 */
export const FALSE_FRIEND_BIAS_FACTOR = 1.15;

export interface SelectorOpts {
  size?: number;
  seed?: number;
  refreshMinAgeMs?: number;
}

interface Rng {
  shuffle<T>(arr: T[]): T[];
  /**
   * F009 (v1.10.0). Weighted shuffle via Efraimidis-Spirakis: each item
   * gets a key `u^(1/weight)` where u is a uniform sample. Sorting by
   * key descending yields a permutation where items with higher weight
   * are more likely to land near the front. With every weight = 1 it
   * is statistically equivalent to a Fisher-Yates shuffle. We pass a
   * `weightFn` rather than a parallel array so the bias rule lives at
   * the call-site and the shuffle stays general-purpose.
   */
  weightedShuffle<T>(arr: T[], weightFn: (item: T) => number): T[];
}

function makeRng(seed?: number): Rng {
  let s = seed ?? Math.floor(Math.random() * 2 ** 32);
  const nextU = (): number => {
    s = (s * 1664525 + 1013904223) >>> 0;
    // 32-bit LCG → uniform on (0, 1). Clamp 0 to avoid log(0) below.
    return Math.max(1e-12, (s + 1) / 0x1_0000_0001);
  };
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
    weightedShuffle<T>(arr: T[], weightFn: (item: T) => number): T[] {
      // key = u^(1/weight) — sort desc by key. We use Math.log to keep
      // numerical stability when weights are close to 1.
      const keyed = arr.map((item) => {
        const w = Math.max(1e-9, weightFn(item));
        const key = Math.log(nextU()) / w;
        return { item, key };
      });
      keyed.sort((a, b) => b.key - a.key);
      return keyed.map((k) => k.item);
    },
  };
}

/**
 * F009 (v1.10.0). The bias rule: a non-mastered false-friend word gets
 * `FALSE_FRIEND_BIAS_FACTOR` (1.15); everything else baseline (1.0).
 * Mastered false-friend words revert to 1.0 so the belt doesn't dominate
 * review lessons.
 */
function falseFriendWeight(
  word: VocabularyWordRow,
  masteryByWord: Map<number, WordMasteryRow>,
): number {
  if (!word.falseFriendEs) return 1.0;
  const m = masteryByWord.get(word.id);
  if (m?.mastered) return 1.0;
  return FALSE_FRIEND_BIAS_FACTOR;
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

  // F009 (v1.10.0): weight each candidate by `falseFriendWeight` so the
  // belt surfaces ~15% more often within each pool. Mastered words and
  // non-belt words use weight = 1.0 (no change vs v1.9.0 behavior).
  const weightFn = (w: VocabularyWordRow): number => falseFriendWeight(w, masteryByWord);

  for (const t of targets) {
    const shuffled = rng.weightedShuffle(t.pool.filter((w) => !chosenIds.has(w.id)), weightFn);
    for (let i = 0; i < t.take && shuffled[i]; i += 1) {
      chosenIds.add(shuffled[i]!.id);
      chosen.push(shuffled[i]!);
    }
  }

  // Fill any shortfall from the union of pools, preferring "new" then "failed" then "refresh".
  if (chosen.length < size) {
    const combinedFallback = [
      ...rng.weightedShuffle(newPool, weightFn),
      ...rng.weightedShuffle(failedPool, weightFn),
      ...rng.weightedShuffle(refreshPool, weightFn),
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
