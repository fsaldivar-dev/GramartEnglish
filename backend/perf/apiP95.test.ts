import { describe, it, expect, afterAll } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../src/server.js';
import { RecordedFakeLlm } from '../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';
const BUDGET_P95_MS = 200; // Constitution VIII

let app: FastifyInstance | undefined;

afterAll(async () => {
  if (app) await app.close();
});

function percentile(samples: number[], p: number): number {
  const sorted = [...samples].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p));
  return sorted[idx]!;
}

describe('perf — POST /v1/lessons p95 latency', () => {
  it(`is ≤ ${BUDGET_P95_MS} ms`, async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const samples: number[] = [];
    const N = 50;
    for (let i = 0; i < N; i += 1) {
      const t0 = performance.now();
      const res = await app.inject({
        method: 'POST',
        url: '/v1/lessons',
        headers: { 'x-correlation-id': ID },
        payload: { level: 'A1' },
      });
      const t1 = performance.now();
      expect(res.statusCode).toBe(200);
      samples.push(t1 - t0);
    }
    const p95 = percentile(samples, 0.95);
    const median = percentile(samples, 0.5);
    console.log(`POST /v1/lessons: median=${median.toFixed(2)}ms p95=${p95.toFixed(2)}ms (n=${N})`);
    expect(p95).toBeLessThanOrEqual(BUDGET_P95_MS);
  });
});
