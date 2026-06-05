import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { VerbRepository } from '../store/verbRepository.js';

const Params = z.object({
  base: z.string().min(1).max(32).regex(/^[a-z]+$/),
});

export interface VerbRouteDeps {
  /** Loaded once at boot from the corpus directory. When undefined (tests that
   *  skip corpus bootstrap), every /intro request returns 404. */
  verbs: VerbRepository | undefined;
}

/**
 * F006 (v1.7.0): `GET /v1/verbs/:base/intro`.
 *
 * Returns the pre-conjugation micro-card payload for the "Conoce el verbo"
 * scaffolding (specs/006-verb-intro-card/). The card is shown on the client
 * exactly once per (macInstall, verbBase) — see VerbIntroSeenStore. The server
 * is stateless about that flag; clients gate calls themselves.
 *
 * Why both `exampleEs` and `exampleEsFilled`?
 * - The conjugation question reuses the unfilled `exampleEs` (with `___`) so
 *   the learner has to commit to a tense. The intro card shows the
 *   already-substituted `exampleEsFilled` to ground meaning without showing a
 *   literal gap on a teaching surface (v1.7.0 patch). Both fields come from
 *   verbs.json — the filled form is hand-curated per verb because
 *   algorithmic Spanish preterite conjugation is too unreliable.
 */
export async function registerVerbRoutes(app: FastifyInstance, deps: VerbRouteDeps): Promise<void> {
  app.get('/v1/verbs/:base/intro', async (req, reply) => {
    const parsed = Params.safeParse(req.params);
    if (!parsed.success) {
      return reply.code(400).send({ code: 'invalid_payload', message: parsed.error.message });
    }
    const row = deps.verbs?.lookupByBase(parsed.data.base);
    if (!row) {
      return reply.code(404).send({ code: 'verb_not_found', message: `unknown verb base: ${parsed.data.base}` });
    }
    // v1.7.0 patch (F006 Blocker 1): the intro card uses `exampleEsFilled`
    // (Spanish past form substituted into the slot) — Marisol read the
    // bare `___` as a literal error on a teaching surface. The unfilled
    // `exampleEs` is still returned so any downstream consumer that needs
    // the gap shape (currently none for /intro, but conjugation drills
    // reuse the same row through verbConjugationBuilder) has it. The
    // English line continues to show the fully conjugated translation.
    req.log.info({ verbBase: row.base }, 'verb.intro.fetched');
    return {
      base: row.base,
      es: row.es,
      exampleEs: row.exampleEs,
      exampleEsFilled: row.exampleEsFilled,
      exampleEn: row.exampleEn,
      audioBase: row.audioBase,
    };
  });
}
