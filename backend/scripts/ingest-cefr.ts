#!/usr/bin/env tsx
/**
 * One-shot ingestion: read data/cefr/*.json into vocabulary_words, build
 * RAGSource rows from canonical definitions + examples, generate embeddings
 * via Ollama, and persist the HNSW index alongside SQLite.
 *
 * Idempotent: clears existing RAG sources at the active schema version and
 * rebuilds. The corpus table is loaded on demand via loadCorpusIfEmpty.
 */
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openDb } from '../src/store/db.js';
import { loadCorpusIfEmpty } from '../src/store/corpusLoader.js';
import { WordRepository } from '../src/store/wordRepository.js';
import { RagSourceRepository, type NewRagSource } from '../src/store/ragSourceRepository.js';
import { RagIndex } from '../src/rag/index.js';
import { OllamaAdapter } from '../src/llm/ollama.js';

const REPO_ROOT = join(fileURLToPath(import.meta.url), '..', '..', '..');
const EMBEDDING_MODEL = process.env.GRAMART_EMBEDDING_MODEL ?? 'nomic-embed-text';
const SCHEMA_VERSION = 1;

async function main(): Promise<void> {
  const dbFilename = process.env.GRAMART_DB ?? join(REPO_ROOT, '.gramart', 'app.db');
  mkdirSync(dirname(dbFilename), { recursive: true });
  const db = openDb({ filename: dbFilename });

  const loaded = loadCorpusIfEmpty(db, join(REPO_ROOT, 'data', 'cefr'));
  process.stdout.write(`corpus loaded: ${JSON.stringify(loaded)}\n`);

  const wordRepo = new WordRepository(db);
  const ragRepo = new RagSourceRepository(db);
  const llm = new OllamaAdapter();

  ragRepo.truncateAll();

  const entries: NewRagSource[] = [];
  const words = wordRepo.byLevel('A1')
    .concat(wordRepo.byLevel('A2'))
    .concat(wordRepo.byLevel('B1'))
    .concat(wordRepo.byLevel('B2'))
    .concat(wordRepo.byLevel('C1'))
    .concat(wordRepo.byLevel('C2'));
  process.stdout.write(`embedding ${words.length} word entries…\n`);

  const probe = await llm.embed({ model: EMBEDDING_MODEL, input: 'dimension probe' });
  const dim = probe.embedding.length;
  process.stdout.write(`embedding dim: ${dim}\n`);

  for (const word of words) {
    // Definition source
    const defText = `${word.base} (${word.pos}, ${word.level}): ${word.canonicalDefinition}`;
    const defEmbed = await llm.embed({ model: EMBEDDING_MODEL, input: defText });
    entries.push({
      kind: 'definition',
      wordId: word.id,
      level: word.level,
      content: word.canonicalDefinition,
      embedding: defEmbed.embedding,
      embeddingModel: `${EMBEDDING_MODEL}@v1`,
      schemaVersion: SCHEMA_VERSION,
    });
    // Example sources
    for (const example of word.canonicalExamples) {
      const exEmbed = await llm.embed({ model: EMBEDDING_MODEL, input: example });
      entries.push({
        kind: 'example',
        wordId: word.id,
        level: word.level,
        content: example,
        embedding: exEmbed.embedding,
        embeddingModel: `${EMBEDDING_MODEL}@v1`,
        schemaVersion: SCHEMA_VERSION,
      });
    }
  }

  const ids = ragRepo.insertMany(entries);
  process.stdout.write(`inserted ${ids.length} rag_sources rows\n`);

  // Build HNSW index file
  const index = new RagIndex(dirname(dbFilename), SCHEMA_VERSION, dim);
  index.rebuild(
    entries.map((e, i) => ({
      ragSourceId: ids[i]!,
      embedding: e.embedding!,
    })),
  );
  process.stdout.write(`rebuilt HNSW index with ${entries.length} vectors\n`);
  db.close();
}

main().catch((err) => {
  process.stderr.write(`ingest failed: ${err instanceof Error ? err.stack ?? err.message : String(err)}\n`);
  process.exit(1);
});
