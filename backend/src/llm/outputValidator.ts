export interface ValidatedExamples {
  ok: boolean;
  examples: string[];
  reason?: string;
}

export interface ValidatedDefinition {
  ok: boolean;
  definition: string;
  reason?: string;
}

/**
 * Returns true when the text contains the word or a simple morphological
 * variant. Used to filter out hallucinated outputs (FR-008).
 */
export function containsWord(text: string, base: string): boolean {
  const lower = text.toLowerCase();
  const word = base.toLowerCase();
  if (lower.includes(word)) return true;
  // Simple morphological variants: -s, -es, -ed, -ing, -ier, -iest, -er, -est, -ly
  const variants = [
    `${word}s`,
    `${word}es`,
    `${word}ed`,
    `${word}ing`,
    `${word}er`,
    `${word}est`,
    `${word}ly`,
    word.endsWith('e') ? `${word.slice(0, -1)}ing` : null,
    word.endsWith('y') ? `${word.slice(0, -1)}ies` : null,
    word.endsWith('y') ? `${word.slice(0, -1)}ied` : null,
  ].filter((v): v is string => v !== null);
  return variants.some((v) => lower.includes(v));
}

export function validateExamples(rawOutput: string, base: string): ValidatedExamples {
  const lines = rawOutput
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0)
    .map((l) => l.replace(/^[\d\.\-\)\(]+\s*/, '').replace(/^["']|["']$/g, '').trim())
    .filter((l) => l.length > 0);
  const kept = lines.filter((l) => containsWord(l, base)).slice(0, 3);
  if (kept.length === 0) {
    return { ok: false, examples: [], reason: 'no example contained the target word or a known inflection' };
  }
  return { ok: true, examples: kept };
}

export function validateDefinition(rawOutput: string, _base: string): ValidatedDefinition {
  const trimmed = rawOutput.trim();
  if (trimmed.length === 0) return { ok: false, definition: '', reason: 'empty output' };
  // Take the first sentence-ish chunk (until first newline), strip wrapping
  // quotes, and cap at 250 chars.
  const firstLine = (trimmed.split(/\r?\n/)[0] ?? '').trim().replace(/^["']|["']$/g, '').trim();
  if (firstLine.length === 0) return { ok: false, definition: '', reason: 'empty output' };
  const capped = firstLine.length > 250 ? `${firstLine.slice(0, 247)}…` : firstLine;
  return { ok: true, definition: capped };
}
