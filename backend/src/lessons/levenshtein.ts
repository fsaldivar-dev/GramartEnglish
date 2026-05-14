/**
 * Returns the Levenshtein distance between `a` and `b`, but short-circuits to
 * `Infinity` as soon as it can prove the distance exceeds `k`. This is the
 * variant we need: we only care about distance ≤ 1 for typo tolerance.
 *
 * For typical vocabulary words (< 20 chars), this is sub-millisecond.
 */
export function levenshteinAtMost(a: string, b: string, k: number): number {
  const m = a.length;
  const n = b.length;
  if (Math.abs(m - n) > k) return Infinity;
  if (m === 0) return n <= k ? n : Infinity;
  if (n === 0) return m <= k ? m : Infinity;

  // Two-row DP with row-min short-circuit.
  let prev = new Array<number>(n + 1);
  let curr = new Array<number>(n + 1);
  for (let j = 0; j <= n; j += 1) prev[j] = j;

  for (let i = 1; i <= m; i += 1) {
    curr[0] = i;
    let rowMin = curr[0]!;
    for (let j = 1; j <= n; j += 1) {
      const cost = a.charCodeAt(i - 1) === b.charCodeAt(j - 1) ? 0 : 1;
      curr[j] = Math.min(
        prev[j]! + 1,        // deletion
        curr[j - 1]! + 1,    // insertion
        prev[j - 1]! + cost, // substitution
      );
      if (curr[j]! < rowMin) rowMin = curr[j]!;
    }
    if (rowMin > k) return Infinity;
    [prev, curr] = [curr, prev];
  }
  return prev[n] ?? Infinity;
}

/** Convenience: is `a` within `k` edits of `b` (case-insensitive, trimmed)? */
export function isWithinEdits(a: string, b: string, k: number): boolean {
  return levenshteinAtMost(a.trim().toLowerCase(), b.trim().toLowerCase(), k) <= k;
}
