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

describe('AI fallback integration', () => {
  it('keeps lesson quiz functions working when LLM is unavailable (FR-011, SC-006)', async () => {
    const fake = new RecordedFakeLlm({ available: false });
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;

    // Quiz still works
    const health = await app.inject({ method: 'GET', url: '/v1/health', headers: { 'x-correlation-id': ID } });
    expect(health.statusCode).toBe(200);
    expect(health.json().ollamaAvailable).toBe(false);

    const lessons = await app.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1' },
    });
    expect(lessons.statusCode).toBe(200);
    expect(lessons.json().questions).toHaveLength(10);

    // AI endpoints return fallback (503 + fallback:true)
    const ex = await app.inject({
      method: 'GET',
      url: '/v1/words/eat/examples?level=A1',
      headers: { 'x-correlation-id': ID },
    });
    expect(ex.statusCode).toBe(503);
    expect(ex.json().fallback).toBe(true);
  });

  it('falls back when LLM throws mid-stream', async () => {
    // RecordedFakeLlm throws on chat when available=false. Toggle after a probe
    // to simulate "available reports true but chat throws".
    const fake = new RecordedFakeLlm({ available: true });
    fake.setResponse('TASK', ''); // empty triggers validator failure
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/eat/examples?level=A1',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(503);
    expect(res.json().fallback).toBe(true);
  });
});
