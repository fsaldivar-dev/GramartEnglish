import { describe, it, expect } from 'vitest';
import { maskWord } from '../../../src/lessons/gapMasker.js';

function gapRatio(masked: string): number {
  const gaps = [...masked].filter((c) => c === '_').length;
  return gaps / masked.length;
}

describe('maskWord (F003 US3, research §1)', () => {
  it('weather → mask preserves w, has gaps in 40-50 % range', () => {
    const { masked, autoPromoted } = maskWord('weather');
    expect(autoPromoted).toBe(false);
    expect(masked.length).toBe('weather'.length);
    expect(masked[0]).toBe('w');
    const ratio = gapRatio(masked);
    expect(ratio).toBeGreaterThanOrEqual(0.4);
    expect(ratio).toBeLessThanOrEqual(0.5);
  });

  it('eat (3 letters) auto-promotes with first-letter scaffold (v1.5.1)', () => {
    const { masked, autoPromoted } = maskWord('eat');
    expect(autoPromoted).toBe(true);
    expect(masked).toBe('e__');
  });

  it('go (2 letters) auto-promotes with first-letter scaffold (v1.5.1)', () => {
    const r = maskWord('go');
    expect(r.autoPromoted).toBe(true);
    expect(r.masked).toBe('g_');
  });

  it('year (4 letters, boundary) → standard masking, NOT auto-promoted', () => {
    const { masked, autoPromoted } = maskWord('year');
    expect(autoPromoted).toBe(false);
    expect(masked.length).toBe(4);
    expect(masked[0]).toBe('y');
    // At least one underscore — standard masker engaged.
    expect(masked).toContain('_');
  });

  it('language → first letter preserved, gap ratio ≤ 50 %', () => {
    const { masked, autoPromoted } = maskWord('language');
    expect(autoPromoted).toBe(false);
    expect(masked[0]).toBe('l');
    expect(gapRatio(masked)).toBeLessThanOrEqual(0.5);
    // 'a','u','a','e' are vowels; cap at floor(8/2)=4.
    const gaps = [...masked].filter((c) => c === '_').length;
    expect(gaps).toBeLessThanOrEqual(4);
  });

  it('play (4 letters) → first letter preserved; trailing y is a vowel', () => {
    const { masked, autoPromoted } = maskWord('play');
    expect(autoPromoted).toBe(false);
    expect(masked[0]).toBe('p');
    // word-final y should be removed (treated as a vowel).
    expect(masked[3]).toBe('_');
  });

  it('myth (no vowels) → weak consonant fallback hits ≥ 40 % gap ratio', () => {
    const { masked, autoPromoted } = maskWord('myth');
    expect(autoPromoted).toBe(false);
    expect(masked[0]).toBe('m');
    // After vowel pass nothing was removed; the weak-consonant pass should
    // pull h and/or y to land ≥ 40 %.
    expect(gapRatio(masked)).toBeGreaterThanOrEqual(0.4);
    expect(gapRatio(masked)).toBeLessThanOrEqual(0.5);
  });

  it('dangerous → matches the research §1 example (4/9 ≈ 44 %, first letter d preserved)', () => {
    const { masked, autoPromoted } = maskWord('dangerous');
    expect(autoPromoted).toBe(false);
    expect(masked[0]).toBe('d');
    const ratio = gapRatio(masked);
    expect(ratio).toBeGreaterThanOrEqual(0.4);
    expect(ratio).toBeLessThanOrEqual(0.5);
  });

  it('never removes more than floor(N/2) characters (rule 5 cap)', () => {
    for (const w of ['weather', 'dangerous', 'language', 'beautiful', 'opportunity']) {
      const { masked } = maskWord(w);
      const gaps = [...masked].filter((c) => c === '_').length;
      expect(gaps).toBeLessThanOrEqual(Math.floor(w.length / 2));
    }
  });
});
