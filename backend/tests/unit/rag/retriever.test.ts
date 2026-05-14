import { describe, it, expect, beforeEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { RagSourceRepository } from '../../../src/store/ragSourceRepository.js';
import { retrieve } from '../../../src/rag/retriever.js';
import { RecordedFakeLlm } from '../../../src/llm/__fakes__/recorded.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

let words: WordRepository;
let ragSources: RagSourceRepository;

beforeEach(() => {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  words = new WordRepository(db);
  ragSources = new RagSourceRepository(db);
});

describe('retrieve', () => {
  it('returns the word entry plus zero sources when no RAG is indexed', async () => {
    const ctx = await retrieve('eat', 'A1', {
      words,
      ragSources,
      index: null,
      llm: new RecordedFakeLlm(),
      embeddingModel: 'fake',
    });
    expect(ctx).not.toBeNull();
    expect(ctx!.word.base).toBe('eat');
    expect(ctx!.level).toBe('A1');
    expect(ctx!.sources).toHaveLength(0);
  });

  it('returns null for unknown words', async () => {
    const ctx = await retrieve('xyzzy', 'A1', {
      words,
      ragSources,
      index: null,
      llm: new RecordedFakeLlm(),
      embeddingModel: 'fake',
    });
    expect(ctx).toBeNull();
  });

  it('includes word-anchored RAG sources without an index', async () => {
    const eatId = words.byBase('eat')!.id;
    ragSources.insertMany([
      {
        kind: 'example',
        wordId: eatId,
        level: 'A1',
        content: 'I eat lunch at noon.',
        embedding: null,
        embeddingModel: 'test',
        schemaVersion: 1,
      },
    ]);
    const ctx = await retrieve('eat', 'A1', {
      words,
      ragSources,
      index: null,
      llm: new RecordedFakeLlm(),
      embeddingModel: 'fake',
    });
    expect(ctx!.sources).toHaveLength(1);
    expect(ctx!.sources[0]?.content).toMatch(/I eat lunch/);
  });
});
