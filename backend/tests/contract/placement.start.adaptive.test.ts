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

beforeEach(() => _resetPlacementStoreForTests());
afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

describe('POST /v1/placement/start with x-client-version: 1.4', () => {
  it('returns a single question + progress + algorithmVersion=v2', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/start',
      headers: { 'x-correlation-id': ID, 'x-client-version': '1.4.0', 'content-type': 'application/json' },
      payload: { seed: 1, selfReport: 'some' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as {
      placementId: string;
      question: { id: string; word: string; options: string[]; level: string };
      progress: { current: number; max: number };
      algorithmVersion: string;
    };
    expect(typeof body.placementId).toBe('string');
    expect(body.question).toBeTruthy();
    expect(body.question.options).toHaveLength(4);
    expect(body.progress).toEqual({ current: 1, max: 30 });
    expect(body.algorithmVersion).toBe('v2');
  });

  it('respects selfReport=never by sampling first question near A1/A2', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/start',
      headers: { 'x-correlation-id': ID, 'x-client-version': '1.4.0', 'content-type': 'application/json' },
      payload: { seed: 1, selfReport: 'never' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as { question: { level: string } };
    expect(['A1', 'A2']).toContain(body.question.level);
  });

  it('still returns 24-question legacy shape when x-client-version is absent', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/placement/start',
      headers: { 'x-correlation-id': ID, 'content-type': 'application/json' },
      payload: { seed: 1 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as { questions?: unknown[]; question?: unknown };
    expect(body.questions).toHaveLength(24);
    expect(body.question).toBeUndefined();
  });
});
