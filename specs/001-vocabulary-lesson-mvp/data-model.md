# Phase 1 Data Model: Vocabulary Lesson MVP

**Date**: 2026-05-12

This document defines the persistent data model for the embedded backend's SQLite store and the in-memory shapes shared with the macOS client. Field types are given in a backend-agnostic notation; the SQLite schema column types are listed where they differ.

## Entities

### User

The single local student. Created on first launch with no personal information.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (TEXT) | Opaque, locally generated. PK. |
| `currentLevel` | CEFRLevel (TEXT) | One of A1, A2, B1, B2, C1, C2. Set after placement test; user-editable. |
| `createdAt` | ISO8601 timestamp (TEXT) | Local creation time. |
| `accessibilityPrefs` | JSON (TEXT) | Reduce motion / large text overrides if user opts in. Default `{}`. |

Constraints: exactly one row in MVP (single-user). No name, email, age, or external identifier.

### CEFRLevel (enum)

`A1 | A2 | B1 | B2 | C1 | C2`. Persisted as TEXT.

### VocabularyWord

A curated entry from the CEFR corpus. Source of truth for definitions.

| Field | Type | Notes |
|-------|------|-------|
| `id` | INTEGER | PK. Stable across releases. |
| `base` | TEXT | Lemma form (e.g., "ephemeral"). UNIQUE. |
| `pos` | TEXT | Part of speech: `noun`, `verb`, `adjective`, `adverb`, etc. |
| `level` | CEFRLevel | The CEFR level the word is mapped to. INDEXED. |
| `canonicalDefinition` | TEXT | Author-written, ≤ 200 chars. |
| `canonicalExamples` | JSON (TEXT) | Array of 0–3 example sentences. |
| `sourceTag` | TEXT | Provenance: `cefr-j`, `evp`, `tatoeba`, `author`. |
| `addedAt` | ISO8601 (TEXT) | Build-time timestamp. |

### Lesson

A single quiz session of (default) 10 questions.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (TEXT) | PK. |
| `userId` | UUID (TEXT) | FK → User.id. |
| `level` | CEFRLevel | Snapshot of the user's level at lesson start. |
| `state` | TEXT | `in_progress`, `completed`, `abandoned`. |
| `startedAt` | ISO8601 (TEXT) | |
| `completedAt` | ISO8601 nullable | |
| `score` | INTEGER nullable | Set on completion: count of correct answers. |
| `correlationId` | TEXT | UUID; propagates to every related log line. |

State transitions:

```text
in_progress ──(complete()  )──▶ completed
in_progress ──(abandon()   )──▶ abandoned
```

Transitions are one-way; a completed or abandoned lesson never re-opens. A new lesson always means a new row.

### Question

A single question inside a lesson.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (TEXT) | PK. |
| `lessonId` | UUID (TEXT) | FK → Lesson.id. INDEXED. |
| `position` | INTEGER | 0..N-1 within the lesson. |
| `wordId` | INTEGER | FK → VocabularyWord.id. |
| `options` | JSON (TEXT) | Array of exactly 4 strings (definitions). |
| `correctIndex` | INTEGER | 0–3. |
| `selectedIndex` | INTEGER nullable | Set when the user answers. |
| `correct` | BOOLEAN nullable | Derived; persisted for query speed. |
| `answeredAt` | ISO8601 nullable | |
| `answerMs` | INTEGER nullable | Time from question shown to answer. |

Constraints:

- Within a Lesson, `wordId` is unique (FR-013: no duplicate words in one lesson).
- Each Question MUST have exactly one correct option among the 4.
- Question selection follows the **50/30/20 mix** (FR-013a) computed at lesson creation time from the user's WordMastery rows.

### WordMastery

The user's per-word state.

| Field | Type | Notes |
|-------|------|-------|
| `userId` | UUID (TEXT) | FK → User. PK part 1. |
| `wordId` | INTEGER | FK → VocabularyWord. PK part 2. |
| `consecutiveCorrect` | INTEGER | Resets to 0 on a miss. |
| `totalCorrect` | INTEGER | Cumulative. |
| `totalIncorrect` | INTEGER | Cumulative. |
| `lastSeenAt` | ISO8601 (TEXT) | |
| `mastered` | BOOLEAN | TRUE when `consecutiveCorrect >= 2`. |

Derived rule: `mastered = consecutiveCorrect >= 2`. Persisted for indexed lookup of mastery growth (SC-008).

### PlacementResult

The outcome of a placement test.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (TEXT) | PK. |
| `userId` | UUID (TEXT) | FK → User. |
| `takenAt` | ISO8601 (TEXT) | |
| `perLevelScores` | JSON (TEXT) | `{ "A1": 2, "A2": 2, ... }` correct out of attempted per level. |
| `estimatedLevel` | CEFRLevel | Output of the scoring rule. |
| `userOverride` | CEFRLevel nullable | If the user later changed it in Settings. |

### RAGSource

A passage indexed for retrieval. Embeddings are stored alongside for `hnswlib-node` rebuild.

| Field | Type | Notes |
|-------|------|-------|
| `id` | INTEGER | PK. |
| `kind` | TEXT | `definition`, `example`, `usage_note`. |
| `wordId` | INTEGER nullable | FK → VocabularyWord when the passage is word-anchored. |
| `level` | CEFRLevel nullable | Best-fit level if known. |
| `content` | TEXT | The passage text. ≤ 500 chars. |
| `embedding` | BLOB | Embedding vector (Float32) from `nomic-embed-text`. |
| `embeddingModel` | TEXT | Model name + version, e.g. `nomic-embed-text@v1`. |
| `schemaVersion` | INTEGER | Bumped when the indexing schema changes. INDEXED. |
| `addedAt` | ISO8601 (TEXT) | |

The HNSW index file (`rag.index`) is rebuilt from these rows when `schemaVersion` mismatches at boot.

### AIGeneration

A record of every LLM call. Persisted for diagnostics and replay (Principle IV).

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (TEXT) | PK. |
| `correlationId` | TEXT | Matches the originating HTTP request. INDEXED. |
| `wordId` | INTEGER nullable | FK → VocabularyWord. |
| `kind` | TEXT | `examples`, `contextual_definition`. |
| `targetLevel` | CEFRLevel | The user's level passed to the prompt. |
| `model` | TEXT | e.g. `llama3.1:8b-instruct-q4_K_M`. |
| `promptHash` | TEXT | SHA-256 of the assembled prompt. |
| `ragSourceIds` | JSON (TEXT) | IDs of retrieved RAGSource rows used in the prompt. |
| `output` | TEXT | Final generated text. |
| `firstTokenMs` | INTEGER | Latency to first token. |
| `totalMs` | INTEGER | End-to-end latency. |
| `createdAt` | ISO8601 (TEXT) | |

## Relationships

```text
User 1───* Lesson 1───* Question *───1 VocabularyWord
User 1───* WordMastery *───1 VocabularyWord
User 1───* PlacementResult
VocabularyWord 1───* RAGSource
AIGeneration *───1 VocabularyWord   (optional)
```

## SQLite migration plan

- `0001_init.sql` — creates all tables above with the indexes listed.
- `PRAGMA user_version` is bumped to `1` after `0001`.
- Future migrations are append-only files (`0002_*.sql`, ...) loaded at backend startup; migrations run inside a single transaction.

## Validation rules (enforced by `zod` in the backend)

- `VocabularyWord.canonicalDefinition`: 1–200 chars, no leading/trailing whitespace.
- `Question.options`: exactly 4 strings; all distinct; `correctIndex` ∈ [0, 3].
- `Lesson`: question count fixed at 10 in MVP (configurable internally).
- `PlacementResult.perLevelScores`: keys must be a subset of the 6 CEFR levels.
- `AIGeneration.output`: must contain `VocabularyWord.base` or a morphological variant (validated against a small inflection rule set; failure logs a warning but does not fail the response — falls back to canonical example).

## Concurrency

Single-user, single-process: no row-level locking concerns beyond SQLite's WAL mode (enabled at boot for read/write concurrency between routes and the ingest worker).
