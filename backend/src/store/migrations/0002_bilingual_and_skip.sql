-- Adds bilingual support and the "I don't know" outcome.
--
-- vocabulary_words.spanishOption  — short Spanish text shown as a multiple-choice option
-- vocabulary_words.spanishDefinition — optional, longer Spanish gloss
-- questions.skipped — when the user pressed "I don't know"
-- word_mastery.totalSkipped — separate counter, kept distinct from totalIncorrect

ALTER TABLE vocabulary_words ADD COLUMN spanishOption TEXT NOT NULL DEFAULT '';
ALTER TABLE vocabulary_words ADD COLUMN spanishDefinition TEXT NOT NULL DEFAULT '';

ALTER TABLE questions ADD COLUMN skipped INTEGER NOT NULL DEFAULT 0 CHECK(skipped IN (0,1));

ALTER TABLE word_mastery ADD COLUMN totalSkipped INTEGER NOT NULL DEFAULT 0;

PRAGMA user_version = 2;
