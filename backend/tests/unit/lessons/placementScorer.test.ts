import { describe, it, expect } from 'vitest';
import { buildPerLevelScores, scorePlacement } from '../../../src/lessons/placementScorer.js';

describe('scorePlacement', () => {
  it('defaults to A2 when nothing reaches 50%', () => {
    const scores = buildPerLevelScores();
    scores.A1 = { attempted: 2, correct: 0 };
    scores.A2 = { attempted: 2, correct: 0 };
    scores.B1 = { attempted: 2, correct: 0 };
    expect(scorePlacement(scores)).toBe('A2');
  });

  it('returns the highest level that reached 50% when no level above is attempted-zero', () => {
    const scores = buildPerLevelScores();
    scores.A1 = { attempted: 2, correct: 2 };
    scores.A2 = { attempted: 2, correct: 2 };
    scores.B1 = { attempted: 2, correct: 1 };
    // B2 not attempted — no bump-down signal
    expect(scorePlacement(scores)).toBe('B1');
  });

  it('applies bump-down when level above is 0/attempted', () => {
    const scores = buildPerLevelScores();
    scores.A1 = { attempted: 2, correct: 2 };
    scores.A2 = { attempted: 2, correct: 2 };
    scores.B1 = { attempted: 2, correct: 1 }; // passes
    scores.B2 = { attempted: 2, correct: 0 }; // total miss above
    expect(scorePlacement(scores)).toBe('A2');
  });

  it('does not bump down when level above was not attempted', () => {
    const scores = buildPerLevelScores();
    scores.A1 = { attempted: 2, correct: 2 };
    scores.A2 = { attempted: 2, correct: 2 };
    scores.B1 = { attempted: 2, correct: 1 };
    // B2 attempted=0 — don't bump
    expect(scorePlacement(scores)).toBe('B1');
  });

  it('caps at C2 even if all levels pass', () => {
    const scores = buildPerLevelScores();
    for (const lvl of ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'] as const) {
      scores[lvl] = { attempted: 2, correct: 2 };
    }
    expect(scorePlacement(scores)).toBe('C2');
  });

  it('handles single-level pass at A1 without bumping below A1', () => {
    const scores = buildPerLevelScores();
    scores.A1 = { attempted: 2, correct: 2 };
    scores.A2 = { attempted: 2, correct: 0 };
    // A1 passes but A2 is 0/2 — A1 has no level below, so stays.
    expect(scorePlacement(scores)).toBe('A1');
  });
});
