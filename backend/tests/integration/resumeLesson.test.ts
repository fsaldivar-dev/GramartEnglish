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

  it('returns mode + questions shape mirroring POST /v1/lessons', async () => {
    // F007 v1.8.0 patch (Blocker). The client's resumeLesson API decodes
    // this endpoint into the same StartLessonResponse type the lesson-start
    // call returns. Lock the field names in place.
    const s = await start();
    const res = await app!.inject({
      method: 'GET',
      url: `/v1/lessons/${s.lessonId}`,
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.lessonId).toBe(s.lessonId);
    expect(body.mode).toBe('read_pick_meaning');
    expect(Array.isArray(body.questions)).toBe(true);
    expect(body.questions.length).toBe(10);
    expect(body.questions[0]).toHaveProperty('id');
    expect(body.questions[0]).toHaveProperty('options');
  });

  it('preserves write-mode `prompt` field on resume', async () => {
    // Spanish prompt is the only thing the user sees on a write_type_word
    // question. If resume drops it, the learner is asked to type the English
    // for an invisible meaning.
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const startRes = await app.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_type_word' },
    });
    const started = startRes.json() as { lessonId: string; questions: { id: string; prompt?: string }[] };
    expect(started.questions[0]!.prompt).toBeTruthy();
    const res = await app.inject({
      method: 'GET',
      url: `/v1/lessons/${started.lessonId}`,
      headers: { 'x-correlation-id': ID },
    });
    const body = res.json();
    expect(body.mode).toBe('write_type_word');
    expect(body.questions[0].prompt).toBeTruthy();
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
