import { describe, it, expect } from 'vitest';
import Fastify from 'fastify';
import { correlationIdPlugin, isValidCorrelationId } from '../../../src/observability/correlationId.js';

const SAMPLE_ID = '00000000-0000-4000-8000-000000000000';

async function buildApp() {
  const app = Fastify({ logger: false });
  await app.register(correlationIdPlugin);
  app.get('/echo', async (req) => ({ id: req.correlationId }));
  return app;
}

describe('isValidCorrelationId', () => {
  it('accepts UUIDs', () => {
    expect(isValidCorrelationId(SAMPLE_ID)).toBe(true);
  });
  it('rejects non-UUIDs', () => {
    expect(isValidCorrelationId('nope')).toBe(false);
    expect(isValidCorrelationId(undefined)).toBe(false);
    expect(isValidCorrelationId(123)).toBe(false);
  });
});

describe('correlationIdPlugin', () => {
  it('echoes a valid incoming correlation id', async () => {
    const app = await buildApp();
    const res = await app.inject({ method: 'GET', url: '/echo', headers: { 'x-correlation-id': SAMPLE_ID } });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ id: SAMPLE_ID });
    expect(res.headers['x-correlation-id']).toBe(SAMPLE_ID);
    await app.close();
  });

  it('generates one when the header is missing or invalid', async () => {
    const app = await buildApp();
    const res = await app.inject({ method: 'GET', url: '/echo', headers: { 'x-correlation-id': 'not-a-uuid' } });
    expect(res.statusCode).toBe(200);
    expect(isValidCorrelationId(res.json().id)).toBe(true);
    expect(res.headers['x-correlation-id']).toBe(res.json().id);
    await app.close();
  });
});
