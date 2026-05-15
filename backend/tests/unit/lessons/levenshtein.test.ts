import { describe, it, expect } from 'vitest';
import { isWithinEdits, levenshteinAtMost } from '../../../src/lessons/levenshtein.js';

describe('levenshteinAtMost', () => {
  it('returns 0 for identical strings', () => {
    expect(levenshteinAtMost('weather', 'weather', 1)).toBe(0);
  });

  it('returns 1 for single substitution / insertion / deletion', () => {
    expect(levenshteinAtMost('weather', 'westher', 1)).toBe(1);    // substitution
    expect(levenshteinAtMost('weather', 'weatherx', 1)).toBe(1);   // insertion
    expect(levenshteinAtMost('weather', 'weathe', 1)).toBe(1);     // deletion
  });

  it('short-circuits to Infinity once the row min exceeds k', () => {
    expect(levenshteinAtMost('weather', 'orange', 1)).toBe(Infinity);
    expect(levenshteinAtMost('weather', 'thunder', 1)).toBe(Infinity);
  });

  it('respects k for empty strings', () => {
    expect(levenshteinAtMost('', '', 1)).toBe(0);
    expect(levenshteinAtMost('a', '', 1)).toBe(1);
    expect(levenshteinAtMost('ab', '', 1)).toBe(Infinity);
  });
});

describe('isWithinEdits (case-insensitive, trimmed)', () => {
  it('accepts identical when normalized', () => {
    expect(isWithinEdits('  Weather  ', 'weather', 1)).toBe(true);
    expect(isWithinEdits('EAT', 'eat', 1)).toBe(true);
  });

  it('accepts a single-character typo', () => {
    expect(isWithinEdits('wether', 'weather', 1)).toBe(true);
  });

  it('rejects two-character distance', () => {
    expect(isWithinEdits('wethr', 'weather', 1)).toBe(false);
  });
});

describe('SC-004: typo tolerance fixture (20 curated real-world typos)', () => {
  // Each entry is (canonical, typo, expectedDistance).
  // Sourced from common Spanish-speaker mistakes when writing English words.
  const fixture: Array<{ canonical: string; typo: string; expected: number }> = [
    { canonical: 'weather', typo: 'wether', expected: 1 },        // omission of 'a'
    { canonical: 'language', typo: 'lenguage', expected: 1 },     // a→e
    { canonical: 'dangerous', typo: 'dangerus', expected: 1 },    // omitted 'o'
    { canonical: 'important', typo: 'imporant', expected: 1 },    // omitted 't'
    { canonical: 'expensive', typo: 'expensiv', expected: 1 },    // omitted 'e'
    { canonical: 'decide', typo: 'desid', expected: 2 },          // double swap — should NOT pass
    { canonical: 'remember', typo: 'remenber', expected: 1 },     // m→n
    { canonical: 'favorite', typo: 'favourite', expected: 1 },    // UK spelling — accepted as typo
    { canonical: 'travel', typo: 'travell', expected: 1 },        // insertion
    { canonical: 'achieve', typo: 'acheive', expected: 2 },       // transposition — distance 2
    { canonical: 'borrow', typo: 'borow', expected: 1 },          // single deletion
    { canonical: 'kitchen', typo: 'kichen', expected: 1 },        // deletion
    { canonical: 'noisy', typo: 'noizy', expected: 1 },           // s→z
    { canonical: 'quiet', typo: 'quite', expected: 2 },           // transposition
    { canonical: 'village', typo: 'vilage', expected: 1 },        // deletion
    { canonical: 'invite', typo: 'invate', expected: 1 },         // i→a
    { canonical: 'ticket', typo: 'tikit', expected: 2 },          // distance 2
    { canonical: 'easy', typo: 'eazy', expected: 1 },             // s→z
    { canonical: 'build', typo: 'buld', expected: 1 },            // deletion
    { canonical: 'explain', typo: 'esplain', expected: 1 },       // x→s
  ];

  it('produces the expected distance for each fixture entry', () => {
    for (const f of fixture) {
      const d = levenshteinAtMost(f.canonical, f.typo, 5);
      expect.soft(d).toBe(f.expected);
    }
  });

  it('accepts ≥ 90% of distance-1 typos at threshold 1', () => {
    const distance1 = fixture.filter((f) => f.expected === 1);
    const accepted = distance1.filter((f) => isWithinEdits(f.typo, f.canonical, 1));
    const ratio = accepted.length / distance1.length;
    expect(ratio).toBeGreaterThanOrEqual(0.9);
    expect(distance1.length).toBeGreaterThanOrEqual(15);
  });

  it('rejects all distance-2 typos at threshold 1', () => {
    const distance2 = fixture.filter((f) => f.expected === 2);
    for (const f of distance2) {
      expect.soft(isWithinEdits(f.typo, f.canonical, 1)).toBe(false);
    }
  });
});
