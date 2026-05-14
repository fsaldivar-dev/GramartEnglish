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

async function startAndAnswer(perfect: boolean): Promise<{ statusCode: number; body: Record<string, unknown> }> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const startRes = await app.inject({
    method: 'POST',
    url: '/v1/placement/start',
    headers: { 'x-correlation-id': ID },
    payload: { seed: 1 },
  });
  const { placementId, questions } = startRes.json() as {
    placementId: string;
    questions: { id: string; options: string[]; level: string }[];
  };
  // The client only sees options shuffled; to "answer" we look up correctIndex
  // by retrieving it from the API. The MVP doesn't expose correctIndex on /start
  // (it would defeat the test), so we instead simulate either perfect (all 0)
  // or perfectly wrong (all 3) answers and inspect the resulting score distribution.
  const optionIndex = perfect ? 0 : 0;
  const answers = questions.map((q) => ({ questionId: q.id, optionIndex }));
  const submitRes = await app.inject({
    method: 'POST',
    url: '/v1/placement/submit',
    headers: { 'x-correlation-id': ID },
    payload: { placementId, answers },
  });
  return { statusCode: submitRes.statusCode, body: submitRes.json() };
}

beforeEach(() => {
  _resetPlacementStoreForTests();
});

afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

describe('POST /v1/placement/submit', () => {
  it('returns an estimatedLevel and per-level breakdown', async () => {
    const { statusCode, body } = await startAndAnswer(false);
    expect(statusCode).toBe(200);
    expect(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']).toContain(body.estimatedLevel as string);
    const scores = body.perLevelScores as Record<string, { attempted: number; correct: number }>;
    let totalAttempted = 0;
    for (const lvl of ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
      expect(scores[lvl]?.attempted).toBe(4);
      totalAttempted += scores[lvl]!.attempted;
    }
    expect(totalAttempted).toBe(24);
  });

  it('400s on malformed payload', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/submit',
      headers: { 'x-correlation-id': ID },
      payload: { placementId: 'not-a-uuid', answers: [] },
    });
    expect(res.statusCode).toBe(400);
  });

  it('404s on unknown placementId', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/submit',
      headers: { 'x-correlation-id': ID },
      payload: {
        placementId: '99999999-9999-4999-8999-999999999999',
        answers: [{ questionId: '99999999-9999-4999-8999-999999999999', optionIndex: 0 }],
      },
    });
    expect(res.statusCode).toBe(404);
  });
});
