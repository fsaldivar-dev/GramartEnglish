import type { CefrLevel } from '../domain/schemas.js';
import type { VerbRepository, VerbRow } from '../store/verbRepository.js';

/**
 * F004 (v1.6.0): pure function that builds one `conjugate_pick_form` question
 * from a target verb. The distractor recipe is locked by PO+TL:
 *
 *   options = shuffle([
 *     correct           = target.simplePast,
 *     over_regularized  = regularize(target.base),        // e.g. "goed" for "go"
 *     base_form         = target.base,                    // e.g. "go"
 *     past_participle   = target.pastParticiple,          // e.g. "gone"
 *   ])
 *
 * When any distractor collides with the correct answer (typical for regular
 * verbs where `over_regularized === simple_past === past_participle ===
 * "<base>ed"`), the recipe degrades gracefully:
 *
 *   - First collision → fall back to a random other-verb past form at the
 *     same level (`other_past`).
 *   - Subsequent collisions → keep drawing other-verb past forms until 3
 *     distinct distractors are found.
 *
 * The function never returns fewer than 4 options; if the verb pool is too
 * small to find 3 distinct distractors it throws (the caller bubbles up a
 * 409 lesson_unavailable).
 */

export interface BuiltConjugationQuestion {
  prompt: string;
  options: string[];
  correctIndex: number;
  verbBase: string;
  targetTense: 'simple_past';
}

export interface VerbBuilderOpts {
  level: CefrLevel;
  seed?: number;
}

interface Rng {
  shuffle<T>(arr: T[]): T[];
  pickInt(maxExclusive: number): number;
}

function makeRng(seed?: number): Rng {
  let s = seed ?? Math.floor(Math.random() * 2 ** 32);
  const next = () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s;
  };
  return {
    shuffle<T>(arr: T[]): T[] {
      const out = [...arr];
      for (let i = out.length - 1; i > 0; i -= 1) {
        const j = next() % (i + 1);
        [out[i]!, out[j]!] = [out[j]!, out[i]!];
      }
      return out;
    },
    pickInt(maxExclusive: number): number {
      return next() % maxExclusive;
    },
  };
}

/**
 * Apply the naïve regular-past rule that L2 learners over-apply. This is
 * intentionally NOT the linguist's spelling rule — the goal is to produce
 * the WRONG form a Spanish-speaking student would write before they learn
 * the irregular past. So:
 *
 *   - go    → "goed"     (not "went")
 *   - eat   → "eated"    (not "ate")
 *   - run   → "runned"   (not "ran")
 *   - travel→ "traveled" (matches the canonical regular past — that's fine,
 *                          collision is detected and the recipe falls back)
 *   - bake  → "bakeed"   (deliberately not deduping the trailing-e; the
 *                          learner over-regularization mistake doesn't apply
 *                          the silent-e rule either)
 *
 * The few cases where this rule produces a real English word are handled by
 * the collision fallback in `buildVerbQuestion` rather than by complicating
 * the regularizer.
 */
export function overRegularize(base: string): string {
  return `${base}ed`;
}

export function buildVerbQuestion(
  target: VerbRow,
  verbs: VerbRepository,
  opts: VerbBuilderOpts,
): BuiltConjugationQuestion {
  const rng = makeRng(opts.seed);
  const correct = target.simplePast;

  // Recipe slots, in order of preference. Filter out anything that collides
  // with the correct answer or with an earlier slot.
  const desired: string[] = [
    overRegularize(target.base),
    target.base,
    target.pastParticiple,
  ];

  const distractors: string[] = [];
  for (const cand of desired) {
    if (cand === correct) continue;
    if (distractors.includes(cand)) continue;
    distractors.push(cand);
  }

  // Top up with random same-level past forms when slots collide with the
  // correct answer (common for regular verbs).
  if (distractors.length < 3) {
    const pool = verbs
      .atLevel(opts.level)
      .filter((v) => v.base !== target.base)
      .map((v) => v.simplePast);
    const shuffled = rng.shuffle(pool);
    for (const cand of shuffled) {
      if (distractors.length >= 3) break;
      if (cand === correct) continue;
      if (distractors.includes(cand)) continue;
      distractors.push(cand);
    }
  }

  if (distractors.length < 3) {
    throw new Error(
      `verbConjugationBuilder: cannot assemble 3 distinct distractors for "${target.base}" (level ${opts.level})`,
    );
  }

  const optionsRaw = rng.shuffle([correct, ...distractors.slice(0, 3)]);
  const correctIndex = optionsRaw.indexOf(correct);

  return {
    prompt: `Pasado simple de **${target.es}**`,
    options: optionsRaw,
    correctIndex,
    verbBase: target.base,
    targetTense: 'simple_past',
  };
}
