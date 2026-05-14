# Phase 1 Data Model: Listening Modes (delta over 001)

**Date**: 2026-05-14

This document captures **only the changes** over the MVP data model. Anything not mentioned here is unchanged from `specs/001-vocabulary-lesson-mvp/data-model.md`.

## New enum

### LessonMode

A string enum with four values for F002 (verb modes added in F004):

| Value | Description |
|-------|-------------|
| `read_pick_meaning` | The original MVP mode: see English word in context, pick Spanish meaning |
| `listen_pick_word` | Hear English audio, pick the English word from 4 written options |
| `listen_pick_meaning` | Hear English audio, pick the Spanish meaning from 4 options |
| `listen_type` | Hear English audio, type the word (Levenshtein ≤ 1 tolerated) |

Persisted everywhere as the bare snake_case string.

## Modified entities

### `users` table

Add column:

| Field | Type | Notes |
|-------|------|-------|
| `preferredMode` | TEXT NOT NULL DEFAULT `'read_pick_meaning'` | The mode the user picked last; UI restores it on next launch. |

### `lessons` table

Add column:

| Field | Type | Notes |
|-------|------|-------|
| `mode` | TEXT NOT NULL DEFAULT `'read_pick_meaning'` | The mode this lesson was played in. Used for resume, diagnostics, and mastery attribution. |

Existing lessons get `mode = 'read_pick_meaning'` via the `DEFAULT`, no backfill needed.

### `word_mastery` table

This is the **important** change. The composite PK widens from `(userId, wordId)` to `(userId, wordId, mode)`:

| Field | Type | Notes |
|-------|------|-------|
| `userId` | TEXT | unchanged |
| `wordId` | INTEGER | unchanged |
| `mode` | TEXT NOT NULL DEFAULT `'read_pick_meaning'` | new PK component |
| `consecutiveCorrect` | INTEGER | unchanged semantics, but now per-(word,mode) |
| `totalCorrect` | INTEGER | same |
| `totalIncorrect` | INTEGER | same |
| `totalSkipped` | INTEGER | same |
| `lastSeenAt` | TEXT | same |
| `mastered` | INTEGER | same (true iff `consecutiveCorrect >= 2`) |

Mastery is **per-(word, mode)**: knowing "weather" in `read_pick_meaning` does NOT mean it's mastered in `listen_pick_word`. The selector filters by mode when assembling a lesson, so a fresh listening lesson treats all words as new (and the 50/30/20 mix re-establishes for that mode).

### `questions` table

For `listen_type` mode the answer is typed text, not an option index. Add a column:

| Field | Type | Notes |
|-------|------|-------|
| `typedAnswer` | TEXT NULL | Set when the question was answered in a typed mode; null otherwise. |

`options` and `correctIndex` remain populated for option-based questions and are ignored for typed-mode questions (we keep them as `[]` and `0` rather than NULL to avoid downstream NULL checks; the dispatch is by lesson mode, not by these fields).

`correct` semantics: for typed mode, `correct = 1` iff `levenshtein(typedAnswer.lower(), targetWord.lower()) <= 1`.

## Migration 0003_lesson_modes.sql

```sql
-- Adds the LessonMode axis to the system.

ALTER TABLE users ADD COLUMN preferredMode TEXT NOT NULL DEFAULT 'read_pick_meaning';
ALTER TABLE lessons ADD COLUMN mode TEXT NOT NULL DEFAULT 'read_pick_meaning';
ALTER TABLE questions ADD COLUMN typedAnswer TEXT;

-- word_mastery: composite PK now includes `mode`. SQLite cannot easily ALTER
-- PRIMARY KEY in place, so we rebuild the table.
CREATE TABLE word_mastery_v3 (
  userId              TEXT NOT NULL REFERENCES users(id),
  wordId              INTEGER NOT NULL REFERENCES vocabulary_words(id),
  mode                TEXT NOT NULL DEFAULT 'read_pick_meaning',
  consecutiveCorrect  INTEGER NOT NULL DEFAULT 0,
  totalCorrect        INTEGER NOT NULL DEFAULT 0,
  totalIncorrect      INTEGER NOT NULL DEFAULT 0,
  totalSkipped        INTEGER NOT NULL DEFAULT 0,
  lastSeenAt          TEXT NOT NULL,
  mastered            INTEGER NOT NULL DEFAULT 0 CHECK(mastered IN (0,1)),
  PRIMARY KEY (userId, wordId, mode)
);

INSERT INTO word_mastery_v3
  (userId, wordId, mode, consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered)
SELECT
  userId, wordId, 'read_pick_meaning', consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered
FROM word_mastery;

DROP TABLE word_mastery;
ALTER TABLE word_mastery_v3 RENAME TO word_mastery;

PRAGMA user_version = 3;
```

## Validation rules (added)

Backend zod schemas extended:

- `LessonMode` enum schema in `domain/schemas.ts`.
- `LessonStartRequest`: optional `mode: LessonMode` (default applied in service if missing).
- `AnswerRequest` for `listen_type` mode: at least one of `optionIndex` (0..3) or `typedAnswer` (string, 1..80 chars).
- `AnswerResponse`: optional `typedAnswerEcho?: string`, populated only when mode was `listen_type`.

## Relationships (unchanged otherwise)

```text
User 1───* Lesson 1───* Question
User 1───* WordMastery *───1 VocabularyWord
                ^
                |  composite PK widened with `mode`
```

## Concurrency / FK behavior

SQLite WAL stays enabled; nothing changes. The recreate-and-rename pattern for `word_mastery` runs inside a transaction (the migration runner already wraps each migration). FKs are reasserted by the new CREATE TABLE.

## Open questions for `/speckit-tasks`

- None blocking. Implementation choices (file paths, test names) are decided in `tasks.md`.
