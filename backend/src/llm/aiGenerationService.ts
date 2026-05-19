import type { CefrLevel } from '../domain/schemas.js';
import type { WordRepository } from '../store/wordRepository.js';
import type { RagSourceRepository } from '../store/ragSourceRepository.js';
import type { AiGenerationRepository, AiKind } from '../store/aiGenerationRepository.js';
import type { LlmAdapter } from './ollama.js';
import type { RagIndex } from '../rag/index.js';
import { retrieve } from '../rag/retriever.js';
import { buildPromptFor } from '../rag/promptBuilder.js';
import { validateDefinition, validateExamples } from './outputValidator.js';

export interface AiServiceDeps {
  words: WordRepository;
  ragSources: RagSourceRepository;
  aiGenerations: AiGenerationRepository;
  index: RagIndex | null;
  llm: LlmAdapter;
  chatModel: string;
  embeddingModel: string;
}

export interface ExamplesResult {
  examples: string[];
  sourceIds: number[];
  generatedBy: 'llm' | 'fallback_canonical';
  fallback: boolean;
}

export interface DefinitionResult {
  definition: string;
  sourceIds: number[];
  generatedBy: 'llm' | 'fallback_canonical';
  fallback: boolean;
}

export class AiGenerationService {
  constructor(private deps: AiServiceDeps) {}

  async getExamples(base: string, level: CefrLevel, correlationId: string): Promise<ExamplesResult | null> {
    const ctx = await retrieve(base, level, this.deps);
    if (!ctx) return null;
    return this.runWithFallback({
      kind: 'examples',
      correlationId,
      level,
      run: async () => {
        const prompt = buildPromptFor('examples', ctx);
        const chat = await this.deps.llm.chat({ model: this.deps.chatModel, system: prompt.system, user: prompt.user });
        const validated = validateExamples(chat.text, ctx.word.base);
        return { prompt, chat, validated };
      },
      onSuccess: ({ chat, validated, prompt }) => {
        if (!validated.ok) throw new Error(validated.reason ?? 'invalid output');
        this.deps.aiGenerations.insert({
          correlationId,
          wordId: ctx.word.id,
          kind: 'examples',
          targetLevel: level,
          model: this.deps.chatModel,
          promptHash: prompt.promptHash,
          ragSourceIds: ctx.sources.map((s) => s.id),
          output: validated.examples.join('\n'),
          firstTokenMs: chat.firstTokenMs,
          totalMs: chat.totalMs,
        });
        return {
          examples: validated.examples,
          sourceIds: ctx.sources.map((s) => s.id),
          generatedBy: 'llm',
          fallback: false,
        } as ExamplesResult;
      },
      fallback: () => fallbackExamples(ctx.word.canonicalExamples, ctx.word.canonicalDefinition),
    });
  }

  async getDefinition(base: string, level: CefrLevel, correlationId: string): Promise<DefinitionResult | null> {
    const ctx = await retrieve(base, level, this.deps);
    if (!ctx) return null;
    return this.runWithFallback({
      kind: 'contextual_definition',
      correlationId,
      level,
      run: async () => {
        const prompt = buildPromptFor('contextual_definition', ctx);
        const chat = await this.deps.llm.chat({ model: this.deps.chatModel, system: prompt.system, user: prompt.user });
        const validated = validateDefinition(chat.text, ctx.word.base);
        return { prompt, chat, validated };
      },
      onSuccess: ({ chat, validated, prompt }) => {
        if (!validated.ok) throw new Error(validated.reason ?? 'invalid output');
        this.deps.aiGenerations.insert({
          correlationId,
          wordId: ctx.word.id,
          kind: 'contextual_definition',
          targetLevel: level,
          model: this.deps.chatModel,
          promptHash: prompt.promptHash,
          ragSourceIds: ctx.sources.map((s) => s.id),
          output: validated.definition,
          firstTokenMs: chat.firstTokenMs,
          totalMs: chat.totalMs,
        });
        return {
          definition: validated.definition,
          sourceIds: ctx.sources.map((s) => s.id),
          generatedBy: 'llm',
          fallback: false,
        } as DefinitionResult;
      },
      fallback: () => ({
        definition: ctx.word.canonicalDefinition,
        sourceIds: [],
        generatedBy: 'fallback_canonical' as const,
        fallback: true,
      }),
    });
  }

  private async runWithFallback<TRun, TResult>(args: {
    kind: AiKind;
    correlationId: string;
    level: CefrLevel;
    run: () => Promise<TRun>;
    onSuccess: (out: TRun) => TResult;
    fallback: () => TResult;
  }): Promise<TResult> {
    const available = await this.deps.llm.isAvailable();
    if (!available) return args.fallback();
    try {
      const out = await args.run();
      return args.onSuccess(out);
    } catch {
      return args.fallback();
    }
  }
}

function fallbackExamples(canonical: string[], canonicalDefinition: string): ExamplesResult {
  if (canonical.length > 0) {
    return {
      examples: canonical.slice(0, 3),
      sourceIds: [],
      generatedBy: 'fallback_canonical',
      fallback: true,
    };
  }
  return {
    examples: [canonicalDefinition],
    sourceIds: [],
    generatedBy: 'fallback_canonical',
    fallback: true,
  };
}
