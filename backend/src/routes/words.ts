import type { FastifyInstance } from 'fastify';
import type Database from 'better-sqlite3';
import { z } from 'zod';
import { CefrLevel } from '../domain/schemas.js';
import { WordRepository } from '../store/wordRepository.js';
import { RagSourceRepository } from '../store/ragSourceRepository.js';
import { AiGenerationRepository } from '../store/aiGenerationRepository.js';
import type { RagIndex } from '../rag/index.js';
import type { LlmAdapter } from '../llm/ollama.js';
import { AiGenerationService } from '../llm/aiGenerationService.js';

const Query = z.object({ level: CefrLevel });
const Params = z.object({ word: z.string().min(1).max(80) });

export interface WordsRouteDeps {
  db: Database.Database;
  index: RagIndex | null;
  llm: LlmAdapter;
  chatModel: string;
  embeddingModel: string;
}

export async function registerWordsRoutes(app: FastifyInstance, deps: WordsRouteDeps): Promise<void> {
  const service = new AiGenerationService({
    words: new WordRepository(deps.db),
    ragSources: new RagSourceRepository(deps.db),
    aiGenerations: new AiGenerationRepository(deps.db),
    index: deps.index,
    llm: deps.llm,
    chatModel: deps.chatModel,
    embeddingModel: deps.embeddingModel,
  });

  app.get('/v1/words/:word/examples', async (req, reply) => {
    const p = Params.safeParse(req.params);
    const q = Query.safeParse(req.query);
    if (!p.success || !q.success) {
      return reply.code(400).send({ code: 'invalid_payload', message: 'word and level are required' });
    }
    const result = await service.getExamples(p.data.word.toLowerCase(), q.data.level, req.correlationId);
    if (!result) return reply.code(404).send({ code: 'word_not_found', message: 'unknown word' });
    if (result.fallback) reply.code(503);
    return result;
  });

  app.get('/v1/words/:word/definition', async (req, reply) => {
    const p = Params.safeParse(req.params);
    const q = Query.safeParse(req.query);
    if (!p.success || !q.success) {
      return reply.code(400).send({ code: 'invalid_payload', message: 'word and level are required' });
    }
    const result = await service.getDefinition(p.data.word.toLowerCase(), q.data.level, req.correlationId);
    if (!result) return reply.code(404).send({ code: 'word_not_found', message: 'unknown word' });
    if (result.fallback) reply.code(503);
    return result;
  });
}
