import { describe, it, expect, beforeEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { MasteryRepository } from '../../../src/store/masteryRepository.js';
import { UserRepository } from '../../../src/store/userRepository.js';
import { LessonRepository } from '../../../src/store/lessonRepository.js';
import { QuestionRepository } from '../../../src/store/questionRepository.js';
import { loadVerbCorpus } from '../../../src/store/verbRepository.js';
import { LessonService } from '../../../src/lessons/lessonService.js';

/**
 * F007 (v1.8.0). The over-regularization `feedbackHint` is emitted when the
 * learner commits to `<base>ed` for an irregular verb. Visible-distractor
 * removal (Item 4) made the picker pool exclude `goed`/`eated`/etc — so the
 * realistic trigger is the typed-write branch. We exercise that branch by
 * hand-crafting a `write_type_word` lesson row whose first question targets
 * the verb `go`, then submit `"goed"` and assert the hint is returned.
 */

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

interface Ctx {
  db: Database.Database;
  service: LessonService;
  userId: string;
  goWordId: number;
}

function setup(): Ctx {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  const words = new WordRepository(db);
  const verbs = loadVerbCorpus(CORPUS, words);
  const user = new UserRepository(db).ensureSingleton('A2');
  const lessons = new LessonRepository(db);
  const questions = new QuestionRepository(db);
  const service = new LessonService({
    lessons,
    questions,
    words,
    mastery: new MasteryRepository(db),
    verbs,
  });
  const go = verbs.lookupByBase('go');
  if (!go) throw new Error('test setup expects `go` in corpus');
  return { db, service, userId: user.id, goWordId: go.wordId };
}

function craftWriteTypeWordLessonForGo(ctx: Ctx): { lessonId: string; questionId: string } {
  // Insert a lesson + question directly so we don't depend on the word
  // selector picking `go` for write_type_word — the selector is non-
  // deterministic w.r.t. priority across seeds.
  const lessonId = '11111111-1111-4111-8111-111111111111';
  const questionId = '22222222-2222-4222-8222-222222222222';
  ctx.db
    .prepare(
      `INSERT INTO lessons (id, userId, level, mode, state, startedAt, correlationId)
       VALUES (?, ?, 'A2', 'write_type_word', 'in_progress', datetime('now'), 'test-c')`,
    )
    .run(lessonId, ctx.userId);
  ctx.db
    .prepare(
      `INSERT INTO questions (id, lessonId, position, wordId, options, correctIndex)
       VALUES (?, ?, 0, ?, ?, 0)`,
    )
    .run(questionId, lessonId, ctx.goWordId, JSON.stringify(['go', 'a', 'b', 'c']));
  return { lessonId, questionId };
}

describe('LessonService — F007 feedbackHint (over-regularization)', () => {
  let ctx: Ctx;
  beforeEach(() => { ctx = setup(); });

  it('emits feedbackHint when learner types "goed" for the verb go', () => {
    const { lessonId, questionId } = craftWriteTypeWordLessonForGo(ctx);
    const result = ctx.service.submitAnswer({
      lessonId,
      questionId,
      typedAnswer: 'goed',
      answerMs: 1234,
      userId: ctx.userId,
    });
    expect(result.outcome).toBe('incorrect');
    expect(result.feedbackHint).toBeDefined();
    expect(result.feedbackHint).toContain('goed');
    expect(result.feedbackHint).toContain('went');
    expect(result.feedbackHint).toContain('irregular');
  });

  it('does NOT emit feedbackHint when learner types the canonical answer correctly', () => {
    const { lessonId, questionId } = craftWriteTypeWordLessonForGo(ctx);
    const result = ctx.service.submitAnswer({
      lessonId,
      questionId,
      typedAnswer: 'go',
      answerMs: 1234,
      userId: ctx.userId,
    });
    expect(result.outcome).toBe('correct');
    expect(result.feedbackHint).toBeUndefined();
  });

  it('does NOT emit feedbackHint for an unrelated wrong typing', () => {
    const { lessonId, questionId } = craftWriteTypeWordLessonForGo(ctx);
    const result = ctx.service.submitAnswer({
      lessonId,
      questionId,
      typedAnswer: 'walked',
      answerMs: 1234,
      userId: ctx.userId,
    });
    expect(result.outcome).toBe('incorrect');
    expect(result.feedbackHint).toBeUndefined();
  });
});
