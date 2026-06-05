-- F008 Item 3 (v1.9.0). Adds the false-friend belt to vocabulary rows.
--
-- Background: Lucía's L1-transfer research flagged a small set of high-
-- frequency cognate-looking words ("realize", "actually", "library", …)
-- whose Spanish look-alike has a completely different meaning. Surfacing
-- a short Spanish warning ("OJO: no es 'realizar' — do/carry out") at
-- the moment the learner sees the word disambiguates the trap before
-- the wrong mapping rehearses.
--
-- Schema delta is additive and nullable — no schemaVersion bump (still 3).
-- The vast majority of rows leave `falseFriendEs` NULL; only the ~10-12
-- belt entries carry a value. Client tolerates the absence.

ALTER TABLE vocabulary_words ADD COLUMN falseFriendEs TEXT;

-- F008 note: the migration RUNNER uses `PRAGMA user_version` to track
-- applied migrations on disk — bump it to 4 here so the runner doesn't
-- replay the ALTER TABLE on re-start ("duplicate column" SqliteError).
-- The user-facing `schemaVersion` reported via /v1/health stays at 3
-- (driven by `version.json`); that contract is about on-wire breakage,
-- which an additive nullable column doesn't trigger.
PRAGMA user_version = 4;
