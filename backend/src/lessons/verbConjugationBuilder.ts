import type { CefrLevel } from '../domain/schemas.js';
import type { VerbRepository, VerbRow } from '../store/verbRepository.js';

/**
 * F004 (v1.6.0) / F007 (v1.8.0): pure function that builds one
 * `conjugate_pick_form` question from a target verb. Distractor recipe:
 *
 *   v1.6.0 original:
 *     [over_regularized, base, past_participle, +random_other_past_at_level]
 *
 *   v1.8.0 (F007): Lucía called this out as a teaching anti-pattern —
 *     surfacing `goed`/`runed`/`eated` as MCQ options teaches the error
 *     because every reading of the wrong option leaves an "I saw that
 *     spelling" trace. Replace it with two more random valid past-form
 *     distractors. The over-regularized form is STILL generated server-
 *     side, but only used as a `feedbackHint` when the learner picks/
 *     types it in a write mode (see `lessonService.submitAnswer`). The
 *     teaching moment now happens AFTER the wrong commitment, not before.
 *
 *   v1.8.0 recipe:
 *     [correct, base, past_participle, +random_other_past_at_level]
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
  /** v1.6.0 patch (Blocker 2): Spanish example sentence with `___` slot,
   *  rendered below the prompt header to disambiguate preterite/imperfect
   *  collisions Spanish makes that English doesn't (e.g. "comí" vs "comía"
   *  both → "ate"). */
  exampleEs: string;
  /** v1.6.0 patch (Blocker 2): English translation with the verb already
   *  conjugated. Surfaced post-answer for reinforcement, not pre-answer. */
  exampleEn: string;
}

/**
 * v1.6.0 patch (Blocker 1): some English verbs spell the simple past
 * identically to the base (`read`/`read`, `cut`/`cut`, `put`/`put`,
 * `hit`/`hit`, `let`/`let`, `set`/`set`, `cost`/`cost`, `hurt`/`hurt`).
 * For these, `conjugate_pick_form` is unanswerable as MCQ — the "correct"
 * option and the "base form" distractor are spelled the same. The current
 * A2/B1 corpus only has `read`; this guard exists so any future addition
 * is caught before reaching the picker.
 *
 * The selector exposes this as a pure predicate so tests can pin the rule
 * even if the corpus changes.
 */
export function isAmbiguousForPickForm(verb: { base: string; simplePast: string }): boolean {
  return verb.base.toLowerCase() === verb.simplePast.toLowerCase();
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
 *   - run   → "runed"    (not "ran" and not "runned" — we DELIBERATELY don't
 *                          double the consonant. At A2 the consonant-doubling
 *                          CVC rule isn't taught yet, so "runed" is the
 *                          believable wrong form a learner produces. Adding
 *                          the CVC regularizer would over-engineer the
 *                          distractor for negligible pedagogical gain. PO+TL
 *                          locked this choice 2026-06-05 — see this comment.)
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
  // with the correct answer or with an earlier slot. v1.8.0 (F007): the
  // over-regularized form is intentionally absent — it's reserved for
  // post-answer `feedbackHint` rendering, not for surfacing as an option.
  const desired: string[] = [
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
    exampleEs: target.exampleEs,
    exampleEn: target.exampleEn,
  };
}
