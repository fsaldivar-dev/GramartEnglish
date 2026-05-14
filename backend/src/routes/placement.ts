import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type Database from 'better-sqlite3';
import { z } from 'zod';
import { Uuid } from '../domain/schemas.js';
import { WordRepository } from '../store/wordRepository.js';
import { UserRepository } from '../store/userRepository.js';
import { PlacementRepository } from '../store/placementRepository.js';
import { selectPlacementQuestions, type PlacementQuestion } from '../lessons/placementSelector.js';
import { scorePlacement, buildPerLevelScores } from '../lessons/placementScorer.js';

/**
 * In-memory store of in-flight placements. The MVP is single-user, single-process;
 * persisting placement question banks to disk would only add noise.
 */
interface InFlightPlacement {
  id: string;
  questions: PlacementQuestion[];
}

const placements = new Map<string, InFlightPlacement>();

const StartRequest = z
  .object({
    seed: z.number().int().optional(),
  })
  .partial()
  .optional();

const SubmitRequest = z.object({
  placementId: Uuid,
  answers: z
    .array(
      z.object({
        questionId: Uuid,
        optionIndex: z.number().int().min(0).max(3),
      }),
    )
    .min(1),
});

export interface PlacementRouteDeps {
  db: Database.Database;
}

export async function registerPlacementRoutes(app: FastifyInstance, deps: PlacementRouteDeps): Promise<void> {
  const wordRepo = new WordRepository(deps.db);
  const userRepo = new UserRepository(deps.db);
  const placementRepo = new PlacementRepository(deps.db);

  app.post('/v1/placement/start', async (req) => {
    const parsed = StartRequest.safeParse(req.body ?? {});
    const seed = parsed.success ? parsed.data?.seed : undefined;
    const questions = selectPlacementQuestions(wordRepo, seed !== undefined ? { seed } : {});
    if (questions.length === 0) {
      throw app.httpErrors?.serviceUnavailable
        ? app.httpErrors.serviceUnavailable('No CEFR corpus available')
        : new Error('No CEFR corpus available');
    }
    const placementId = randomUUID();
    placements.set(placementId, { id: placementId, questions });
    req.log.info({ placementId, count: questions.length }, 'placement.started');
    return {
      placementId,
      questions: questions.map((q) => ({
        id: q.id,
        word: q.word,
        sentence: q.sentence,
        options: q.options,
        level: q.level,
      })),
    };
  });

  app.post('/v1/placement/submit', async (req, reply) => {
    const parsed = SubmitRequest.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({ code: 'invalid_payload', message: parsed.error.message });
    }
    const { placementId, answers } = parsed.data;
    const inflight = placements.get(placementId);
    if (!inflight) {
      return reply.code(404).send({ code: 'placement_not_found', message: 'placement not found or expired' });
    }

    const byQuestionId = new Map(inflight.questions.map((q) => [q.id, q]));
    const scores = buildPerLevelScores();
    for (const a of answers) {
      const q = byQuestionId.get(a.questionId);
      if (!q) continue;
      scores[q.level].attempted += 1;
      if (a.optionIndex === q.correctIndex) scores[q.level].correct += 1;
    }

    const estimatedLevel = scorePlacement(scores);
    const user = userRepo.ensureSingleton();
    userRepo.setLevel(user.id, estimatedLevel);
    placementRepo.create({
      userId: user.id,
      perLevelScores: scores,
      estimatedLevel,
      userOverride: null,
    });

    placements.delete(placementId);
    req.log.info({ placementId, estimatedLevel }, 'placement.completed');
    return { estimatedLevel, perLevelScores: scores };
  });
}

/** Test helper: clears the in-memory placement store. */
export function _resetPlacementStoreForTests(): void {
  placements.clear();
}
