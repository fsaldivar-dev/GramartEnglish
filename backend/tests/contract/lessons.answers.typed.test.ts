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

interface StartedQuestion {
  id: string;
  word: string;
  options: string[];
  position: number;
}

async function startListenType(a: FastifyInstance): Promise<{ lessonId: string; questions: StartedQuestion[] }> {
  const res = await a.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1', mode: 'listen_type' },
  });
  expect(res.statusCode).toBe(200);
  return res.json();
}

describe('POST /v1/lessons/:id/answers — typed (listen_type)', () => {
  it('exact match (case-insensitive, trimmed) → correct + echoes the typed answer', async () => {
    const a = await setup();
    const { lessonId, questions } = await startListenType(a);
    const q = questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: `  ${q.word.toUpperCase()}  `, answerMs: 1500 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('correct');
    expect(body.correctOption).toBe(q.word);
    // Echo preserves the user's original (trimmed) input — including case.
    expect(body.typedAnswerEcho).toBe(q.word.toUpperCase());
  });

  it('typo within Levenshtein 1 → correct + echo populated', async () => {
    const a = await setup();
    const { lessonId, questions } = await startListenType(a);
    // Find a question whose word has at least 4 chars so a 1-substitution typo is well-defined.
    const q = questions.find((qq) => qq.word.length >= 4) ?? questions[0]!;
    const typo = q.word.slice(0, -1) + 'z'; // distance 1 substitution at the last char
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: typo, answerMs: 1500 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('correct');
    expect(body.typedAnswerEcho).toBe(typo);
  });

  it('distance ≥ 2 → incorrect, echo still populated', async () => {
    const a = await setup();
    const { lessonId, questions } = await startListenType(a);
    const q = questions[0]!;
    const garbage = 'xxxxxxxxxx'; // very far from any real word
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: garbage, answerMs: 1500 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('incorrect');
    expect(body.typedAnswerEcho).toBe(garbage);
  });

  it('400s when both optionIndex and typedAnswer are provided', async () => {
    const a = await setup();
    const { lessonId, questions } = await startListenType(a);
    const q = questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, optionIndex: 0, typedAnswer: q.word, answerMs: 1000 },
    });
    expect(res.statusCode).toBe(400);
  });

  it('400s when neither optionIndex nor typedAnswer is provided', async () => {
    const a = await setup();
    const { lessonId, questions } = await startListenType(a);
    const q = questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, answerMs: 1000 },
    });
    expect(res.statusCode).toBe(400);
  });
});
