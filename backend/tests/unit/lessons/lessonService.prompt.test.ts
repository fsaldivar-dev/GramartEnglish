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
import { LessonService } from '../../../src/lessons/lessonService.js';
import type { LessonMode } from '../../../src/domain/schemas.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

interface Ctx {
  service: LessonService;
  userId: string;
}

function setup(): Ctx {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  const user = new UserRepository(db).ensureSingleton('A1');
  return {
    service: new LessonService({
      lessons: new LessonRepository(db),
      questions: new QuestionRepository(db),
      words: new WordRepository(db),
      mastery: new MasteryRepository(db),
    }),
    userId: user.id,
  };
}

describe('LessonService.startLesson — LessonQuestion.prompt population', () => {
  let s: Ctx;
  beforeEach(() => {
    s = setup();
  });

  it('write_pick_word: every question carries a non-empty Spanish prompt', () => {
    const { questions } = s.service.startLesson({
      userId: s.userId, level: 'A1', mode: 'write_pick_word', correlationId: 'c', seed: 1,
    });
    expect(questions).toHaveLength(10);
    for (const q of questions) {
      expect(q.prompt).toBeDefined();
      expect(typeof q.prompt).toBe('string');
      expect(q.prompt!.length).toBeGreaterThan(0);
      // Prompt should NOT equal the English word (the prompt is the Spanish meaning).
      expect(q.prompt).not.toBe(q.word);
    }
  });

  it('write_type_word: prompt populated even though there are no on-screen options', () => {
    const { questions } = s.service.startLesson({
      userId: s.userId, level: 'A1', mode: 'write_type_word', correlationId: 'c', seed: 1,
    });
    for (const q of questions) {
      expect(q.prompt).toBeDefined();
    }
  });

  it.each<LessonMode>(['read_pick_meaning', 'listen_pick_word', 'listen_pick_meaning', 'listen_type'])(
    '%s: prompt is undefined (only write modes populate it)',
    (mode) => {
      const { questions } = s.service.startLesson({
        userId: s.userId, level: 'A1', mode, correlationId: 'c', seed: 2,
      });
      for (const q of questions) {
        expect(q.prompt).toBeUndefined();
      }
    },
  );
});
