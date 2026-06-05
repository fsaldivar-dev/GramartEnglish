import { describe, it, expect, afterAll } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../src/server.js';
import { RecordedFakeLlm } from '../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';
const BUDGET_P95_MS = 200; // Constitution VIII
const ADAPTIVE_HEADERS = {
  'x-correlation-id': ID,
  'x-client-version': '1.4.0',
  'content-type': 'application/json',
};

let app: FastifyInstance | undefined;
afterAll(async () => { if (app) await app.close(); });

function percentile(samples: number[], p: number): number {
  const sorted = [...samples].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p));
  return sorted[idx]!;
}

describe('perf — adaptive placement endpoints (F005)', () => {
  it(`POST /v1/placement/start (adaptive) p95 ≤ ${BUDGET_P95_MS} ms`, async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const samples: number[] = [];
    for (let i = 0; i < 30; i += 1) {
      const t0 = performance.now();
      const res = await app.inject({
        method: 'POST',
        url: '/v1/placement/start',
        headers: ADAPTIVE_HEADERS,
        payload: { seed: i, selfReport: 'some' },
      });
      const t1 = performance.now();
      expect(res.statusCode).toBe(200);
      samples.push(t1 - t0);
    }
    const p95 = percentile(samples, 0.95);
    expect(p95).toBeLessThanOrEqual(BUDGET_P95_MS);
  });

  it(`POST /v1/placement/answer p95 ≤ ${BUDGET_P95_MS} ms over a 30-item run`, async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const startRes = await app.inject({
      method: 'POST',
      url: '/v1/placement/start',
      headers: ADAPTIVE_HEADERS,
      payload: { seed: 1, selfReport: 'some' },
    });
    expect(startRes.statusCode).toBe(200);
    const sBody = startRes.json() as { placementId: string; question: { id: string } };
    let placementId = sBody.placementId;
    let questionId = sBody.question.id;
    const samples: number[] = [];
    for (let i = 0; i < 30; i += 1) {
      const t0 = performance.now();
      const ans = await app.inject({
        method: 'POST',
        url: '/v1/placement/answer',
        headers: ADAPTIVE_HEADERS,
        payload: { placementId, questionId, optionIndex: i % 4 },
      });
      const t1 = performance.now();
      expect(ans.statusCode).toBe(200);
      samples.push(t1 - t0);
      const body = ans.json() as { kind: string; question?: { id: string } };
      if (body.kind === 'done') {
        // Start a fresh placement to keep measuring.
        const r = await app.inject({
          method: 'POST',
          url: '/v1/placement/start',
          headers: ADAPTIVE_HEADERS,
          payload: { seed: 1000 + i, selfReport: 'some' },
        });
        const b = r.json() as { placementId: string; question: { id: string } };
        placementId = b.placementId;
        questionId = b.question.id;
      } else {
        questionId = body.question!.id;
      }
    }
    const p95 = percentile(samples, 0.95);
    expect(p95).toBeLessThanOrEqual(BUDGET_P95_MS);
  });
});
