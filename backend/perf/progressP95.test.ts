import { describe, it, expect, afterAll } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../src/server.js';
import { RecordedFakeLlm } from '../src/llm/__fakes__/recorded.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';
const BUDGET_P95_MS = 100; // F002 SC: per-mode aggregates must still be fast

let app: FastifyInstance | undefined;

afterAll(async () => {
  if (app) await app.close();
});

function percentile(samples: number[], p: number): number {
  const sorted = [...samples].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p));
  return sorted[idx]!;
}

describe('perf — GET /v1/progress p95 latency (with mode aggregates)', () => {
  it(`is ≤ ${BUDGET_P95_MS} ms`, async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;

    // Seed some mastery in multiple modes so the aggregation does real work.
    // Run two lessons in different modes and answer a few questions to populate
    // word_mastery rows across the (userId, wordId, mode) axis.
    for (const mode of ['listen_pick_word', 'listen_pick_meaning'] as const) {
      const start = await app.inject({
        method: 'POST',
        url: '/v1/lessons',
        headers: { 'x-correlation-id': ID },
        payload: { level: 'A1', mode },
      });
      const body = start.json() as { lessonId: string; questions: { id: string }[] };
      for (const q of body.questions.slice(0, 5)) {
        await app.inject({
          method: 'POST',
          url: `/v1/lessons/${body.lessonId}/answers`,
          headers: { 'x-correlation-id': ID },
          payload: { questionId: q.id, optionIndex: 0, answerMs: 100 },
        });
      }
    }

    const samples: number[] = [];
    const N = 50;
    for (let i = 0; i < N; i += 1) {
      const t0 = performance.now();
      const res = await app.inject({
        method: 'GET',
        url: '/v1/progress',
        headers: { 'x-correlation-id': ID },
      });
      const t1 = performance.now();
      expect(res.statusCode).toBe(200);
      const body = res.json();
      // Sanity: the new fields are present so we're actually measuring the
      // mode-aware aggregation path, not the pre-F002 lean response.
      expect(body.perModeMastered).toBeDefined();
      expect(body.recommendedMode).toBeDefined();
      samples.push(t1 - t0);
    }
    const p95 = percentile(samples, 0.95);
    const median = percentile(samples, 0.5);
    console.log(`GET /v1/progress: median=${median.toFixed(2)}ms p95=${p95.toFixed(2)}ms (n=${N})`);
    expect(p95).toBeLessThanOrEqual(BUDGET_P95_MS);
  });
});
