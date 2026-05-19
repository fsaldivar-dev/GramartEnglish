import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import { _resetPlacementStoreForTests } from '../../src/routes/placement.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';

let app: FastifyInstance | undefined;

beforeEach(() => {
  _resetPlacementStoreForTests();
});

afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

describe('POST /v1/placement/start', () => {
  it('returns a placementId and 24 sentence-context questions covering all CEFR levels', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/start',
      headers: { 'x-correlation-id': ID, 'content-type': 'application/json' },
      payload: { seed: 1 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(typeof body.placementId).toBe('string');
    expect(body.questions).toHaveLength(24);
    const levels = new Set<string>(body.questions.map((q: { level: string }) => q.level));
    expect(levels.size).toBe(6);
    for (const q of body.questions) {
      expect(q.options).toHaveLength(4);
      expect(typeof q.sentence).toBe('string');
      // Each sentence should contain the target word (case-insensitive) when present.
      if (q.sentence) {
        expect(q.sentence.toLowerCase()).toContain((q.word as string).toLowerCase());
      }
    }
  });

  it('echoes the correlation id on the response', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/start',
      headers: { 'x-correlation-id': ID },
      payload: {},
    });
    expect(res.headers['x-correlation-id']).toBe(ID);
  });
});
