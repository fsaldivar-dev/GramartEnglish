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

async function setup(): Promise<FastifyInstance> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  return app;
}

describe('POST /v1/lessons — write modes (v1.3 contract)', () => {
  it('write_pick_word: response includes prompt + English options', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'POST', url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_pick_word' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as { lessonId: string; mode: string; questions: Array<{ id: string; word: string; prompt?: string; options: string[] }> };
    expect(body.mode).toBe('write_pick_word');
    expect(body.questions).toHaveLength(10);
    for (const q of body.questions) {
      expect(typeof q.prompt).toBe('string');
      expect(q.prompt!.length).toBeGreaterThan(0);
      expect(q.options).toHaveLength(4);
      // The canonical English word IS one of the options.
      expect(q.options).toContain(q.word);
    }
  });

  it('write_type_word: response includes prompt; options exist but client ignores them', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'POST', url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_type_word' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.mode).toBe('write_type_word');
    for (const q of body.questions) {
      expect(typeof q.prompt).toBe('string');
      expect(q.prompt.length).toBeGreaterThan(0);
    }
  });

  it('AnswerRequest accepts hintUsed boolean alongside optionIndex or typedAnswer', async () => {
    const a = await setup();
    const start = await a.inject({
      method: 'POST', url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_pick_word' },
    });
    const body = start.json() as { lessonId: string; questions: Array<{ id: string }> };
    const q = body.questions[0]!;
    const res = await a.inject({
      method: 'POST', url: `/v1/lessons/${body.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, optionIndex: 0, hintUsed: false, answerMs: 800 },
    });
    expect(res.statusCode).toBe(200);
  });

  it('AnswerRequest with both hintUsed and typedAnswer also accepted', async () => {
    const a = await setup();
    const start = await a.inject({
      method: 'POST', url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_type_word' },
    });
    const body = start.json() as { lessonId: string; questions: Array<{ id: string; word: string }> };
    const q = body.questions[0]!;
    const res = await a.inject({
      method: 'POST', url: `/v1/lessons/${body.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: q.word, hintUsed: true, answerMs: 1200 },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().outcome).toBe('correct');
  });
});
