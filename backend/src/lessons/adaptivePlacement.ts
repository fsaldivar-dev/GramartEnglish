import type { CefrLevel } from '../domain/schemas.js';
import { scorePlacement, buildPerLevelScores, type PerLevelScores } from './placementScorer.js';

/**
 * Pure adaptive placement algorithm (F005).
 *
 * - Stateless functions over an opaque `AdaptivePlacementState`.
 * - Deterministic given a seed (the caller threads it through `pickQuestionForLevel`).
 * - No IRT, no Bayesian update — a moving point estimate with a sample-size
 *   confidence floor. See `specs/005-adaptive-placement/research.md` §1.
 */

export const ALGORITHM_VERSION = 'v2' as const;
export const MIN_ITEMS = 12;
export const MAX_ITEMS = 30;
export const CONFIDENCE_TARGET = 0.85;
const STEP_INITIAL = 0.6;
const STEP_FLOOR = 0.15;
const CONFIDENCE_GROWTH = 0.06;

export type CefrIdx = 1 | 2 | 3 | 4 | 5 | 6;
const LEVEL_BY_IDX: Record<CefrIdx, CefrLevel> = {
  1: 'A1',
  2: 'A2',
  3: 'B1',
  4: 'B2',
  5: 'C1',
  6: 'C2',
};
const IDX_BY_LEVEL: Record<CefrLevel, CefrIdx> = {
  A1: 1,
  A2: 2,
  B1: 3,
  B2: 4,
  C1: 5,
  C2: 6,
};

export type SelfReport = 'never' | 'some' | 'lots';

export interface AdaptivePlacementState {
  levelEstimate: number;
  confidence: number;
  perLevel: Record<CefrIdx, { attempted: number; correct: number }>;
  itemsAdministered: number;
  algorithmVersion: typeof ALGORITHM_VERSION;
  selfReport: SelfReport | null;
}

export function levelFromIdx(i: CefrIdx): CefrLevel {
  return LEVEL_BY_IDX[i];
}
export function idxFromLevel(l: CefrLevel): CefrIdx {
  return IDX_BY_LEVEL[l];
}

function clamp(x: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, x));
}

function initialEstimate(selfReport: SelfReport | null | undefined): number {
  switch (selfReport) {
    case 'never':
      return 1.5;
    case 'some':
      return 3.0;
    case 'lots':
      return 4.5;
    default:
      return 3.5;
  }
}

export function createState(input: { selfReport?: SelfReport | null }): AdaptivePlacementState {
  const selfReport = input.selfReport ?? null;
  return {
    levelEstimate: initialEstimate(selfReport),
    confidence: 0,
    perLevel: {
      1: { attempted: 0, correct: 0 },
      2: { attempted: 0, correct: 0 },
      3: { attempted: 0, correct: 0 },
      4: { attempted: 0, correct: 0 },
      5: { attempted: 0, correct: 0 },
      6: { attempted: 0, correct: 0 },
    },
    itemsAdministered: 0,
    algorithmVersion: ALGORITHM_VERSION,
    selfReport,
  };
}

/** Returns the CEFR index of the next question to administer. */
export function pickNextLevel(s: AdaptivePlacementState): CefrIdx {
  const center = clamp(Math.round(s.levelEstimate), 1, 6) as CefrIdx;
  const candidates: CefrIdx[] = [];
  for (const offset of [-1, 0, 1]) {
    const c = clamp(center + offset, 1, 6) as CefrIdx;
    if (!candidates.includes(c)) candidates.push(c);
  }
  // Prefer the bucket with the fewest attempts; ties resolve to the first
  // candidate (left-most → center-low) so a 3.0 estimate first samples B1, then A2.
  return candidates.reduce(
    (best, lvl) => (s.perLevel[lvl].attempted < s.perLevel[best].attempted ? lvl : best),
    candidates[0]!,
  );
}

/** Apply one answered item; returns the new state (immutable). */
export function step(s: AdaptivePlacementState, level: CefrLevel, correct: boolean): AdaptivePlacementState {
  const idx = idxFromLevel(level);
  const stepSize = Math.max(STEP_FLOOR, STEP_INITIAL * (1 - s.confidence));
  const delta = correct ? +stepSize : -stepSize;
  const newEstimate = clamp(s.levelEstimate + delta, 1, 6);
  const newConfidence = Math.min(1, s.confidence + CONFIDENCE_GROWTH);
  const perLevel = { ...s.perLevel };
  perLevel[idx] = {
    attempted: s.perLevel[idx].attempted + 1,
    correct: s.perLevel[idx].correct + (correct ? 1 : 0),
  };
  return {
    ...s,
    levelEstimate: newEstimate,
    confidence: newConfidence,
    perLevel,
    itemsAdministered: s.itemsAdministered + 1,
  };
}

/** Has the test reached a terminating condition? */
export function done(s: AdaptivePlacementState): boolean {
  if (s.itemsAdministered >= MAX_ITEMS) return true;
  // Floor lock-in: 4+ A1 attempts with zero correct ⇒ user clearly cannot do A1.
  if (s.perLevel[1].attempted >= 4 && s.perLevel[1].correct === 0) return true;
  // Ceiling lock-in: 4+ C2 attempts perfect AND we have enough items overall.
  if (
    s.itemsAdministered >= MIN_ITEMS &&
    s.perLevel[6].attempted >= 4 &&
    s.perLevel[6].correct === s.perLevel[6].attempted
  ) {
    return true;
  }
  if (s.itemsAdministered >= MIN_ITEMS && s.confidence >= CONFIDENCE_TARGET) return true;
  return false;
}

/** Build the final per-level breakdown (matches the legacy `PerLevelScores` shape). */
export function toPerLevelScores(s: AdaptivePlacementState): PerLevelScores {
  const out = buildPerLevelScores();
  for (const lvl of ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'] as const) {
    const idx = idxFromLevel(lvl);
    out[lvl] = { ...s.perLevel[idx] };
  }
  return out;
}

/** Produce the final CEFR label for a terminated state. */
export function finalize(s: AdaptivePlacementState): CefrLevel {
  // Hard locks first — they reflect explicit signals from the user's answers.
  if (s.perLevel[1].attempted >= 4 && s.perLevel[1].correct === 0) return 'A1';
  if (
    s.perLevel[6].attempted >= 4 &&
    s.perLevel[6].correct === s.perLevel[6].attempted &&
    s.itemsAdministered >= MIN_ITEMS
  ) {
    return 'C2';
  }
  // Otherwise defer to the existing per-level scorer for consistency with v1.
  return scorePlacement(toPerLevelScores(s));
}
