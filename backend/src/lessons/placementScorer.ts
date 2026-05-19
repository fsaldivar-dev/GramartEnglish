import type { CefrLevel } from '../domain/schemas.js';
import { ALL_LEVELS } from './placementSelector.js';

export interface PerLevelScore {
  attempted: number;
  correct: number;
}

export type PerLevelScores = Record<CefrLevel, PerLevelScore>;

const DEFAULT_LEVEL: CefrLevel = 'A2';

/**
 * Scores the placement test per research.md §7:
 * - For each level, compute correct/attempted.
 * - estimatedLevel = highest level where percent correct ≥ 50%.
 * - Bump-down rule: if the user got the level above 100% wrong (0/attempted)
 *   and attempted it, drop one step.
 * - Default to A2 when signals are noisy (nothing reached 50%).
 */
export function scorePlacement(scores: PerLevelScores): CefrLevel {
  const passes: CefrLevel[] = [];
  for (const lvl of ALL_LEVELS) {
    const s = scores[lvl];
    if (s.attempted > 0 && s.correct / s.attempted >= 0.5) {
      passes.push(lvl);
    }
  }

  if (passes.length === 0) return DEFAULT_LEVEL;

  // Highest level that passed.
  let estimated = passes[passes.length - 1]!;

  // Bump-down rule: if there is a level above `estimated` that was attempted
  // and scored 0%, drop one step.
  const idx = ALL_LEVELS.indexOf(estimated);
  const above = idx + 1 < ALL_LEVELS.length ? ALL_LEVELS[idx + 1] : undefined;
  if (above) {
    const aboveScore = scores[above];
    if (aboveScore.attempted > 0 && aboveScore.correct === 0 && idx > 0) {
      estimated = ALL_LEVELS[idx - 1]!;
    }
  }

  return estimated;
}

export function buildPerLevelScores(): PerLevelScores {
  return {
    A1: { attempted: 0, correct: 0 },
    A2: { attempted: 0, correct: 0 },
    B1: { attempted: 0, correct: 0 },
    B2: { attempted: 0, correct: 0 },
    C1: { attempted: 0, correct: 0 },
    C2: { attempted: 0, correct: 0 },
  };
}
