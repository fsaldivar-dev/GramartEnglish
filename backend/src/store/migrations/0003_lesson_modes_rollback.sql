-- Rollback for 0003_lesson_modes.sql.
-- Runs only on explicit `npm run db:rollback 3` (the migration runner does NOT
-- auto-rollback). Constitution V requires a documented rollback path.
--
-- Behavior:
--   - All rows in word_mastery whose `mode != 'read_pick_meaning'` are DROPPED
--     (the user loses listening/typing mastery). This is irreversible per row.
--   - The `mode`, `preferredMode`, and `typedAnswer` columns are dropped.
--   - PRAGMA user_version is reset to 2.
--
-- Operators MUST take a copy of the SQLite file before invoking this script.

BEGIN;

-- Drop non-read mastery rows; keep read mastery so the user doesn't lose all progress.
DELETE FROM word_mastery WHERE mode != 'read_pick_meaning';

-- Rebuild word_mastery with the v2 PK (userId, wordId), since SQLite cannot easily
-- drop a column that participates in a PK.
CREATE TABLE word_mastery_v2 (
  userId              TEXT NOT NULL REFERENCES users(id),
  wordId              INTEGER NOT NULL REFERENCES vocabulary_words(id),
  consecutiveCorrect  INTEGER NOT NULL DEFAULT 0,
  totalCorrect        INTEGER NOT NULL DEFAULT 0,
  totalIncorrect      INTEGER NOT NULL DEFAULT 0,
  totalSkipped        INTEGER NOT NULL DEFAULT 0,
  lastSeenAt          TEXT NOT NULL,
  mastered            INTEGER NOT NULL DEFAULT 0 CHECK(mastered IN (0,1)),
  PRIMARY KEY (userId, wordId)
);

INSERT INTO word_mastery_v2
  (userId, wordId, consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered)
SELECT
  userId, wordId, consecutiveCorrect, totalCorrect, totalIncorrect, totalSkipped, lastSeenAt, mastered
FROM word_mastery;

DROP TABLE word_mastery;
ALTER TABLE word_mastery_v2 RENAME TO word_mastery;

-- Drop the lesson `mode` column. SQLite ≥ 3.35 supports DROP COLUMN directly.
ALTER TABLE lessons DROP COLUMN mode;

-- Drop the typedAnswer column on questions.
ALTER TABLE questions DROP COLUMN typedAnswer;

-- Drop the preferredMode column on users.
ALTER TABLE users DROP COLUMN preferredMode;

PRAGMA user_version = 2;

COMMIT;
