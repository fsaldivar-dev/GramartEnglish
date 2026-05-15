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

async function setup() {
  const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
  app = built.app;
  return app;
}

describe('GET /v1/me + PATCH /v1/me', () => {
  it('GET returns the singleton user with default level A2', async () => {
    const a = await setup();
    const res = await a.inject({ method: 'GET', url: '/v1/me', headers: { 'x-correlation-id': ID } });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.currentLevel).toBe('A2');
    expect(typeof body.id).toBe('string');
  });

  it('PATCH sets currentLevel', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: { 'x-correlation-id': ID },
      payload: { currentLevel: 'B2' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().currentLevel).toBe('B2');
  });

  it('PATCH sets accessibilityPrefs', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: { 'x-correlation-id': ID },
      payload: { accessibilityPrefs: { reduceMotion: true } },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().accessibilityPrefs.reduceMotion).toBe(true);
  });

  it('PATCH 400s when neither field is provided', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: { 'x-correlation-id': ID },
      payload: {},
    });
    expect(res.statusCode).toBe(400);
  });
});

describe('POST /v1/me/reset', () => {
  it('wipes user-specific data and resets the user to default level', async () => {
    const a = await setup();
    // Set level to C1, complete a lesson…
    await a.inject({
      method: 'PATCH',
      url: '/v1/me',
      headers: { 'x-correlation-id': ID },
      payload: { currentLevel: 'C1' },
    });
    const reset = await a.inject({
      method: 'POST',
      url: '/v1/me/reset',
      headers: { 'x-correlation-id': ID },
    });
    expect(reset.statusCode).toBe(200);
    expect(reset.json().user.currentLevel).toBe('A2');

    const me = await a.inject({ method: 'GET', url: '/v1/me', headers: { 'x-correlation-id': ID } });
    expect(me.json().currentLevel).toBe('A2');
  });
});
