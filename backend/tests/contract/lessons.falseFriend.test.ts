import { describe, it, expect, afterEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

/**
 * F008 Item 3 (v1.9.0). When a lesson at level A2 surfaces a belt word
 * (e.g. "library"), the API response's question record carries the
 * `falseFriendEs` string. The vast majority of words are not belt
 * entries, so we keep starting lessons until we hit one to assert on —
 * `library`, `exit`, `success`, `carpet`, `fabric` all sit at A2.
 */

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';

let app: FastifyInstance | undefined;

afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

async function setup(): Promise<FastifyInstance> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  return app;
}

describe('POST /v1/lessons — F008 falseFriendEs propagation', () => {
  it('attaches falseFriendEs to questions whose target word is on the belt', async () => {
    const a = await setup();
    // The selector is seeded but the belt entries are a small fraction of
    // the A2 pool; run a handful of lessons and assert that at least one
    // surfaces a belt word with a populated false-friend string.
    let found = false;
    for (let i = 0; i < 20 && !found; i += 1) {
      const res = await a.inject({
        method: 'POST',
        url: '/v1/lessons',
        headers: { 'x-correlation-id': ID },
        payload: { level: 'A2', mode: 'read_pick_meaning' },
      });
      expect(res.statusCode).toBe(200);
      const beltWords = new Set(['library', 'exit', 'success', 'carpet', 'fabric']);
      for (const q of res.json().questions as Array<{ word: string; falseFriendEs?: string }>) {
        if (beltWords.has(q.word)) {
          expect(q.falseFriendEs).toBeDefined();
          expect(q.falseFriendEs!.length).toBeGreaterThan(0);
          // Belt copy contract: every entry opens with "OJO" so it lands
          // as Lucía specified (smoke test for downstream JSON / DB
          // truncation regressions).
          expect(q.falseFriendEs!.startsWith('OJO')).toBe(true);
          found = true;
          break;
        }
      }
    }
    expect(found).toBe(true);
  });

  it('omits falseFriendEs for questions whose target word is not on the belt', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'read_pick_meaning' },
    });
    expect(res.statusCode).toBe(200);
    // A1 has no belt entries; every question must omit the field (or set
    // it to undefined which JSON.stringify drops).
    for (const q of res.json().questions as Array<{ word: string; falseFriendEs?: string }>) {
      expect(q.falseFriendEs).toBeUndefined();
    }
  });
});
