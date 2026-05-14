import { describe, it, expect, afterEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../../src/server.js';
import { RecordedFakeLlm } from '../../../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';

let app: FastifyInstance | undefined;

afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

async function setup() {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  return app;
}

describe('GET /v1/progress', () => {
  it('returns zeros and null lastLesson on a fresh user', async () => {
    const a = await setup();
    const res = await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.lessonsCompleted).toBe(0);
    expect(body.masteredCount).toBe(0);
    expect(body.toReviewCount).toBe(0);
    expect(body.lastLesson).toBeNull();
    expect(body.resumable).toBeNull();
  });

  it('reports a resumable in-progress lesson', async () => {
    const a = await setup();
    const start = await a.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1' },
    });
    const lesson = start.json() as { lessonId: string; questions: { id: string }[] };
    await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: lesson.questions[0]!.id, optionIndex: 0, answerMs: 100 },
    });
    const res = await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } });
    const body = res.json();
    expect(body.resumable).not.toBeNull();
    expect(body.resumable.lessonId).toBe(lesson.lessonId);
    expect(body.resumable.answeredCount).toBe(1);
    expect(body.resumable.totalCount).toBe(10);
  });

  it('reports lastLesson + lessonsCompleted after completing a lesson', async () => {
    const a = await setup();
    const start = await a.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1' },
    });
    const lesson = start.json() as { lessonId: string; questions: { id: string }[] };
    for (const q of lesson.questions) {
      await a.inject({
        method: 'POST',
        url: `/v1/lessons/${lesson.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: q.id, optionIndex: 0, answerMs: 100 },
      });
    }
    await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });
    const res = await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } });
    const body = res.json();
    expect(body.lessonsCompleted).toBe(1);
    expect(body.lastLesson).not.toBeNull();
    expect(body.lastLesson.total).toBe(10);
  });
});
