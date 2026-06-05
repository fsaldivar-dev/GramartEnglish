import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import { _resetPlacementStoreForTests } from '../../src/routes/placement.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';
const ADAPTIVE_HEADERS = {
  'x-correlation-id': ID,
  'x-client-version': '1.4.0',
  'content-type': 'application/json',
};

let app: FastifyInstance | undefined;

beforeEach(() => _resetPlacementStoreForTests());
afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

interface AdaptiveStartResponse {
  placementId: string;
  question: { id: string; word: string; options: string[]; level: string };
  progress: { current: number; max: number };
  algorithmVersion: 'v2';
}

async function startAdaptive(): Promise<AdaptiveStartResponse> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const res = await app.inject({
    method: 'POST',
    url: '/v1/placement/start',
    headers: ADAPTIVE_HEADERS,
    payload: { seed: 1, selfReport: 'never' },
  });
  expect(res.statusCode).toBe(200);
  return res.json() as AdaptiveStartResponse;
}

describe('POST /v1/placement/answer (adaptive v2)', () => {
  it('returns kind=continue with the next question after a non-terminal answer', async () => {
    const start = await startAdaptive();
    const ans = await app!.inject({
      method: 'POST',
      url: '/v1/placement/answer',
      headers: ADAPTIVE_HEADERS,
      payload: { placementId: start.placementId, questionId: start.question.id, optionIndex: 0 },
    });
    expect(ans.statusCode).toBe(200);
    const body = ans.json() as { kind: string; question?: { id: string }; progress?: { current: number } };
    expect(body.kind).toBe('continue');
    expect(body.question?.id).toBeTruthy();
    expect(body.progress?.current).toBe(2);
  });

  it('accepts optionIndex=-1 ("no lo sé") and treats it as incorrect', async () => {
    const start = await startAdaptive();
    const ans = await app!.inject({
      method: 'POST',
      url: '/v1/placement/answer',
      headers: ADAPTIVE_HEADERS,
      payload: { placementId: start.placementId, questionId: start.question.id, optionIndex: -1 },
    });
    expect(ans.statusCode).toBe(200);
    const body = ans.json() as { kind: string };
    expect(['continue', 'done']).toContain(body.kind);
  });

  it('404s on unknown placementId', async () => {
    await startAdaptive();
    const res = await app!.inject({
      method: 'POST',
      url: '/v1/placement/answer',
      headers: ADAPTIVE_HEADERS,
      payload: {
        placementId: '99999999-9999-4999-8999-999999999999',
        questionId: '99999999-9999-4999-8999-999999999999',
        optionIndex: 0,
      },
    });
    expect(res.statusCode).toBe(404);
  });

  it('400s on malformed payload', async () => {
    await startAdaptive();
    const res = await app!.inject({
      method: 'POST',
      url: '/v1/placement/answer',
      headers: ADAPTIVE_HEADERS,
      payload: { placementId: 'not-a-uuid', questionId: 'nope', optionIndex: 99 },
    });
    expect(res.statusCode).toBe(400);
  });

  it('eventually finishes with kind=done and a full result envelope', async () => {
    const start = await startAdaptive();
    let nextQuestionId = start.question.id;
    const placementId = start.placementId;
    let finalBody: { kind: string; result?: unknown } | null = null;
    // Answer -1 every time (all misses) to hit either the floor lock-in or max items.
    for (let i = 0; i < 35; i += 1) {
      const ans = await app!.inject({
        method: 'POST',
        url: '/v1/placement/answer',
        headers: ADAPTIVE_HEADERS,
        payload: { placementId, questionId: nextQuestionId, optionIndex: -1 },
      });
      expect(ans.statusCode).toBe(200);
      const body = ans.json() as { kind: string; question?: { id: string }; result?: unknown };
      if (body.kind === 'done') {
        finalBody = body;
        break;
      }
      nextQuestionId = body.question!.id;
    }
    expect(finalBody).not.toBeNull();
    const result = finalBody!.result as {
      estimatedLevel: string;
      algorithmVersion: string;
      itemsAdministered: number;
      perLevelScores: Record<string, { attempted: number; correct: number }>;
    };
    expect(result.algorithmVersion).toBe('v2');
    expect(result.itemsAdministered).toBeGreaterThan(0);
    expect(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']).toContain(result.estimatedLevel);
    // All-wrong with selfReport=never should bottom out at A1.
    expect(result.estimatedLevel).toBe('A1');
  });
});
