import { describe, it, expect, beforeEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { MasteryRepository } from '../../../src/store/masteryRepository.js';
import { UserRepository } from '../../../src/store/userRepository.js';
import { LESSON_SIZE, selectLessonWords } from '../../../src/lessons/wordSelector.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

interface Setup {
  words: WordRepository;
  mastery: MasteryRepository;
  userId: string;
}

function setup(): Setup {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  const user = new UserRepository(db).ensureSingleton('A1');
  return {
    words: new WordRepository(db),
    mastery: new MasteryRepository(db),
    userId: user.id,
  };
}

describe('selectLessonWords (50/30/20 mix)', () => {
  let s: Setup;

  beforeEach(() => {
    s = setup();
  });

  it('returns LESSON_SIZE words from the requested level when corpus suffices', () => {
    const chosen = selectLessonWords(s.userId, 'A1', 'read_pick_meaning', { words: s.words, mastery: s.mastery }, { seed: 1 });
    expect(chosen).toHaveLength(LESSON_SIZE);
    for (const w of chosen) expect(w.level).toBe('A1');
  });

  it('does not return duplicate words within a single lesson', () => {
    const chosen = selectLessonWords(s.userId, 'A1', 'read_pick_meaning', { words: s.words, mastery: s.mastery }, { seed: 7 });
    const ids = chosen.map((w) => w.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('falls back to "new" pool when failed and refresh pools are empty', () => {
    // Brand new user — all words are "new". The 50/30/20 mix should still
    // produce 10 unique words from the level pool.
    const chosen = selectLessonWords(s.userId, 'A1', 'read_pick_meaning', { words: s.words, mastery: s.mastery });
    expect(chosen).toHaveLength(10);
  });

  it('produces deterministic output for a fixed seed', () => {
    const a = selectLessonWords(s.userId, 'A1', 'read_pick_meaning', { words: s.words, mastery: s.mastery }, { seed: 999 });
    const b = selectLessonWords(s.userId, 'A1', 'read_pick_meaning', { words: s.words, mastery: s.mastery }, { seed: 999 });
    expect(a.map((w) => w.id)).toEqual(b.map((w) => w.id));
  });

  it('regression: words answered correctly once must still appear in future lessons', () => {
    // Reproduce the 409 bug: after answering N words correctly once, those
    // words used to fall into limbo (no pool included them). Confirm the
    // selector can still assemble 10 words from a 20-word level pool when
    // 10 of them are "correct-once" in-progress.
    const a1Words = s.words.byLevel('A1');
    expect(a1Words.length).toBeGreaterThanOrEqual(20);
    for (const w of a1Words.slice(0, 10)) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
    }
    const chosen = selectLessonWords(s.userId, 'A1', 'read_pick_meaning', { words: s.words, mastery: s.mastery }, { seed: 11 });
    expect(chosen.length).toBe(10);
  });
});
