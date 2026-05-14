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

describe('GET /v1/words/{word}/examples', () => {
  it('returns LLM examples when available and the output contains the word', async () => {
    const fake = new RecordedFakeLlm({ defaultChatResponse: 'I eat breakfast.\nWe eat fish on Friday.' });
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/eat/examples?level=A1',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.fallback).toBe(false);
    expect(body.generatedBy).toBe('llm');
    expect(body.examples.length).toBeGreaterThan(0);
    for (const ex of body.examples) expect(ex.toLowerCase()).toMatch(/eat/);
  });

  it('falls back to canonical when Ollama is unavailable (503 with fallback:true)', async () => {
    const fake = new RecordedFakeLlm({ available: false });
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/eat/examples?level=A1',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(503);
    const body = res.json();
    expect(body.fallback).toBe(true);
    expect(body.generatedBy).toBe('fallback_canonical');
    expect(body.examples.length).toBeGreaterThan(0);
  });

  it('falls back when LLM output does not contain the word', async () => {
    const fake = new RecordedFakeLlm({ defaultChatResponse: 'The sky is blue today.' });
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

  it('404s on unknown word', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/notarealword/examples?level=A1',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(404);
  });

  it('400s on missing level query param', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/eat/examples',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(400);
  });
});
