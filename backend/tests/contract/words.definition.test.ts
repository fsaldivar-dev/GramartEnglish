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

describe('GET /v1/words/{word}/definition', () => {
  it('returns an LLM definition when available', async () => {
    const fake = new RecordedFakeLlm({
      defaultChatResponse: 'A short-lived thing; lasting only briefly.',
    });
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/ephemeral/definition?level=B2',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.fallback).toBe(false);
    expect(body.generatedBy).toBe('llm');
    expect(body.definition.length).toBeGreaterThan(0);
  });

  it('falls back to canonical definition on Ollama outage', async () => {
    const fake = new RecordedFakeLlm({ available: false });
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/words/ephemeral/definition?level=B2',
      headers: { 'x-correlation-id': ID },
    });
    expect(res.statusCode).toBe(503);
    const body = res.json();
    expect(body.fallback).toBe(true);
    expect(body.definition).toMatch(/Lasting for a very short time/);
  });
});
