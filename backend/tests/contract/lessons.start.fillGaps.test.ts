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

describe('POST /v1/lessons — write_fill_gaps (v1.5 contract)', () => {
  it('returns maskedWord for long-enough words; omits it for ≤3-letter auto-promoted ones', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const res = await app.inject({
      method: 'POST',
      url: '/v1/lessons',
      headers: { 'x-correlation-id': ID },
      payload: { level: 'A1', mode: 'write_fill_gaps' },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json() as {
      lessonId: string;
      mode: string;
      questions: Array<{ id: string; word: string; prompt?: string; maskedWord?: string }>;
    };
    expect(body.mode).toBe('write_fill_gaps');
    expect(body.questions).toHaveLength(10);

    let longSeen = 0;
    for (const q of body.questions) {
      expect(typeof q.prompt).toBe('string');
      if (q.word.length <= 3) {
        // Auto-promoted by the gap masker — server omits maskedWord.
        expect(q.maskedWord).toBeUndefined();
      } else {
        longSeen += 1;
        expect(typeof q.maskedWord).toBe('string');
        const masked = q.maskedWord!;
        // First letter preserved.
        expect(masked[0]).toBe(q.word[0]);
        // Contains at least one underscore (gap).
        expect(masked).toContain('_');
        // Same length as the original word.
        expect(masked.length).toBe(q.word.length);
        // Non-underscore positions match the original letters at those indices.
        for (let i = 0; i < masked.length; i += 1) {
          if (masked[i] !== '_') {
            expect(masked[i]).toBe(q.word[i]);
          }
        }
      }
    }
    // A1 corpus has plenty of >3-letter words — sanity check we exercised the mask path.
    expect(longSeen).toBeGreaterThan(0);
  });
});
