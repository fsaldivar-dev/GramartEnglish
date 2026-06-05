import { describe, it, expect } from 'vitest';
import {
  createState,
  pickNextLevel,
  step,
  done,
  finalize,
  ALGORITHM_VERSION,
  MAX_ITEMS,
  MIN_ITEMS,
  CONFIDENCE_TARGET,
} from '../../../src/lessons/adaptivePlacement.js';

describe('adaptivePlacement.createState', () => {
  it('maps selfReport to initial levelEstimate', () => {
    expect(createState({ selfReport: 'never' }).levelEstimate).toBeCloseTo(1.5, 5);
    expect(createState({ selfReport: 'some' }).levelEstimate).toBeCloseTo(3.0, 5);
    expect(createState({ selfReport: 'lots' }).levelEstimate).toBeCloseTo(4.5, 5);
    expect(createState({}).levelEstimate).toBeCloseTo(3.5, 5);
    expect(createState({ selfReport: null }).levelEstimate).toBeCloseTo(3.5, 5);
  });

  it('initializes empty perLevel buckets and zero items', () => {
    const s = createState({});
    for (const lvl of [1, 2, 3, 4, 5, 6] as const) {
      expect(s.perLevel[lvl]).toEqual({ attempted: 0, correct: 0 });
    }
    expect(s.itemsAdministered).toBe(0);
    expect(s.confidence).toBe(0);
    expect(s.algorithmVersion).toBe(ALGORITHM_VERSION);
  });
});

describe('adaptivePlacement.pickNextLevel', () => {
  it('picks within a [-1, 0, +1] window around round(estimate), preferring the least-attempted bucket', () => {
    const s = createState({ selfReport: 'some' }); // estimate 3.0, window [2,3,4]
    // All three at 0 ⇒ left-first deterministic tie-break → 2 (CEFR A2).
    expect(pickNextLevel(s)).toBe(2);
    s.perLevel[2].attempted = 5;
    // Now 3 and 4 tied at 0 ⇒ left-first → 3 (B1).
    expect(pickNextLevel(s)).toBe(3);
    s.perLevel[3].attempted = 5;
    // 4 is the least-attempted in the window.
    expect(pickNextLevel(s)).toBe(4);
  });

  it('clamps the window at A1 (1) and C2 (6)', () => {
    const sLow = createState({ selfReport: 'never' });
    sLow.levelEstimate = 1.0; // round(1) = 1; window [0,1,2] → clamped to [1,2]
    expect([1, 2]).toContain(pickNextLevel(sLow));
    const sHigh = createState({ selfReport: 'lots' });
    sHigh.levelEstimate = 6.0;
    expect([5, 6]).toContain(pickNextLevel(sHigh));
  });
});

describe('adaptivePlacement.step', () => {
  it('moves estimate up on correct, down on incorrect, by a step that shrinks with confidence', () => {
    const s = createState({});
    const after1 = step(s, 'A1', true);
    expect(after1.levelEstimate).toBeGreaterThan(s.levelEstimate);
    expect(after1.itemsAdministered).toBe(1);
    expect(after1.confidence).toBeGreaterThan(s.confidence);
    expect(after1.perLevel[1].attempted).toBe(1);
    expect(after1.perLevel[1].correct).toBe(1);
    const wrong = step(after1, 'A2', false);
    expect(wrong.levelEstimate).toBeLessThan(after1.levelEstimate);
    expect(wrong.perLevel[2].attempted).toBe(1);
    expect(wrong.perLevel[2].correct).toBe(0);
  });

  it('clamps estimate to [1, 6]', () => {
    let s = createState({});
    s.levelEstimate = 1.0;
    s = step(s, 'A1', false);
    expect(s.levelEstimate).toBe(1);
    s.levelEstimate = 6.0;
    s.confidence = 0;
    s = step(s, 'C2', true);
    expect(s.levelEstimate).toBe(6);
  });
});

describe('adaptivePlacement.done + finalize', () => {
  it('does NOT finish before MIN_ITEMS even at high confidence', () => {
    const s = createState({});
    s.confidence = 0.99;
    s.itemsAdministered = MIN_ITEMS - 1;
    expect(done(s)).toBe(false);
  });

  it('finishes when confidence ≥ target AND items ≥ MIN_ITEMS', () => {
    const s = createState({});
    s.confidence = CONFIDENCE_TARGET;
    s.itemsAdministered = MIN_ITEMS;
    expect(done(s)).toBe(true);
  });

  it('hard-stops at MAX_ITEMS regardless of confidence', () => {
    const s = createState({});
    s.confidence = 0;
    s.itemsAdministered = MAX_ITEMS;
    expect(done(s)).toBe(true);
  });

  it('floor lock-in: 4 A1 misses ⇒ done, finalize → A1', () => {
    let s = createState({ selfReport: 'never' });
    for (let i = 0; i < 4; i += 1) s = step(s, 'A1', false);
    expect(done(s)).toBe(true);
    expect(finalize(s)).toBe('A1');
  });

  it('ceiling lock-in: 4 C2 hits AND items ≥ MIN_ITEMS ⇒ done, finalize → C2', () => {
    let s = createState({ selfReport: 'lots' });
    // First fill up items ≥ MIN_ITEMS at varying levels
    for (let i = 0; i < MIN_ITEMS; i += 1) {
      s = step(s, 'B2', true);
    }
    // Then 4 perfect C2
    for (let i = 0; i < 4; i += 1) s = step(s, 'C2', true);
    expect(done(s)).toBe(true);
    expect(finalize(s)).toBe('C2');
  });

  it('finalize for a mid-range estimate falls back to per-level scorer behaviour', () => {
    let s = createState({ selfReport: 'some' });
    // 2/2 at A1, A2, B1 → no level above is 0/attempted, so highest pass (B1)
    s = step(step(s, 'A1', true), 'A1', true);
    s = step(step(s, 'A2', true), 'A2', true);
    s = step(step(s, 'B1', true), 'B1', true);
    // Force min items satisfied with a wash at B2
    for (let i = 0; i < MIN_ITEMS; i += 1) s = step(s, 'B2', i % 2 === 0);
    const result = finalize(s);
    expect(['A2', 'B1', 'B2']).toContain(result);
  });
});
