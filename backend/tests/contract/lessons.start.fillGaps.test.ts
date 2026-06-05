import { describe, it, expect, afterEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';

let app: FastifyInstance | undefined;

afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

describe('POST /v1/lessons — write_fill_gaps (v1.5 contract)', () => {
  // QA flagged that the previous version of this test only verified the
  // mask path — it never proved the ≤3-letter auto-promotion branch was
  // actually exercised, because A1 deck composition is probabilistic.
  // We now drive the route with deterministic seeds and assert BOTH branches
  // are observed: at least one long word with a maskedWord AND at least
  // one ≤3-letter word that auto-promoted (no maskedWord, wire mode
  // still `write_fill_gaps`).
  it('returns maskedWord for long words AND deterministically exercises ≤3-letter auto-promotion', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;

    type Body = {
      lessonId: string;
      mode: string;
      questions: Array<{ id: string; word: string; prompt?: string; maskedWord?: string }>;
    };

    // Probe a small deterministic sequence of seeds until we land on a deck
    // that contains at least one ≤3-letter word from the A1 corpus. The A1
    // pool has 10 short words out of 50, so a short-bearing seed is found
    // within the first handful of attempts. The chosen seed is recorded in
    // the assertion message so future failures are easy to bisect.
    let body: Body | undefined;
    let chosenSeed = -1;
    for (const seed of [5, 14, 18, 9, 10, 6, 3, 1, 2, 7, 8, 11, 12, 13, 15, 17, 19, 20]) {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/lessons',
        headers: { 'x-correlation-id': ID },
        payload: { level: 'A1', mode: 'write_fill_gaps', seed },
      });
      expect(res.statusCode).toBe(200);
      const parsed = res.json() as Body;
      if (parsed.questions.some((q) => q.word.length <= 3)) {
        body = parsed;
        chosenSeed = seed;
        break;
      }
    }
    expect(body, 'no A1 seed in the probe set yielded a ≤3-letter word').toBeDefined();
    const lesson = body!;

    expect(lesson.mode).toBe('write_fill_gaps');
    expect(lesson.questions).toHaveLength(10);

    let longSeen = 0;
    let shortSeen = 0;
    for (const q of lesson.questions) {
      expect(typeof q.prompt).toBe('string');
      if (q.word.length <= 3) {
        shortSeen += 1;
        // Auto-promoted by the gap masker — server omits maskedWord, but
        // the wire mode echoes back as `write_fill_gaps` so the client
        // routes the question through the same lesson screen (the
        // promotion is server-side and opaque, FR-007).
        expect(q.maskedWord, `seed=${chosenSeed} word=${q.word}`).toBeUndefined();
      } else {
        longSeen += 1;
        expect(typeof q.maskedWord).toBe('string');
        const masked = q.maskedWord!;
        // First letter preserved.
        expect(masked[0]).toBe(q.word[0]);
        // Contains at least one underscore (gap).
        expect(masked).toContain('_');
        // Same length as the original word.
        expect(masked.length).toBe(q.word.length);
        // Non-underscore positions match the original letters at those indices.
        for (let i = 0; i < masked.length; i += 1) {
          if (masked[i] !== '_') {
            expect(masked[i]).toBe(q.word[i]);
          }
        }
      }
    }
    // Both branches must be observed within the same lesson.
    expect(longSeen, `seed=${chosenSeed}`).toBeGreaterThan(0);
    expect(shortSeen, `seed=${chosenSeed} — auto-promotion branch not exercised`).toBeGreaterThan(0);
  });
});
