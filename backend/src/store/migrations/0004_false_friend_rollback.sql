-- F008 Item 3 (v1.9.0). Rollback for migration 0004_false_friend.
--
-- SQLite ≥ 3.35 supports ALTER TABLE DROP COLUMN, which is fine for the
-- migration-runner test path (`rollbackTo(db, target)` works one step at
-- a time). Production never auto-rolls-back; this script exists to keep
-- the rollback-runner contract intact for the v1.6.0 migration0003
-- regression test that walks back from the latest version to 2.

ALTER TABLE vocabulary_words DROP COLUMN falseFriendEs;

PRAGMA user_version = 3;
