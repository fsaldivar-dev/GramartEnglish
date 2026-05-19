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

async function start(): Promise<{ lessonId: string; questions: { id: string }[] }> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const res = await app.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1' },
  });
  return res.json() as { lessonId: string; questions: { id: string }[] };
}

describe('GET /v1/lessons/{id}', () => {
  it('returns remaining questions for an in-progress lesson', async () => {
    const start1 = await start();
    // Answer first 3 questions
    for (let i = 0; i < 3; i += 1) {
      await app!.inject({
        method: 'POST',
        url: `/v1/lessons/${start1.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: start1.questions[i]!.id, optionIndex: 0, answerMs: 100 },
      });
    }
    const res = await app!.inject({
      method: 'GET',
      url: `/v1/lessons/${start1.lessonId}`,
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.state).toBe('in_progress');
    expect(body.answeredCount).toBe(3);
    expect(body.totalCount).toBe(10);
    expect(body.remaining).toHaveLength(7);
  });

  it('returns the summary for a completed lesson', async () => {
    const s = await start();
    for (const q of s.questions) {
      await app!.inject({
        method: 'POST',
        url: `/v1/lessons/${s.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: q.id, optionIndex: 0, answerMs: 100 },
      });
    }
    await app!.inject({
      method: 'POST',
      url: `/v1/lessons/${s.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });
    const res = await app!.inject({
      method: 'GET',
      url: `/v1/lessons/${s.lessonId}`,
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.state).toBe('completed');
    expect(body.total).toBe(10);
  });

  it('404s for an unknown lesson', async () => {
    await start();
    const res = await app!.inject({
      method: 'GET',
      url: '/v1/lessons/99999999-9999-4999-8999-999999999999',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(404);
  });
});
