-- Adds the LessonMode axis to the system.
--
-- Behavior:
--   - users.preferredMode: which mode the user last picked
--   - lessons.mode: which mode a lesson was played in
--   - questions.typedAnswer: for typed-input modes (listen_type, future write_type)
--   - word_mastery PK widens from (userId, wordId) to (userId, wordId, mode);
--     existing rows are preserved with mode = 'read_pick_meaning'.

ALTER TABLE users ADD COLUMN preferredMode TEXT NOT NULL DEFAULT 'read_pick_meaning';
ALTER TABLE lessons ADD COLUMN mode TEXT NOT NULL DEFAULT 'read_pick_meaning';
ALTER TABLE questions ADD COLUMN typedAnswer TEXT;

-- SQLite can't ALTER PRIMARY KEY in place; rebuild and migrate.
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
