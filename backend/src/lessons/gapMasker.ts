/**
 * write_fill_gaps masking — F003 US3 (v1.5.0).
 *
 * Spec: `specs/003-writing-modes/research.md` §1 (locked algorithm).
 *
 * Rules (in order):
 *   1. Words length ≤ 3 → `autoPromoted: true`, `masked` = original word.
 *      Caller (lessonService) treats these as `write_type_word` semantics.
 *   2. Always keep first letter visible.
 *   3. Remove vowels first: a, e, i, o, u. `y` counts as a vowel ONLY when
 *      it's the last character of the word (word-final).
 *   4. If gap ratio < 40 % AND we haven't capped, also remove weak
 *      consonants (h, w, y where y wasn't already removed).
 *   5. Gap ratio is capped at 50 % — never remove more than floor(N/2)
 *      characters.
 *   6. Output `masked` = original word with removed positions replaced by `_`.
 *
 * Examples (from research §1):
 *   weather   → w__th_r  (3/7 = 43 %)
 *   dangerous → d_ng_r__s (4/9 = 44 %)
 *   language  → l_ng__g_ (4/8 = 50 % capped)
 *   eat       → autoPromoted (length 3)
 */
export interface MaskResult {
  masked: string;
  autoPromoted: boolean;
}

const VOWELS = new Set(['a', 'e', 'i', 'o', 'u']);
const WEAK_CONSONANTS = new Set(['h', 'w', 'y']);

export function maskWord(word: string): MaskResult {
  const original = word;
  const lower = word.toLowerCase();
  const n = lower.length;

  // Rule 1: short words auto-promote.
  if (n <= 3) {
    return { masked: original, autoPromoted: true };
  }

  const cap = Math.floor(n / 2); // never remove more than half (rule 5)

  // Track removed positions (skip index 0 — first letter always visible — rule 2).
  const removed = new Set<number>();

  // Rule 3: vowels first. `y` is a vowel only when word-final.
  for (let i = 1; i < n; i += 1) {
    if (removed.size >= cap) break;
    const ch = lower[i]!;
    if (VOWELS.has(ch)) {
      removed.add(i);
    } else if (ch === 'y' && i === n - 1) {
      removed.add(i);
    }
  }

  // Rule 4: if gap ratio < 40 %, remove weak consonants (h, w, y) too.
  const minGaps = Math.ceil(n * 0.4);
  if (removed.size < minGaps) {
    for (let i = 1; i < n; i += 1) {
      if (removed.size >= cap) break;
      if (removed.size >= minGaps) break;
      if (removed.has(i)) continue;
      const ch = lower[i]!;
      if (WEAK_CONSONANTS.has(ch)) {
        removed.add(i);
      }
    }
  }

  // Build masked string from original (preserve original casing on kept chars).
  let masked = '';
  for (let i = 0; i < n; i += 1) {
    masked += removed.has(i) ? '_' : original[i]!;
  }
  return { masked, autoPromoted: false };
}
