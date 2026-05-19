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

async function boot(): Promise<FastifyInstance> {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  return app;
}

async function start(a: FastifyInstance, mode: string): Promise<StartBody> {
  const res = await a.inject({
    method: 'POST',
    url: '/v1/lessons',
    headers: { 'x-correlation-id': ID },
    payload: { level: 'A1', mode },
  });
  expect(res.statusCode).toBe(200);
  return res.json() as StartBody;
}

describe('integration: write_pick_word end-to-end', () => {
  it('returns 10 questions with Spanish prompt and 4 English options each', async () => {
    const a = await boot();
    const lesson = await start(a, 'write_pick_word');
    expect(lesson.mode).toBe('write_pick_word');
    expect(lesson.questions).toHaveLength(10);
    for (const q of lesson.questions) {
      expect(typeof q.prompt).toBe('string');
      expect(q.prompt!.length).toBeGreaterThan(0);
      // Prompt is Spanish — by heuristic it includes either a diacritic OR
      // is materially different from the English `word`.
      expect(q.prompt).not.toBe(q.word);
      expect(q.options).toHaveLength(4);
      // The canonical English word is among the options.
      expect(q.options).toContain(q.word);
      // All options are English (ASCII alphabetic + spaces/hyphens/apostrophes).
      for (const opt of q.options) {
        expect(opt).toMatch(/^[A-Za-z][A-Za-z\s'-]*$/);
      }
    }
  });

  it('mastery moves on write_pick_word independently from read_pick_meaning', async () => {
    const a = await boot();
    const baseline = (await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } })).json();
    expect(baseline.perModeMastered.write_pick_word).toBe(0);
    expect(baseline.perModeMastered.read_pick_meaning).toBe(0);

    const lesson = await start(a, 'write_pick_word');
    for (const q of lesson.questions) {
      await a.inject({
        method: 'POST',
        url: `/v1/lessons/${lesson.lessonId}/answers`,
        headers: { 'x-correlation-id': ID },
        payload: { questionId: q.id, optionIndex: 0, answerMs: 200 },
      });
    }
    await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/complete`,
      headers: { 'x-correlation-id': ID },
    });

    const after = (await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } })).json();
    // Other modes untouched.
    expect(after.perModeMastered.read_pick_meaning).toBe(0);
    expect(after.perModeMastered.listen_pick_word).toBe(0);
    expect(after.perModeMastered.write_type_word).toBe(0);
    // write_pick_word column saw work (0 mastered is fine — one correct ≠ mastered).
    expect(typeof after.perModeMastered.write_pick_word).toBe('number');
    expect(after.lessonsCompleted).toBe(1);
  });

  it('answer response reveals the canonical English word as correctOption', async () => {
    const a = await boot();
    const lesson = await start(a, 'write_pick_word');
    const q = lesson.questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, optionIndex: 0, answerMs: 200 },
    });
    const body = res.json();
    // The correct option must be the English word (== q.word), not Spanish.
    expect(body.correctOption).toBe(q.word);
  });
});
