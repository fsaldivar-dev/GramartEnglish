import type { FastifyInstance } from 'fastify';
import type Database from 'better-sqlite3';
import { LessonRepository } from '../store/lessonRepository.js';
import { MasteryRepository } from '../store/masteryRepository.js';
import { UserRepository } from '../store/userRepository.js';
import { QuestionRepository } from '../store/questionRepository.js';
import { WordRepository } from '../store/wordRepository.js';
import { SHIPPED_MODES, type LessonMode } from '../domain/schemas.js';
import { recommendMode } from '../lessons/modeRecommender.js';

export interface ProgressRouteDeps {
  db: Database.Database;
}

export async function registerProgressRoutes(app: FastifyInstance, deps: ProgressRouteDeps): Promise<void> {
  const userRepo = new UserRepository(deps.db);
  const lessonRepo = new LessonRepository(deps.db);
  const masteryRepo = new MasteryRepository(deps.db);
  const questionRepo = new QuestionRepository(deps.db);
  const wordRepo = new WordRepository(deps.db);

  app.get('/v1/progress', async () => {
    const user = userRepo.ensureSingleton();
    const lastCompleted = lessonRepo.latestCompletedForUser(user.id);
    const inProgress = lessonRepo.latestInProgressForUser(user.id);

    let lastLesson: { lessonId: string; score: number; total: number; level: string; completedAt: string } | null = null;
    if (lastCompleted && lastCompleted.completedAt) {
      const total = questionRepo.byLessonId(lastCompleted.id).length;
      lastLesson = {
        lessonId: lastCompleted.id,
        score: lastCompleted.score ?? 0,
        total,
        level: lastCompleted.level,
        completedAt: lastCompleted.completedAt,
      };
    }

    let resumable: { lessonId: string; level: string; answeredCount: number; totalCount: number } | null = null;
    if (inProgress) {
      const qs = questionRepo.byLessonId(inProgress.id);
      const answered = qs.filter((q) => q.selectedIndex !== null).length;
      resumable = {
        lessonId: inProgress.id,
        level: inProgress.level,
        answeredCount: answered,
        totalCount: qs.length,
      };
    }

    const perModeMastered: Record<LessonMode, number> = {
      read_pick_meaning: 0,
      listen_pick_word: 0,
      listen_pick_meaning: 0,
      listen_type: 0,
    };
    for (const mode of SHIPPED_MODES) {
      perModeMastered[mode] = masteryRepo.countMastered(user.id, mode);
    }
    const recommendedMode = recommendMode(user.id, user.currentLevel, {
      words: wordRepo,
      mastery: masteryRepo,
    });

    return {
      currentLevel: user.currentLevel,
      lessonsCompleted: lessonRepo.countCompletedForUser(user.id),
      masteredCount: masteryRepo.countMastered(user.id),
      toReviewCount: masteryRepo.countToReview(user.id),
      lastLesson,
      resumable,
      perModeMastered,
      recommendedMode,
    };
  });

  app.get('/v1/lessons/:lessonId', async (req, reply) => {
    const lessonId = (req.params as { lessonId: string }).lessonId;
    const lesson = lessonRepo.byId(lessonId);
    if (!lesson) return reply.code(404).send({ code: 'lesson_not_found', message: 'unknown lesson' });
    const questions = questionRepo.byLessonId(lessonId);
    if (lesson.state === 'completed') {
      const missed = questions
        .filter((q) => q.correct === false)
        .map((q) => {
          const w = wordRepo.byId(q.wordId);
          return w ? { word: w.base, canonicalDefinition: w.canonicalDefinition } : null;
        })
        .filter((m): m is { word: string; canonicalDefinition: string } => m !== null);
      return {
        state: 'completed',
        lessonId: lesson.id,
        level: lesson.level,
        score: lesson.score ?? questions.filter((q) => q.correct === true).length,
        total: questions.length,
        missedWords: missed,
      };
    }
    const remaining = questions
      .filter((q) => q.selectedIndex === null)
      .map((q) => {
        const w = wordRepo.byId(q.wordId);
        return { id: q.id, word: w?.base ?? '', options: q.options, position: q.position };
      });
    return {
      state: 'in_progress',
      lessonId: lesson.id,
      level: lesson.level,
      answeredCount: questions.length - remaining.length,
      totalCount: questions.length,
      remaining,
    };
  });
}
