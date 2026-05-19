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

describe('POST /v1/lessons — mode', () => {
  it('defaults to read_pick_meaning when mode is omitted', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().mode).toBe('read_pick_meaning');
  });

  it('honors an explicit listen_pick_word mode', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'listen_pick_word' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().mode).toBe('listen_pick_word');
    expect(res.json().questions).toHaveLength(10);
  });

  it('honors listen_pick_meaning and listen_type', async () => {
    const a = await setup();
    for (const mode of ['listen_pick_meaning', 'listen_type'] as const) {
      const res = await a.inject({
        method: 'POST',
        url: '/v1/lessons',
        headers: { 'x-correlation-id': ID },
        payload: { level: 'A1', mode },
      });
      expect(res.statusCode).toBe(200);
      expect(res.json().mode).toBe(mode);
    }
  });

  it('returns 400 for an invalid mode value', async () => {
    const a = await setup();
    const res = await a.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_freeform' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().code).toBe('invalid_payload');
  });
});
