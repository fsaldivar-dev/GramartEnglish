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
  questions: { id: string; word: string; prompt?: string; maskedWord?: string; options: string[]; position: number }[];
}

async function bootAndStart(): Promise<{ a: FastifyInstance; lesson: StartBody }> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  const res = await app.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1', mode: 'write_fill_gaps' },
  });
  return { a: app, lesson: res.json() as StartBody };
}

describe('integration: write_fill_gaps end-to-end (FR-007 per-mode mastery axis)', () => {
  it('correct + incorrect typed answers update the write_fill_gaps mastery axis independently', async () => {
    const { a, lesson } = await bootAndStart();
    const q = lesson.questions[0]!;

    // Correct typed answer (matches canonical English regardless of mask).
    const okRes = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, typedAnswer: q.word, answerMs: 900 },
    });
    expect(okRes.statusCode).toBe(200);
    expect(okRes.json().outcome).toBe('correct');

    // Wrong typed answer on the next question (distance >> 1).
    const q2 = lesson.questions[1]!;
    const wrongRes = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q2.id, typedAnswer: 'zzzz', answerMs: 1100 },
    });
    expect(wrongRes.json().outcome).toBe('incorrect');

    await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });

    const prog = (await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } })).json();
    // write_fill_gaps appears in perModeMastered keyset (now part of SHIPPED_MODES).
    expect(prog.perModeMastered).toHaveProperty('write_fill_gaps');
    // Mastery axis is independent: other axes stay at 0 after a single write_fill_gaps lesson.
    expect(prog.perModeMastered.read_pick_meaning).toBe(0);
    expect(prog.perModeMastered.write_type_word).toBe(0);
  });
});
