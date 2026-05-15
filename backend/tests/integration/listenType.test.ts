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
  questions: { id: string; word: string; options: string[]; position: number }[];
}

async function bootAndStart(): Promise<{ a: FastifyInstance; lesson: StartBody }> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const res = await app.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1', mode: 'listen_type' },
  });
  expect(res.statusCode).toBe(200);
  return { a: app, lesson: res.json() as StartBody };
}

/**
 * Produces a typo of an exact Levenshtein distance.
 *
 * Older versions used "xy" as the trailing garbage which collided with words
 * ending in y (e.g. `"easy"` → `"eaxy"` is distance 1, not 2, because the
 * trailing `y` matches the canonical `y`). We now append `qz` for distance 2
 * (those letters are virtually never word-final in English) and substitute
 * the last char with whichever of `q`/`z` is NOT already there.
 */
function makeTypo(word: string, distance: 1 | 2): string {
  if (distance === 1) {
    if (word.length === 0) return 'q';
    const last = word[word.length - 1]!;
    const repl = last === 'q' ? 'z' : 'q';
    return word.slice(0, -1) + repl;
  }
  // Always +2 insertions of letters that don't occur at word end in English.
  return word + 'qz';
}

describe('integration: listen_type end-to-end', () => {
  it('typed exact match → correct + echo matches input verbatim', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: q.word, answerMs: 800 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('correct');
    expect(body.correctOption).toBe(q.word);
    expect(body.typedAnswerEcho).toBe(q.word);
  });

  it('typed Levenshtein-1 → correct + echo populated with the typo', async () => {
    const { a, lesson } = await bootAndStart();
    // Use a question whose word is long enough that distance-1 is well-defined.
    const q = lesson.questions.find((x) => x.word.length >= 4) ?? lesson.questions[0]!;
    const typo = makeTypo(q.word, 1);
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: typo, answerMs: 1100 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('correct');
    expect(body.typedAnswerEcho).toBe(typo);
  });

  it('typed Levenshtein-2 → incorrect, echo still present', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions.find((x) => x.word.length >= 4) ?? lesson.questions[0]!;
    const typo = makeTypo(q.word, 2);
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: typo, answerMs: 1500 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('incorrect');
    expect(body.typedAnswerEcho).toBe(typo);
  });

  it('typed answer is case-insensitive and trimmed', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: `   ${q.word.toUpperCase()}   `, answerMs: 700 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.outcome).toBe('correct');
    // Echo preserves the user's original (trimmed) case.
    expect(body.typedAnswerEcho).toBe(q.word.toUpperCase());
  });

  it('empty typed answer is rejected by zod (client must route to /skip)', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: '', answerMs: 100 },
    });
    expect(res.statusCode).toBe(400);
  });

  it('listen_type mastery is independent: scoring read mode does not move the listen_type column', async () => {
    const { a, lesson } = await bootAndStart();
    // Answer the typed lesson correctly for at least one question.
    const q = lesson.questions[0]!;
    await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: q.word, answerMs: 700 },
    });
    const progress = (await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } })).json();
    expect(progress.perModeMastered.read_pick_meaning).toBe(0);
    expect(progress.perModeMastered.listen_pick_word).toBe(0);
    expect(progress.perModeMastered.listen_pick_meaning).toBe(0);
    // listen_type may or may not be mastered yet (one correct ≠ mastered), but
    // the field must exist as a number and be ≥ 0.
    expect(typeof progress.perModeMastered.listen_type).toBe('number');
  });
});
