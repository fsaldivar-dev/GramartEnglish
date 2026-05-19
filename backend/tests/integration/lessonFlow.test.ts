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

interface StartBody {
  lessonId: string;
  questions: { id: string; word: string; options: string[]; position: number }[];
}

async function start(): Promise<StartBody> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const res = await app.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1' },
  });
  expect(res.statusCode).toBe(200);
  return res.json() as StartBody;
}

describe('lesson flow', () => {
  it('POST /v1/lessons creates a 10-question lesson at the given level', async () => {
    const body = await start();
    expect(body.questions).toHaveLength(10);
    for (const q of body.questions) expect(q.options).toHaveLength(4);
  });

  it('POST /v1/lessons/{id}/answers returns outcome, correctIndex, correctOption, definition', async () => {
    const body = await start();
    const q = body.questions[0]!;
    const res = await app!.inject({
      method: 'POST',
      url: `/v1/lessons/${body.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, optionIndex: 0, answerMs: 1234 },
    });
    expect(res.statusCode).toBe(200);
    const data = res.json();
    expect(['correct', 'incorrect']).toContain(data.outcome);
    expect(data.correctIndex).toBeGreaterThanOrEqual(0);
    expect(data.correctIndex).toBeLessThanOrEqual(3);
    expect(typeof data.correctOption).toBe('string');
    expect(typeof data.canonicalDefinition).toBe('string');
  });

  it('POST /v1/lessons/{id}/skip records a skip with outcome=skipped', async () => {
    const body = await start();
    const q = body.questions[0]!;
    const res = await app!.inject({
      method: 'POST',
      url: `/v1/lessons/${body.lessonId}/skip`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, answerMs: 500 },
    });
    expect(res.statusCode).toBe(200);
    const data = res.json();
    expect(data.outcome).toBe('skipped');
    expect(data.correctIndex).toBeGreaterThanOrEqual(0);
    expect(typeof data.correctOption).toBe('string');
  });

  it('summary distinguishes wrong from skipped', async () => {
    const body = await start();
    // Answer first 3 with option 0 (random correctness), skip next 2, answer rest.
    for (let i = 0; i < 3; i += 1) {
      await app!.inject({
        method: 'POST',
        url: `/v1/lessons/${body.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: body.questions[i]!.id, optionIndex: 0, answerMs: 100 },
      });
    }
    for (let i = 3; i < 5; i += 1) {
      await app!.inject({
        method: 'POST',
        url: `/v1/lessons/${body.lessonId}/skip`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: body.questions[i]!.id, answerMs: 100 },
      });
    }
    for (let i = 5; i < 10; i += 1) {
      await app!.inject({
        method: 'POST',
        url: `/v1/lessons/${body.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: body.questions[i]!.id, optionIndex: 0, answerMs: 100 },
      });
    }
    const res = await app!.inject({
      method: 'POST',
      url: `/v1/lessons/${body.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });
    const s = res.json();
    expect(s.total).toBe(10);
    expect(s.skipped).toBe(2);
    expect(s.score + s.wrong + s.skipped).toBe(10);
  });

  it('POST /v1/lessons/{id}/complete returns score and missed words', async () => {
    const body = await start();
    // Answer all with option 0 (random correctness).
    for (const q of body.questions) {
      await app!.inject({
        method: 'POST',
        url: `/v1/lessons/${body.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: q.id, optionIndex: 0, answerMs: 500 },
      });
    }
    const res = await app!.inject({
      method: 'POST',
      url: `/v1/lessons/${body.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const summary = res.json();
    expect(summary.lessonId).toBe(body.lessonId);
    expect(summary.total).toBe(10);
    expect(summary.score).toBeGreaterThanOrEqual(0);
    expect(summary.score).toBeLessThanOrEqual(10);
    expect(Array.isArray(summary.missedWords)).toBe(true);
  });

  it('400s on invalid answer payload', async () => {
    const body = await start();
    const res = await app!.inject({
      method: 'POST',
      url: `/v1/lessons/${body.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: 'nope', optionIndex: 0, answerMs: 0 },
    });
    expect(res.statusCode).toBe(400);
  });
});
