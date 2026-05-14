import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Fastify, { type FastifyInstance } from 'fastify';
import { correlationIdPlugin } from './observability/correlationId.js';
import { createLogger } from './observability/logger.js';
import { openDb } from './store/db.js';
import { getCurrentVersion } from './store/migrations/runner.js';
import { loadCorpusIfEmpty } from './store/corpusLoader.js';
import { UserRepository } from './store/userRepository.js';
import { registerPlacementRoutes } from './routes/placement.js';
import { registerLessonRoutes } from './routes/lessons.js';
import { registerWordsRoutes } from './routes/words.js';
import { registerProgressRoutes } from './routes/progress.js';
import { registerMeRoutes } from './routes/me.js';
import { RagIndex } from './rag/index.js';
import type Database from 'better-sqlite3';
import { OllamaAdapter, type LlmAdapter } from './llm/ollama.js';

export interface ServerOptions {
  dbFilename?: string;
  llm?: LlmAdapter;
  host?: string;
  port?: number;
  repoRoot?: string;
  /** When true, skip auto-loading the CEFR corpus on boot (used by tests that seed their own data). */
  skipCorpusBootstrap?: boolean;
  /** Override the RAG index directory. Defaults to dbFilename's directory. */
  ragIndexDir?: string;
  /** Override the chat / embedding model identifiers. */
  chatModel?: string;
  embeddingModel?: string;
  /** Override the RAG index embedding dimension (default 768 for nomic-embed-text). */
  ragIndexDim?: number;
}

export interface BuiltServer {
  app: FastifyInstance;
  db: Database.Database;
  llm: LlmAdapter;
}

function readVersionJson(repoRoot: string): { version: string; schemaVersion: number } {
  const path = join(repoRoot, 'version.json');
  return JSON.parse(readFileSync(path, 'utf8')) as { version: string; schemaVersion: number };
}

function defaultRepoRoot(): string {
  return join(fileURLToPath(import.meta.url), '..', '..', '..');
}

export async function buildServer(opts: ServerOptions = {}): Promise<BuiltServer> {
  const repoRoot = opts.repoRoot ?? defaultRepoRoot();
  const versionJson = readVersionJson(repoRoot);
  const logger = createLogger();
  const app = Fastify({ loggerInstance: logger, disableRequestLogging: false });

  const db = openDb({ filename: opts.dbFilename ?? ':memory:' });
  const llm = opts.llm ?? new OllamaAdapter();

  if (!opts.skipCorpusBootstrap) {
    const result = loadCorpusIfEmpty(db, join(repoRoot, 'data', 'cefr'));
    if (result.inserted > 0) {
      logger.info({ inserted: result.inserted, total: result.total }, 'corpus.loaded');
    }
    new UserRepository(db).ensureSingleton();
  }

  await app.register(correlationIdPlugin);
  await registerPlacementRoutes(app, { db });
  await registerLessonRoutes(app, { db });

  // RAG index: try to load on boot. If absent/mismatched, retain a non-ready
  // index so the route still works (falls back to canonical examples).
  const chatModel = opts.chatModel ?? 'llama3.1:8b-instruct-q4_K_M';
  const embeddingModel = opts.embeddingModel ?? 'nomic-embed-text';
  const ragIndexDim = opts.ragIndexDim ?? 768;
  const ragIndexDir = opts.ragIndexDir ?? (opts.dbFilename && opts.dbFilename !== ':memory:'
    ? dirname(opts.dbFilename)
    : join(repoRoot, '.gramart'));
  const index = new RagIndex(ragIndexDir, versionJson.schemaVersion ?? 1, ragIndexDim);
  try {
    if (index.load()) {
      logger.info({ size: index.size() }, 'rag.index.loaded');
    } else {
      logger.info('rag.index.not_built — /words/* will use canonical fallback until ingestion runs');
    }
  } catch (err) {
    logger.warn({ err }, 'rag.index.load_failed');
  }
  await registerWordsRoutes(app, { db, index: index.isReady() ? index : null, llm, chatModel, embeddingModel });
  await registerProgressRoutes(app, { db });
  await registerMeRoutes(app, { db });

  app.get('/v1/health', async () => ({
    status: 'ok' as const,
    version: versionJson.version,
    schemaVersion: getCurrentVersion(db),
    ollamaAvailable: await llm.isAvailable(),
  }));

  app.get('/v1/levels', async () => [
    { code: 'A1', label: 'Beginner' },
    { code: 'A2', label: 'Elementary' },
    { code: 'B1', label: 'Intermediate' },
    { code: 'B2', label: 'Upper-intermediate' },
    { code: 'C1', label: 'Advanced' },
    { code: 'C2', label: 'Proficient' },
  ]);

  app.addHook('onClose', async () => {
    db.close();
  });

  return { app, db, llm };
}

export async function startServer(opts: ServerOptions = {}): Promise<{ port: number; close: () => Promise<void> }> {
  const { app } = await buildServer(opts);
  const address = await app.listen({ host: opts.host ?? '127.0.0.1', port: opts.port ?? 0 });
  const url = new URL(address);
  const port = Number.parseInt(url.port, 10);
  return {
    port,
    close: async () => {
      await app.close();
    },
  };
}

/** When invoked directly (production / dev), perform the stdout handshake and run. */
async function main(): Promise<void> {
  const repoRoot = process.env.GRAMART_REPO_ROOT ?? defaultRepoRoot();
  const versionJson = readVersionJson(repoRoot);
  const dbFilename = process.env.GRAMART_DB ?? join(repoRoot, '.gramart', 'app.db');
  if (dbFilename !== ':memory:') {
    mkdirSync(dirname(dbFilename), { recursive: true });
  }
  const chatModel = process.env.GRAMART_CHAT_MODEL;
  const embeddingModel = process.env.GRAMART_EMBEDDING_MODEL;
  const { app } = await buildServer({
    dbFilename,
    repoRoot,
    ...(chatModel ? { chatModel } : {}),
    ...(embeddingModel ? { embeddingModel } : {}),
  });
  const address = await app.listen({ host: '127.0.0.1', port: 0 });
  const url = new URL(address);
  const port = Number.parseInt(url.port, 10);

  // Single-line JSON handshake for the macOS parent process.
  process.stdout.write(`${JSON.stringify({ port, pid: process.pid, version: versionJson.version })}\n`);

  const shutdown = async (): Promise<void> => {
    await app.close();
    process.exit(0);
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

const invokedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (invokedDirectly) {
  main().catch((err) => {
    process.stderr.write(`fatal: ${err instanceof Error ? err.stack ?? err.message : String(err)}\n`);
    process.exit(1);
  });
}
