import type { FastifyInstance } from 'fastify';
import type Database from 'better-sqlite3';
import { z } from 'zod';
import { CefrLevel, LessonMode, Uuid } from '../domain/schemas.js';
import { LessonRepository } from '../store/lessonRepository.js';
import { QuestionRepository } from '../store/questionRepository.js';
import { WordRepository } from '../store/wordRepository.js';
import { MasteryRepository } from '../store/masteryRepository.js';
import { UserRepository } from '../store/userRepository.js';
import { LessonService } from '../lessons/lessonService.js';

const StartRequest = z.object({
  level: CefrLevel,
  mode: LessonMode.default('read_pick_meaning'),
});
const AnswerRequest = z
  .object({
    questionId: Uuid,
    optionIndex: z.number().int().min(0).max(3).optional(),
    typedAnswer: z.string().trim().min(1).max(80).optional(),
    answerMs: z.number().int().nonnegative(),
  })
  .refine(
    (d) => (d.optionIndex === undefined) !== (d.typedAnswer === undefined),
    { message: 'exactly one of optionIndex or typedAnswer must be provided' },
  );

const SkipRequest = z.object({
  questionId: Uuid,
  answerMs: z.number().int().nonnegative(),
});

export interface LessonRouteDeps {
  db: Database.Database;
}

export async function registerLessonRoutes(app: FastifyInstance, deps: LessonRouteDeps): Promise<void> {
  const lessonRepo = new LessonRepository(deps.db);
  const questionRepo = new QuestionRepository(deps.db);
  const wordRepo = new WordRepository(deps.db);
  const masteryRepo = new MasteryRepository(deps.db);
  const userRepo = new UserRepository(deps.db);
  const service = new LessonService({
    lessons: lessonRepo,
    questions: questionRepo,
    words: wordRepo,
    mastery: masteryRepo,
  });

  app.post('/v1/lessons', async (req, reply) => {
    const parsed = StartRequest.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ code: 'invalid_payload', message: parsed.error.message });
    const user = userRepo.ensureSingleton();
    try {
      const result = service.startLesson({
        userId: user.id,
        level: parsed.data.level,
        mode: parsed.data.mode,
        correlationId: req.correlationId,
      });
      req.log.info({ lessonId: result.lesson.id, level: parsed.data.level, mode: parsed.data.mode }, 'lesson.started');
      return { lessonId: result.lesson.id, mode: parsed.data.mode, questions: result.questions };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'lesson start failed';
      req.log.error({ err }, 'lesson.start_failed');
      return reply.code(409).send({ code: 'lesson_unavailable', message });
    }
  });

  app.post('/v1/lessons/:lessonId/answers', async (req, reply) => {
    const params = z.object({ lessonId: Uuid }).safeParse(req.params);
    if (!params.success) return reply.code(400).send({ code: 'invalid_payload', message: params.error.message });
    const body = AnswerRequest.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ code: 'invalid_payload', message: body.error.message });
    const user = userRepo.ensureSingleton();
    try {
      const result = service.submitAnswer({
        lessonId: params.data.lessonId,
        questionId: body.data.questionId,
        ...(body.data.optionIndex !== undefined ? { optionIndex: body.data.optionIndex } : {}),
        ...(body.data.typedAnswer !== undefined ? { typedAnswer: body.data.typedAnswer } : {}),
        answerMs: body.data.answerMs,
        userId: user.id,
      });
      return result;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'answer failed';
      return reply.code(404).send({ code: 'question_not_found', message });
    }
  });

  app.post('/v1/lessons/:lessonId/skip', async (req, reply) => {
    const params = z.object({ lessonId: Uuid }).safeParse(req.params);
    if (!params.success) return reply.code(400).send({ code: 'invalid_payload', message: params.error.message });
    const body = SkipRequest.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ code: 'invalid_payload', message: body.error.message });
    const user = userRepo.ensureSingleton();
    try {
      const result = service.submitSkip({
        lessonId: params.data.lessonId,
        questionId: body.data.questionId,
        answerMs: body.data.answerMs,
        userId: user.id,
      });
      return result;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'skip failed';
      return reply.code(404).send({ code: 'question_not_found', message });
    }
  });

  app.post('/v1/lessons/:lessonId/complete', async (req, reply) => {
    const params = z.object({ lessonId: Uuid }).safeParse(req.params);
    if (!params.success) return reply.code(400).send({ code: 'invalid_payload', message: params.error.message });
    try {
      const summary = service.completeLesson({ lessonId: params.data.lessonId });
      req.log.info({ lessonId: summary.lessonId, score: summary.score }, 'lesson.completed');
      return summary;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'complete failed';
      return reply.code(404).send({ code: 'lesson_not_found', message });
    }
  });
}
