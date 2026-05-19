import { describe, it, expect, afterAll } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../src/server.js';
import { OllamaAdapter } from '../src/llm/ollama.js';
import type { FastifyInstance } from 'fastify';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';
const BUDGET_FIRST_TOKEN_MS = 1500; // SC-004

// This bench requires a real local Ollama. Skip if `OLLAMA_BENCH=1` is not set.
const RUN = process.env.OLLAMA_BENCH === '1';

let app: FastifyInstance | undefined;

afterAll(async () => {
  if (app) await app.close();
});

describe.skipIf(!RUN)('perf — LLM first token latency', () => {
  it(`/v1/words/eat/examples completes (first token) in ≤ ${BUDGET_FIRST_TOKEN_MS} ms`, async () => {
    const chatModel = process.env.GRAMART_CHAT_MODEL ?? 'llama3.1:8b-instruct-q4_K_M';
    const built = await buildServer({
      dbFilename: ':memory:',
      llm: new OllamaAdapter(),
      repoRoot: REPO_ROOT,
      chatModel,
    });
    app = built.app;
    const samples: number[] = [];
    const N = 5;
    for (let i = 0; i < N; i += 1) {
      const t0 = performance.now();
      const res = await app.inject({
        method: 'GET',
        url: '/v1/words/eat/examples?level=A1',
        headers: { 'x-correlation-id': ID },
      });
      const t1 = performance.now();
      // Even if the streaming first token is internal, total wall-clock under
      // 1.5 s is a tighter bound — accept either fallback (counts as failed)
      // or a real LLM response.
      if (res.statusCode === 200) {
        samples.push(t1 - t0);
      }
    }
    expect(samples.length).toBeGreaterThan(0);
    const median = samples.sort((a, b) => a - b)[Math.floor(samples.length / 2)]!;
    console.log(`LLM examples wall-clock (n=${samples.length}): median=${median.toFixed(0)}ms`);
    expect(median).toBeLessThanOrEqual(BUDGET_FIRST_TOKEN_MS);
  });
});
