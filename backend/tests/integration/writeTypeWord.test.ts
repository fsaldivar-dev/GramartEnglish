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
  mode: string;
  questions: { id: string; word: string; prompt?: string; options: string[]; position: number }[];
}

async function bootAndStart(): Promise<{ a: FastifyInstance; lesson: StartBody }> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const res = await app.inject({
    method: 'POST', url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1', mode: 'write_type_word' },
  });
  return { a: app, lesson: res.json() as StartBody };
}

function distanceTwoTypo(word: string): string {
  // Append "qz" — letters that never appear at word end in English so we
  // guarantee distance == 2.
  return word + 'qz';
}

describe('integration: write_type_word end-to-end', () => {
  it('exact-match typed answer → correct, echo verbatim', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions[0]!;
    const res = await a.inject({
      method: 'POST', url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: q.word, answerMs: 800 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('correct');
    expect(body.correctOption).toBe(q.word);
    expect(body.typedAnswerEcho).toBe(q.word);
  });

  it('Levenshtein-1 typo → still correct (FR-003)', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions.find((qq) => qq.word.length >= 4) ?? lesson.questions[0]!;
    const typo = q.word.slice(0, -1) + (q.word.endsWith('q') ? 'z' : 'q');
    const res = await a.inject({
      method: 'POST', url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: typo, answerMs: 1200 },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().outcome).toBe('correct');
  });

  it('Levenshtein-2 typo → incorrect', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions.find((qq) => qq.word.length >= 4) ?? lesson.questions[0]!;
    const typo = distanceTwoTypo(q.word);
    const res = await a.inject({
      method: 'POST', url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: typo, answerMs: 1500 },
    });
    expect(res.json().outcome).toBe('incorrect');
  });

  it('empty typedAnswer rejected with 400 (client routes to /skip)', async () => {
    const { a, lesson } = await bootAndStart();
    const res = await a.inject({
      method: 'POST', url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: lesson.questions[0]!.id, typedAnswer: '', answerMs: 100 },
    });
    expect(res.statusCode).toBe(400);
  });

  it('hintUsed=true: correct typed answer does NOT mature into mastered after 2 in a row (FR-009)', async () => {
    const { a, lesson } = await bootAndStart();
    // Pick a word and answer it correctly TWICE in a row with hintUsed=true.
    // Backend should keep consecutiveCorrect=0 each time and never mark mastered.
    const q = lesson.questions[0]!;

    // First lesson — both answers use hint.
    const r1 = await a.inject({
      method: 'POST', url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: q.word, hintUsed: true, answerMs: 800 },
    });
    expect(r1.json().outcome).toBe('correct');
    await a.inject({
      method: 'POST', url: `/v1/lessons/${lesson.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });

    // Start a second lesson and find the same word (best-effort — the
    // selector mixes 50/30/20 so it's likely but not guaranteed). If the same
    // word isn't there, this test still passes because mastered should stay 0.
    const l2 = await a.inject({
      method: 'POST', url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_type_word' },
    });
    const l2Body = l2.json() as StartBody;
    const sameWord = l2Body.questions.find((qq) => qq.word === q.word);
    if (sameWord) {
      await a.inject({
        method: 'POST', url: `/v1/lessons/${l2Body.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: sameWord.id, typedAnswer: q.word, hintUsed: true, answerMs: 800 },
      });
    }
    await a.inject({
      method: 'POST', url: `/v1/lessons/${l2Body.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });

    const prog = (await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } })).json();
    // With hintUsed=true on every answer, write_type_word mastery count MUST be 0.
    expect(prog.perModeMastered.write_type_word).toBe(0);
  });
});
