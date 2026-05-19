import { describe, it, expect, afterEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

const SAMPLE_ID = '00000000-0000-4000-8000-000000000000';

let app: FastifyInstance | undefined;

afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

describe('buildServer', () => {
  it('exposes GET /v1/health with version + schemaVersion + ollamaAvailable', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/health',
      headers: { 'x-correlation-id': SAMPLE_ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.status).toBe('ok');
    expect(typeof body.version).toBe('string');
    expect(body.schemaVersion).toBeGreaterThanOrEqual(1);
    expect(body.ollamaAvailable).toBe(true);
    expect(res.headers['x-correlation-id']).toBe(SAMPLE_ID);
  });

  it('reports ollamaAvailable=false when adapter is down', async () => {
    const fake = new RecordedFakeLlm({ available: false });
    const built = await buildServer({ dbFilename: ':memory:', llm: fake, repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/health',
      headers: { 'x-correlation-id': SAMPLE_ID },
    });
    expect(res.json().ollamaAvailable).toBe(false);
  });

  it('returns 6 CEFR levels with labels', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'GET',
      url: '/v1/levels',
      headers: { 'x-correlation-id': SAMPLE_ID },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as { code: string; label: string }[];
    expect(body).toHaveLength(6);
    expect(body.map((l) => l.code)).toEqual(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
  });
});
