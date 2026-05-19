import { SHIPPED_MODES, type CefrLevel, type LessonMode } from '../domain/schemas.js';
import type { WordRepository } from '../store/wordRepository.js';
import type { MasteryRepository } from '../store/masteryRepository.js';

export interface RecommenderRepos {
  words: WordRepository;
  mastery: MasteryRepository;
}

const BRAND_NEW_FALLBACK: LessonMode = 'listen_pick_word';

/**
 * Recommend the next lesson mode for a user.
 * Heuristic (research.md §2):
 *   1. For each shipped mode, compute `pending` = (level pool size) − (mastered in mode).
 *   2. argmax(pending). Ties broken by least-recently-used (`lastSeenAt`, null = oldest).
 *   3. Brand-new user (every mode tied AND every lastSeen is null) → `listen_pick_word`.
 *   4. Coming-soon modes (not in SHIPPED_MODES) are excluded from candidates.
 */
export function recommendMode(
  userId: string,
  level: CefrLevel,
  deps: RecommenderRepos,
): LessonMode {
  const levelPoolSize = deps.words.byLevel(level).length;

  const stats = SHIPPED_MODES.map((mode) => {
    const masteredCount = deps.mastery.countMastered(userId, mode);
    const pending = Math.max(0, levelPoolSize - masteredCount);
    const lastSeen = deps.mastery.lastSeenForMode(userId, mode);
    return { mode, pending, lastSeen };
  });

  // Brand-new user: every mode is tied on pending AND every lastSeen is null.
  const allNullLastSeen = stats.every((s) => s.lastSeen === null);
  const allSamePending = stats.every((s) => s.pending === stats[0]!.pending);
  if (allNullLastSeen && allSamePending) {
    return BRAND_NEW_FALLBACK;
  }

  // Sort: higher pending first; then lastSeen ascending (null = oldest = wins).
  stats.sort((a, b) => {
    if (b.pending !== a.pending) return b.pending - a.pending;
    const aKey = a.lastSeen ?? '';
    const bKey = b.lastSeen ?? '';
    return aKey.localeCompare(bKey);
  });

  return stats[0]!.mode;
}
