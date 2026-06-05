import { randomUUID } from 'node:crypto';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type Database from 'better-sqlite3';
import { z } from 'zod';
import { Uuid } from '../domain/schemas.js';
import { WordRepository } from '../store/wordRepository.js';
import { UserRepository } from '../store/userRepository.js';
import { PlacementRepository } from '../store/placementRepository.js';
import {
  selectPlacementQuestions,
  pickQuestionForLevel,
  type PlacementQuestion,
} from '../lessons/placementSelector.js';
import { scorePlacement, buildPerLevelScores } from '../lessons/placementScorer.js';
import {
  createState,
  pickNextLevel,
  step as adaptiveStep,
  done as adaptiveDone,
  finalize as adaptiveFinalize,
  toPerLevelScores,
  levelFromIdx,
  ALGORITHM_VERSION,
  MAX_ITEMS,
  type AdaptivePlacementState,
  type SelfReport,
} from '../lessons/adaptivePlacement.js';

/**
 * In-memory store of in-flight placements. The MVP is single-user, single-process;
 * persisting placement question banks to disk would only add noise.
 *
 * F005: now supports two variants tagged by `algorithmVersion`.
 */
interface InFlightPlacement {
  id: string;
  algorithmVersion: 'v1' | 'v2';
  startedAt: number;
  /** v1 only — fixed list of 24 questions. */
  questions?: PlacementQuestion[];
  /** v2 only — adaptive algorithm state. */
  state?: AdaptivePlacementState;
  /** Both — every question delivered so far (looked up by id on /answer). */
  delivered: PlacementQuestion[];
}

const placements = new Map<string, InFlightPlacement>();

const SelfReportEnum = z.enum(['never', 'some', 'lots']);

const StartRequest = z
  .object({
    seed: z.number().int().optional(),
    selfReport: SelfReportEnum.nullish(),
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

const AnswerRequest = z.object({
  placementId: Uuid,
  questionId: Uuid,
  optionIndex: z.number().int().min(-1).max(3),
});

export interface PlacementRouteDeps {
  db: Database.Database;
}

function isAdaptiveClient(req: FastifyRequest): boolean {
  const raw = req.headers['x-client-version'];
  const v = Array.isArray(raw) ? raw[0] : raw;
  if (!v) return false;
  // Anything ≥ 1.4 is adaptive. We don't parse semver — string-prefix is enough
  // for the desktop client which sends exactly its `version.json` value.
  return /^1\.(4|5|6|7|8|9|[1-9][0-9])/.test(v) || /^[2-9]\./.test(v);
}

function wireQuestion(q: PlacementQuestion): {
  id: string;
  word: string;
  sentence: string;
  options: string[];
  level: string;
} {
  return {
    id: q.id,
    word: q.word,
    sentence: q.sentence,
    options: q.options,
    level: q.level,
  };
}

export async function registerPlacementRoutes(app: FastifyInstance, deps: PlacementRouteDeps): Promise<void> {
  const wordRepo = new WordRepository(deps.db);
  const userRepo = new UserRepository(deps.db);
  const placementRepo = new PlacementRepository(deps.db);

  app.post('/v1/placement/start', async (req, reply) => {
    const parsed = StartRequest.safeParse(req.body ?? {});
    const seed = parsed.success ? parsed.data?.seed : undefined;
    const selfReport: SelfReport | null = parsed.success ? (parsed.data?.selfReport ?? null) : null;

    if (!isAdaptiveClient(req)) {
      // ──────────── Legacy v1 path (v1.3 clients) ────────────
      const questions = selectPlacementQuestions(wordRepo, seed !== undefined ? { seed } : {});
      if (questions.length === 0) {
        throw app.httpErrors?.serviceUnavailable
          ? app.httpErrors.serviceUnavailable('No CEFR corpus available')
          : new Error('No CEFR corpus available');
      }
      const placementId = randomUUID();
      placements.set(placementId, {
        id: placementId,
        algorithmVersion: 'v1',
        startedAt: Date.now(),
        questions,
        delivered: questions,
      });
      req.log.info({ placementId, count: questions.length, algorithmVersion: 'v1' }, 'placement.started');
      return {
        placementId,
        questions: questions.map(wireQuestion),
      };
    }

    // ──────────── Adaptive v2 path ────────────
    const state = createState({ selfReport });
    const idx = pickNextLevel(state);
    const level = levelFromIdx(idx);
    const first = pickQuestionForLevel(
      wordRepo,
      level,
      new Set(),
      seed !== undefined ? seed : undefined,
    );
    if (!first) {
      return reply
        .code(503)
        .send({ code: 'no_corpus', message: 'No CEFR corpus available' });
    }
    const placementId = randomUUID();
    placements.set(placementId, {
      id: placementId,
      algorithmVersion: 'v2',
      startedAt: Date.now(),
      state,
      delivered: [first],
    });
    req.log.info(
      { placementId, algorithmVersion: ALGORITHM_VERSION, selfReport, firstLevel: level },
      'placement.started',
    );
    return {
      placementId,
      question: wireQuestion(first),
      progress: { current: 1, max: MAX_ITEMS },
      algorithmVersion: ALGORITHM_VERSION,
    };
  });

  app.post('/v1/placement/answer', async (req, reply) => {
    const parsed = AnswerRequest.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({ code: 'invalid_payload', message: parsed.error.message });
    }
    const { placementId, questionId, optionIndex } = parsed.data;
    const inflight = placements.get(placementId);
    if (!inflight || inflight.algorithmVersion !== 'v2' || !inflight.state) {
      return reply.code(404).send({ code: 'placement_not_found', message: 'placement not found or expired' });
    }
    const question = inflight.delivered.find((q) => q.id === questionId);
    if (!question) {
      return reply.code(404).send({ code: 'question_not_in_placement', message: 'unknown questionId' });
    }
    const correct = optionIndex >= 0 && optionIndex === question.correctIndex;
    const before = inflight.state.levelEstimate;
    const nextState = adaptiveStep(inflight.state, question.level, correct);
    inflight.state = nextState;
    req.log.info(
      {
        placementId,
        position: nextState.itemsAdministered,
        selectedLevel: question.level,
        levelEstimateBefore: before,
        levelEstimateAfter: nextState.levelEstimate,
        confidence: nextState.confidence,
        correct,
        algorithmVersion: ALGORITHM_VERSION,
      },
      'placement.item',
    );

    if (adaptiveDone(nextState)) {
      const estimatedLevel = adaptiveFinalize(nextState);
      const user = userRepo.ensureSingleton();
      userRepo.setLevel(user.id, estimatedLevel);
      const perLevelScores = toPerLevelScores(nextState);
      placementRepo.create({
        userId: user.id,
        perLevelScores,
        estimatedLevel,
        userOverride: null,
        algorithmVersion: ALGORITHM_VERSION,
        itemsAdministered: nextState.itemsAdministered,
      });
      placements.delete(placementId);
      req.log.info(
        {
          placementId,
          estimatedLevel,
          itemsAdministered: nextState.itemsAdministered,
          algorithmVersion: ALGORITHM_VERSION,
          selfReport: nextState.selfReport,
        },
        'placement.completed',
      );
      return {
        kind: 'done',
        result: {
          estimatedLevel,
          perLevelScores,
          algorithmVersion: ALGORITHM_VERSION,
          itemsAdministered: nextState.itemsAdministered,
        },
      };
    }

    // Pick the next question.
    const usedWordIds = new Set(inflight.delivered.map((q) => q.wordId));
    const idx = pickNextLevel(nextState);
    let level = levelFromIdx(idx);
    let next = pickQuestionForLevel(wordRepo, level, usedWordIds);
    // Walk outward if the chosen level is exhausted (rare on the small corpus).
    if (!next) {
      const tried = new Set<string>([level]);
      for (const offset of [-1, 1, -2, 2, -3, 3, -4, 4, -5, 5]) {
        const altIdx = Math.max(1, Math.min(6, idx + offset)) as 1 | 2 | 3 | 4 | 5 | 6;
        const alt = levelFromIdx(altIdx);
        if (tried.has(alt)) continue;
        tried.add(alt);
        next = pickQuestionForLevel(wordRepo, alt, usedWordIds);
        if (next) {
          level = alt;
          break;
        }
      }
    }
    if (!next) {
      // Corpus fully exhausted — force-finalize.
      const estimatedLevel = adaptiveFinalize(nextState);
      const user = userRepo.ensureSingleton();
      userRepo.setLevel(user.id, estimatedLevel);
      const perLevelScores = toPerLevelScores(nextState);
      placementRepo.create({
        userId: user.id,
        perLevelScores,
        estimatedLevel,
        userOverride: null,
        algorithmVersion: ALGORITHM_VERSION,
        itemsAdministered: nextState.itemsAdministered,
      });
      placements.delete(placementId);
      return {
        kind: 'done',
        result: {
          estimatedLevel,
          perLevelScores,
          algorithmVersion: ALGORITHM_VERSION,
          itemsAdministered: nextState.itemsAdministered,
        },
      };
    }
    inflight.delivered.push(next);
    return {
      kind: 'continue',
      question: wireQuestion(next),
      progress: { current: nextState.itemsAdministered + 1, max: MAX_ITEMS },
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
    if (inflight.algorithmVersion !== 'v1' || !inflight.questions) {
      // A v2 placement submitted via the legacy batch endpoint — unsupported.
      return reply.code(409).send({ code: 'wrong_endpoint', message: 'use /v1/placement/answer for adaptive placements' });
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
      algorithmVersion: 'v1',
    });

    placements.delete(placementId);
    req.log.info({ placementId, estimatedLevel, algorithmVersion: 'v1' }, 'placement.completed');
    return {
      estimatedLevel,
      perLevelScores: scores,
      algorithmVersion: 'v1',
    };
  });
}

/** Test helper: clears the in-memory placement store. */
export function _resetPlacementStoreForTests(): void {
  placements.clear();
}
