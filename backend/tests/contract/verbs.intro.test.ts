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

describe('GET /v1/verbs/:base/intro (F006)', () => {
  it('returns 200 with the full intro payload for a known verb', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'GET',
      url: '/v1/verbs/go/intro',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.base).toBe('go');
    expect(body.es).toBe('ir');
    // exampleEs keeps its `___` slot — the intro card pairs Spanish prompt
    // shape with the fully-conjugated English translation. The slot is the
    // visual foreshadowing of the coming question.
    expect(typeof body.exampleEs).toBe('string');
    expect(body.exampleEs).toContain('___');
    expect(body.exampleEs.toLowerCase()).toContain('ayer');
    expect(typeof body.exampleEn).toBe('string');
    expect(body.exampleEn.toLowerCase()).toContain('went');
    expect(body.audioBase).toBe('go.mp3');
  });

  it('returns 404 with a typed error body for an unknown verb', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'GET',
      url: '/v1/verbs/zzznotaverb/intro',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(404);
    const body = res.json();
    expect(body.code).toBe('verb_not_found');
    expect(typeof body.message).toBe('string');
  });

  it('rejects malformed base (uppercase / non-alpha)', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'GET',
      url: '/v1/verbs/GO/intro',
      headers: { 'x-correlation-id': ID },
    });
    // route validates lower-case alpha; rejects with 400 or 404 — either is
    // acceptable, the point is "doesn't 200 with junk".
    expect([400, 404]).toContain(res.statusCode);
  });
});
