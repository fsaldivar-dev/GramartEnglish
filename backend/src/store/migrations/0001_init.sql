-- Initial schema for GramartEnglish backend.
-- Sets PRAGMA user_version = 1 at the end.

CREATE TABLE IF NOT EXISTS users (
  id                  TEXT PRIMARY KEY,
  currentLevel        TEXT NOT NULL CHECK(currentLevel IN ('A1','A2','B1','B2','C1','C2')),
  createdAt           TEXT NOT NULL,
  accessibilityPrefs  TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS vocabulary_words (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  base                TEXT NOT NULL UNIQUE,
  pos                 TEXT NOT NULL,
  level               TEXT NOT NULL CHECK(level IN ('A1','A2','B1','B2','C1','C2')),
  canonicalDefinition TEXT NOT NULL,
  canonicalExamples   TEXT NOT NULL DEFAULT '[]',
  sourceTag           TEXT NOT NULL,
  addedAt             TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_vocabulary_words_level ON vocabulary_words(level);

CREATE TABLE IF NOT EXISTS lessons (
  id              TEXT PRIMARY KEY,
  userId          TEXT NOT NULL REFERENCES users(id),
  level           TEXT NOT NULL CHECK(level IN ('A1','A2','B1','B2','C1','C2')),
  state           TEXT NOT NULL CHECK(state IN ('in_progress','completed','abandoned')),
  startedAt       TEXT NOT NULL,
  completedAt     TEXT,
  score           INTEGER,
  correlationId   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_lessons_user ON lessons(userId);

CREATE TABLE IF NOT EXISTS questions (
  id              TEXT PRIMARY KEY,
  lessonId        TEXT NOT NULL REFERENCES lessons(id),
  position        INTEGER NOT NULL,
  wordId          INTEGER NOT NULL REFERENCES vocabulary_words(id),
  options         TEXT NOT NULL,
  correctIndex    INTEGER NOT NULL CHECK(correctIndex BETWEEN 0 AND 3),
  selectedIndex   INTEGER CHECK(selectedIndex BETWEEN 0 AND 3),
  correct         INTEGER CHECK(correct IN (0,1)),
  answeredAt      TEXT,
  answerMs        INTEGER
);
CREATE INDEX IF NOT EXISTS idx_questions_lesson ON questions(lessonId);
CREATE UNIQUE INDEX IF NOT EXISTS uq_questions_lesson_word ON questions(lessonId, wordId);

CREATE TABLE IF NOT EXISTS word_mastery (
  userId              TEXT NOT NULL REFERENCES users(id),
  wordId              INTEGER NOT NULL REFERENCES vocabulary_words(id),
  consecutiveCorrect  INTEGER NOT NULL DEFAULT 0,
  totalCorrect        INTEGER NOT NULL DEFAULT 0,
  totalIncorrect      INTEGER NOT NULL DEFAULT 0,
  lastSeenAt          TEXT NOT NULL,
  mastered            INTEGER NOT NULL DEFAULT 0 CHECK(mastered IN (0,1)),
  PRIMARY KEY (userId, wordId)
);

CREATE TABLE IF NOT EXISTS placement_results (
  id              TEXT PRIMARY KEY,
  userId          TEXT NOT NULL REFERENCES users(id),
  takenAt         TEXT NOT NULL,
  perLevelScores  TEXT NOT NULL,
  estimatedLevel  TEXT NOT NULL CHECK(estimatedLevel IN ('A1','A2','B1','B2','C1','C2')),
  userOverride    TEXT CHECK(userOverride IN ('A1','A2','B1','B2','C1','C2'))
);

CREATE TABLE IF NOT EXISTS rag_sources (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  kind            TEXT NOT NULL CHECK(kind IN ('definition','example','usage_note')),
  wordId          INTEGER REFERENCES vocabulary_words(id),
  level           TEXT CHECK(level IN ('A1','A2','B1','B2','C1','C2')),
  content         TEXT NOT NULL,
  embedding       BLOB,
  embeddingModel  TEXT NOT NULL,
  schemaVersion   INTEGER NOT NULL,
  addedAt         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rag_schema ON rag_sources(schemaVersion);

CREATE TABLE IF NOT EXISTS ai_generations (
  id              TEXT PRIMARY KEY,
  correlationId   TEXT NOT NULL,
  wordId          INTEGER REFERENCES vocabulary_words(id),
  kind            TEXT NOT NULL CHECK(kind IN ('examples','contextual_definition')),
  targetLevel     TEXT NOT NULL CHECK(targetLevel IN ('A1','A2','B1','B2','C1','C2')),
  model           TEXT NOT NULL,
  promptHash      TEXT NOT NULL,
  ragSourceIds    TEXT NOT NULL,
  output          TEXT NOT NULL,
  firstTokenMs    INTEGER NOT NULL,
  totalMs         INTEGER NOT NULL,
  createdAt       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ai_corr ON ai_generations(correlationId);

PRAGMA user_version = 1;
