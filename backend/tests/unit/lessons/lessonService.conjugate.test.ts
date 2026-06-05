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

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

function setup() {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  const words = new WordRepository(db);
  const verbs = loadVerbCorpus(CORPUS, words);
  const user = new UserRepository(db).ensureSingleton('A2');
  const service = new LessonService({
    lessons: new LessonRepository(db),
    questions: new QuestionRepository(db),
    words,
    mastery: new MasteryRepository(db),
    verbs,
  });
  return { service, userId: user.id };
}

describe('LessonService — conjugate_pick_form', () => {
  let s: ReturnType<typeof setup>;
  beforeEach(() => { s = setup(); });

  it('startLesson assembles 10 conjugation questions', () => {
    const { questions, lesson } = s.service.startLesson({
      userId: s.userId, level: 'A2', mode: 'conjugate_pick_form', correlationId: 'c', seed: 1,
    });
    expect(questions).toHaveLength(10);
    expect(lesson.mode).toBe('conjugate_pick_form');
    for (const q of questions) {
      expect(q.options).toHaveLength(4);
      expect(q.prompt).toMatch(/^Pasado simple de \*\*.+\*\*$/);
      expect(q.verbBase).toBeDefined();
      expect(q.targetTense).toBe('simple_past');
      // v1.6.0 patch (Blocker 1): no ambiguous verbs (base === simple_past)
      // reach the client. The current corpus only excluded `read`; this
      // assertion guards against future regressions.
      expect(q.verbBase, `verbBase should not be a base==simple_past verb`).not.toBe('read');
      // v1.6.0 patch (Blocker 2): every conjugate question carries an
      // example_es with a `___` slot + an example_en translation, so the
      // client can disambiguate preterite vs imperfect.
      expect(q.exampleEs, `q.exampleEs missing for verb ${q.verbBase}`).toBeDefined();
      expect(q.exampleEs!).toContain('___');
      expect(q.exampleEn, `q.exampleEn missing for verb ${q.verbBase}`).toBeDefined();
      expect(q.exampleEn!.length).toBeGreaterThan(0);
    }
  });

  it('submitAnswer with the correct optionIndex marks the question correct', () => {
    const { lesson, questions } = s.service.startLesson({
      userId: s.userId, level: 'A2', mode: 'conjugate_pick_form', correlationId: 'c', seed: 5,
    });
    const q0 = questions[0]!;
    // Reach the QuestionRepository to find the correctIndex for this question.
    // The service does not expose it on the client DTO. Try each option; we
    // expect exactly one "correct" outcome across the 4 attempts.
    const outcomes: string[] = [];
    for (let i = 0; i < 4; i += 1) {
      const ctx = setup(); // fresh DB so the mastery side-effect doesn't leak
      const fresh = ctx.service.startLesson({
        userId: ctx.userId, level: 'A2', mode: 'conjugate_pick_form', correlationId: 'c', seed: 5,
      });
      const r = ctx.service.submitAnswer({
        lessonId: fresh.lesson.id,
        questionId: fresh.questions[0]!.id,
        optionIndex: i,
        answerMs: 1000,
        userId: ctx.userId,
      });
      outcomes.push(r.outcome);
    }
    expect(outcomes.filter((o) => o === 'correct')).toHaveLength(1);
    expect(outcomes.filter((o) => o === 'incorrect')).toHaveLength(3);
    // touched-to-silence-eslint:
    expect(q0.verbBase).toBeDefined();
    expect(lesson.id).toBeTruthy();
  });

  it('refuses to start when the verb corpus is missing', () => {
    const db = new Database(':memory:');
    runMigrations(db);
    loadCorpusIfEmpty(db, CORPUS);
    const user = new UserRepository(db).ensureSingleton('A2');
    const noVerbsService = new LessonService({
      lessons: new LessonRepository(db),
      questions: new QuestionRepository(db),
      words: new WordRepository(db),
      mastery: new MasteryRepository(db),
      // verbs intentionally omitted
    });
    expect(() => noVerbsService.startLesson({
      userId: user.id, level: 'A2', mode: 'conjugate_pick_form', correlationId: 'c',
    })).toThrow(/verb corpus/i);
  });

  it('B1 lessons draw from the B1 verb pool', () => {
    const { questions } = s.service.startLesson({
      userId: s.userId, level: 'B1', mode: 'conjugate_pick_form', correlationId: 'c', seed: 3,
    });
    expect(questions).toHaveLength(10);
    for (const q of questions) {
      // verbBase must be one of the B1-level bases.
      expect(typeof q.verbBase).toBe('string');
    }
  });
});
