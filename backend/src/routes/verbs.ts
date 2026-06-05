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
 * Why server-side slot-fill of exampleEs?
 * - The conjugation question reuses the unfilled `example_es` (with `___`) so
 *   the learner has to commit to a tense. The intro card shows the answer in
 *   context to ground meaning. Doing the substitution here means the client
 *   never holds the two variants — one trip, one DTO.
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
    // The intro pairs the Spanish prompt (with `___` slot still visible) with
    // the fully-conjugated English translation. The blank doubles as visual
    // foreshadowing of the question shape the learner will see next, and
    // avoids the awkward mixed-language artifact of slotting an English form
    // into a Spanish sentence.
    req.log.info({ verbBase: row.base }, 'verb.intro.fetched');
    return {
      base: row.base,
      es: row.es,
      exampleEs: row.exampleEs,
      exampleEn: row.exampleEn,
      audioBase: row.audioBase,
    };
  });
}
