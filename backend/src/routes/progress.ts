import type { FastifyInstance } from 'fastify';
import type Database from 'better-sqlite3';
import { LessonRepository } from '../store/lessonRepository.js';
import { MasteryRepository } from '../store/masteryRepository.js';
import { UserRepository } from '../store/userRepository.js';
import { QuestionRepository } from '../store/questionRepository.js';
import { WordRepository } from '../store/wordRepository.js';
import { SHIPPED_MODES, type LessonMode } from '../domain/schemas.js';
import { recommendMode } from '../lessons/modeRecommender.js';
import { LessonService } from '../lessons/lessonService.js';
import { loadVerbCorpus } from '../store/verbRepository.js';

export interface ProgressRouteDeps {
  db: Database.Database;
  /** v1.8.0+ (F007 patch). Optional path to `data/cefr/` so the GET
   *  /v1/lessons/:lessonId endpoint can rehydrate `conjugate_pick_form`
   *  lessons with verb-corpus-derived metadata (prompt, exampleEs/En). When
   *  omitted, conjugation lessons still resume but with the minimal MCQ shape. */
  corpusDir?: string;
}

export async function registerProgressRoutes(app: FastifyInstance, deps: ProgressRouteDeps): Promise<void> {
  const userRepo = new UserRepository(deps.db);
  const lessonRepo = new LessonRepository(deps.db);
  const masteryRepo = new MasteryRepository(deps.db);
  const questionRepo = new QuestionRepository(deps.db);
  const wordRepo = new WordRepository(deps.db);
  // F007 patch (v1.8.0). Reuse the lesson service so resume returns the same
  // ClientLessonQuestion shape as POST /v1/lessons (prompt/maskedWord/verbBase/
  // exampleEs/exampleEn populated per-mode). Previously the route built a
  // bare {id, word, options, position} which made resuming write/conjugation
  // lessons render blanks where the prompt should be.
  const verbRepo = deps.corpusDir ? loadVerbCorpus(deps.corpusDir, wordRepo) : undefined;
  const lessonService = new LessonService({
    lessons: lessonRepo,
    questions: questionRepo,
    words: wordRepo,
    mastery: masteryRepo,
    ...(verbRepo ? { verbs: verbRepo } : {}),
  });

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
      write_pick_word: 0,
      write_type_word: 0,
      write_fill_gaps: 0,
      conjugate_pick_form: 0,
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
    const result = lessonService.describeLesson({ lessonId });
    if (!result) return reply.code(404).send({ code: 'lesson_not_found', message: 'unknown lesson' });
    if (result.kind === 'completed') {
      return {
        state: 'completed',
        lessonId: result.lesson.id,
        level: result.lesson.level,
        mode: result.lesson.mode,
        score: result.summary.score,
        total: result.summary.total,
        missedWords: result.summary.missedWords.map((m) => ({
          word: m.word,
          canonicalDefinition: m.canonicalDefinition,
        })),
      };
    }
    // F007 patch (v1.8.0). Mirror the `StartLessonResponse` shape so the
    // client can decode both /lessons (POST) and /lessons/:id (GET) into the
    // same type. We additionally surface state/answeredCount/totalCount so
    // existing callers (Home banner, tests) keep working.
    return {
      state: 'in_progress',
      lessonId: result.lesson.id,
      level: result.lesson.level,
      mode: result.lesson.mode,
      answeredCount: result.answeredCount,
      totalCount: result.totalCount,
      questions: result.remaining,
      // Back-compat alias for the pre-patch contract test that asserted
      // `remaining`. Keep the duplicate until we ship a major.
      remaining: result.remaining,
    };
  });
}
