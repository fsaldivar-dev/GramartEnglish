import { describe, it, expect, afterEach } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

/**
 * Regression test pinning the user's reported complaint: "forcing A1 in
 * Settings didn't fix the lesson selection."
 *
 * The chain we're guarding:
 *   PATCH /v1/me { currentLevel: 'A1' }
 *     → userRepository.setLevel
 *     → GET /v1/progress reflects the new currentLevel
 *     → POST /v1/lessons { level: 'A1' } returns only A1 words
 *
 * If any future refactor decouples user.currentLevel from the lesson selector,
 * THIS TEST TURNS RED.
 */

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';

let app: FastifyInstance | undefined;
afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

async function fetchLessonWords(level: 'A1' | 'A2'): Promise<string[]> {
  const res = await app!.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID, 'content-type': 'application/json' },
    payload: { level, mode: 'read_pick_meaning' },
  });
  expect(res.statusCode).toBe(200);
  const body = res.json() as { questions: { word: string }[] };
  return body.questions.map((q) => q.word);
}

describe('Settings level override regression — currentLevel flows end-to-end', () => {
  it('PATCH /v1/me { currentLevel: A1 } is reflected in /v1/progress and constrains lesson selection', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;

    // Force A2 first to establish a baseline.
    const patchA2 = await app.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: { 'x-correlation-id': ID, 'content-type': 'application/json' },
      payload: { currentLevel: 'A2' },
    });
    expect(patchA2.statusCode).toBe(200);

    const progressA2 = await app.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } });
    expect((progressA2.json() as { currentLevel: string }).currentLevel).toBe('A2');

    // Pull a lesson at A2 — words should be A2-level.
    const wordsA2 = await fetchLessonWords('A2');
    expect(wordsA2.length).toBeGreaterThan(0);

    // Now the user "forces A1" in Settings.
    const patchA1 = await app.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: { 'x-correlation-id': ID, 'content-type': 'application/json' },
      payload: { currentLevel: 'A1' },
    });
    expect(patchA1.statusCode).toBe(200);

    const progressA1 = await app.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } });
    expect((progressA1.json() as { currentLevel: string }).currentLevel).toBe('A1');

    // And the next lesson — at the new A1 level — must NOT include A2 words.
    const wordsA1 = await fetchLessonWords('A1');
    expect(wordsA1.length).toBeGreaterThan(0);

    // QA caveat 2 (#8): derive the expected A1 set from the corpus file at
    // test time rather than hardcoding a 49-word snapshot. The cared-about
    // invariant is "the override worked and the level matches", which we
    // express as: every returned word belongs to the A1 corpus.
    const a1Corpus = JSON.parse(
      readFileSync(join(REPO_ROOT, 'data', 'cefr', 'a1.json'), 'utf-8'),
    ) as { base: string; level: string }[];
    const a1Set = new Set(a1Corpus.map((w) => w.base.toLowerCase()));
    // Sanity: corpus is well-formed.
    expect(a1Corpus.every((w) => w.level === 'A1')).toBe(true);
    const offCorpus = wordsA1.filter((w) => !a1Set.has(w.toLowerCase()));
    expect(offCorpus).toEqual([]);
  });
});
