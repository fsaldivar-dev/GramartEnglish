import type { CefrLevel } from '../domain/schemas.js';
import type { VocabularyWordRow, WordRepository } from '../store/wordRepository.js';
import type { RagSourceRow, RagSourceRepository } from '../store/ragSourceRepository.js';
import type { RagIndex } from './index.js';
import type { LlmAdapter } from '../llm/ollama.js';

export interface RetrievalContext {
  word: VocabularyWordRow;
  level: CefrLevel;
  sources: RagSourceRow[];
}

export interface RetrieverDeps {
  words: WordRepository;
  ragSources: RagSourceRepository;
  index: RagIndex | null;
  llm: LlmAdapter;
  embeddingModel: string;
}

export interface RetrieveOpts {
  k?: number;
}

/**
 * Two-stage retrieval per research.md §4:
 *   1. Lexical lookup of the word entry (canonical definition + examples).
 *   2. If a HNSW index is loaded, semantic k-NN over RAGSource embeddings
 *      using the query "<word> at <level>". Otherwise we return word-anchored
 *      sources only.
 */
export async function retrieve(
  base: string,
  level: CefrLevel,
  deps: RetrieverDeps,
  opts: RetrieveOpts = {},
): Promise<RetrievalContext | null> {
  const word = deps.words.byBase(base);
  if (!word) return null;

  let semantic: RagSourceRow[] = [];
  if (deps.index && deps.index.isReady() && deps.index.size() > 0) {
    const k = opts.k ?? 5;
    try {
      const { embedding } = await deps.llm.embed({ model: deps.embeddingModel, input: `${base} (${level}): meaning and usage` });
      const knn = deps.index.knn(embedding, k);
      semantic = deps.ragSources.byIds(knn.map((r) => r.ragSourceId));
    } catch {
      semantic = [];
    }
  }

  // Always include word-anchored sources first.
  const wordAnchored = deps.ragSources.byWordId(word.id);
  const seen = new Set<number>();
  const combined: RagSourceRow[] = [];
  for (const r of [...wordAnchored, ...semantic]) {
    if (seen.has(r.id)) continue;
    seen.add(r.id);
    combined.push(r);
  }

  return { word, level, sources: combined };
}
