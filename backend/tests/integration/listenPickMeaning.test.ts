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

describe('integration: listen_pick_meaning end-to-end', () => {
  it('returns Spanish option text for listen_pick_meaning while listen_pick_word returns English', async () => {
    const a = await boot();

    const meaning = await start(a, 'listen_pick_meaning');
    const word = await start(a, 'listen_pick_word');

    expect(meaning.mode).toBe('listen_pick_meaning');
    expect(word.mode).toBe('listen_pick_word');

    // Build option-text alphabets. Spanish has diacritics (á é í ó ú ñ ü ¡ ¿)
    // that don't appear in pure English text; English options for the A1
    // corpus are alphabetic + spaces/hyphens. We can't strictly partition the
    // two but we can sanity-check that at least ONE Spanish option contains a
    // diacritic and that all English option words are ASCII.
    const spanishHasDiacritic = meaning.questions
      .flatMap((q) => q.options)
      .some((opt) => /[áéíóúñü¡¿Á-ÚÑÜ]/.test(opt));
    expect(spanishHasDiacritic).toBe(true);

    for (const q of word.questions) {
      for (const opt of q.options) {
        expect(opt).toMatch(/^[A-Za-z][A-Za-z\s'-]*$/);
      }
    }
  });

  it('mode-specific mastery progresses independently from listen_pick_word', async () => {
    const a = await boot();
    const lesson = await start(a, 'listen_pick_meaning');
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

    const prog = (await a.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } })).json();
    // Other modes must remain at 0 — this is the per-(word, mode) mastery invariant.
    expect(prog.perModeMastered.read_pick_meaning).toBe(0);
    expect(prog.perModeMastered.listen_pick_word).toBe(0);
    expect(prog.perModeMastered.listen_type).toBe(0);
    expect(typeof prog.perModeMastered.listen_pick_meaning).toBe('number');
    expect(prog.lessonsCompleted).toBe(1);
  });

  it('answer response reveals the Spanish meaning as correctOption', async () => {
    const a = await boot();
    const lesson = await start(a, 'listen_pick_meaning');
    const q = lesson.questions[0]!;
    const res = await a.inject({
      method: 'POST',
      url: `/v1/lessons/${lesson.lessonId}/answers`,
      headers: { 'x-correlation-id': ID },
      payload: { questionId: q.id, optionIndex: 0, answerMs: 200 },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    // The correctOption must be one of the options shown (Spanish),
    // NOT the English canonical word.
    expect(q.options).toContain(body.correctOption);
    expect(body.correctOption).not.toBe(q.word);
  });
});
