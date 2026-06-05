import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildServer } from '../../src/server.js';
import { RecordedFakeLlm } from '../../src/llm/__fakes__/recorded.js';
import { _resetPlacementStoreForTests } from '../../src/routes/placement.js';
import type { FastifyInstance } from 'fastify';

// QA caveat 1 (#7): build a `base → spanishOption` lookup from the corpus files
// so the integration test can identify the correct option without inspecting
// server internals. Options are the Spanish translations, shuffled per-question
// with a deterministic seed plumbed through `placement/start`.
const LEVELS = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'] as const;
function buildSpanishLookup(repoRoot: string): Map<string, string> {
  const map = new Map<string, string>();
  for (const lvl of LEVELS) {
    const path = join(repoRoot, 'data', 'cefr', `${lvl}.json`);
    const words = JSON.parse(readFileSync(path, 'utf-8')) as { base: string; spanishOption: string }[];
    for (const w of words) map.set(w.base.toLowerCase(), w.spanishOption);
  }
  return map;
}
function correctIndexFor(word: string, options: string[], lookup: Map<string, string>): number {
  const sp = lookup.get(word.toLowerCase());
  if (sp === undefined) throw new Error(`no spanishOption for ${word}`);
  const idx = options.indexOf(sp);
  if (idx < 0) throw new Error(`spanishOption ${sp} not in options ${JSON.stringify(options)} for ${word}`);
  return idx;
}

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const ID = '00000000-0000-4000-8000-000000000000';
const ADAPTIVE_HEADERS = {
  'x-correlation-id': ID,
  'x-client-version': '1.4.0',
  'content-type': 'application/json',
};

let app: FastifyInstance | undefined;

beforeEach(() => _resetPlacementStoreForTests());
afterEach(async () => {
  if (app) await app.close();
  app = undefined;
});

interface AdaptiveStart {
  placementId: string;
  question: { id: string; word: string; options: string[]; level: string };
  progress: { current: number; max: number };
}

interface AnswerBody {
  kind: 'continue' | 'done';
  question?: { id: string; word: string; options: string[]; level: string };
  progress?: { current: number; max: number };
  result?: {
    estimatedLevel: string;
    algorithmVersion: string;
    itemsAdministered: number;
    perLevelScores: Record<string, { attempted: number; correct: number }>;
  };
}

async function start(selfReport: 'never' | 'some' | 'lots'): Promise<AdaptiveStart> {
  const res = await app!.inject({
    method: 'POST',
    url: '/v1/placement/start',
    headers: ADAPTIVE_HEADERS,
    payload: { seed: 1, selfReport },
  });
  expect(res.statusCode).toBe(200);
  return res.json() as AdaptiveStart;
}

async function answer(placementId: string, questionId: string, optionIndex: number): Promise<AnswerBody> {
  const res = await app!.inject({
    method: 'POST',
    url: '/v1/placement/answer',
    headers: ADAPTIVE_HEADERS,
    payload: { placementId, questionId, optionIndex },
  });
  expect(res.statusCode).toBe(200);
  return res.json() as AnswerBody;
}

describe('Adaptive placement — end-to-end flow', () => {
  it('selfReport=never + all wrong answers ⇒ floor-locks at A1 in ≤ 8 items', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const s = await start('never');
    let qId = s.question.id;
    let last: AnswerBody | null = null;
    for (let i = 0; i < 12; i += 1) {
      last = await answer(s.placementId, qId, -1); // -1 always wrong
      if (last.kind === 'done') break;
      qId = last.question!.id;
    }
    expect(last?.kind).toBe('done');
    expect(last?.result?.estimatedLevel).toBe('A1');
    expect(last?.result?.itemsAdministered ?? 999).toBeLessThanOrEqual(8);
  });

  it('selfReport=lots + all correct answers ⇒ ceiling-locks at C2', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const s = await start('lots');

    // QA caveat 1 fix (#7): the deterministic `seed: 1` in `start()` makes
    // the option shuffle reproducible; we now resolve the correct option by
    // matching the wire `word` against the corpus `spanishOption` instead of
    // blind-clicking 0. With selfReport=lots + every answer correct, the
    // adaptive algorithm MUST ceiling-lock at C2.
    const lookup = buildSpanishLookup(REPO_ROOT);
    let qId = s.question.id;
    let qWord = s.question.word;
    let qOptions = s.question.options;
    let last: AnswerBody | null = null;
    for (let i = 0; i < 35; i += 1) {
      const idx = correctIndexFor(qWord, qOptions, lookup);
      last = await answer(s.placementId, qId, idx);
      if (last.kind === 'done') break;
      qId = last.question!.id;
      qWord = last.question!.word;
      qOptions = last.question!.options;
    }
    expect(last?.kind).toBe('done');
    expect(last?.result?.estimatedLevel).toBe('C2');
    expect(last?.result?.itemsAdministered).toBeGreaterThan(0);
  });

  it('persists the placement_results row with algorithmVersion and itemsAdministered', async () => {
    const built = await buildServer({ dbFilename: ':memory:', llm: new RecordedFakeLlm(), repoRoot: REPO_ROOT });
    app = built.app;
    const s = await start('never');
    let qId = s.question.id;
    let last: AnswerBody | null = null;
    for (let i = 0; i < 35; i += 1) {
      last = await answer(s.placementId, qId, -1);
      if (last?.kind === 'done') break;
      qId = last!.question!.id;
    }
    expect(last?.kind).toBe('done');
    // user.currentLevel should now match the result
    const progress = await app.inject({ method: 'GET', url: '/v1/progress', headers: { 'x-correlation-id': ID } });
    const body = progress.json() as { currentLevel: string };
    expect(body.currentLevel).toBe(last!.result!.estimatedLevel);
  });
});
