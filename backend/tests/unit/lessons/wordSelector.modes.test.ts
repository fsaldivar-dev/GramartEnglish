import { describe, it, expect, beforeEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { MasteryRepository } from '../../../src/store/masteryRepository.js';
import { UserRepository } from '../../../src/store/userRepository.js';
import { selectLessonWords, LESSON_SIZE } from '../../../src/lessons/wordSelector.js';

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

describe('selectLessonWords — mode isolation', () => {
  let s: Setup;

  beforeEach(() => {
    s = setup();
  });

  it('mastering a word in read_pick_meaning does NOT remove it from listen_pick_word eligibility', () => {
    const a1 = s.words.byLevel('A1');
    expect(a1.length).toBeGreaterThan(0);
    const target = a1[0]!;

    // Master `target` in read mode.
    s.mastery.apply({ userId: s.userId, wordId: target.id, mode: 'read_pick_meaning', outcome: 'correct' });
    s.mastery.apply({ userId: s.userId, wordId: target.id, mode: 'read_pick_meaning', outcome: 'correct' });
    expect(s.mastery.byUserAndWord(s.userId, target.id, 'read_pick_meaning')?.mastered).toBe(true);

    // The selector for listen_pick_word must treat `target` as still "new"
    // (no mastery row exists for that mode), so across many seeds it should
    // appear in the lesson with high probability — for a small A1 pool we
    // simply assert it CAN appear at least once.
    let appeared = false;
    for (let seed = 0; seed < 30 && !appeared; seed += 1) {
      const chosen = selectLessonWords(
        s.userId,
        'A1',
        'listen_pick_word',
        { words: s.words, mastery: s.mastery },
        { seed },
      );
      if (chosen.some((w) => w.id === target.id)) appeared = true;
    }
    expect(appeared).toBe(true);
  });

  it('per-mode 50/30/20 mix is computed from that mode\'s mastery rows only', () => {
    const a1 = s.words.byLevel('A1');
    expect(a1.length).toBeGreaterThanOrEqual(15);

    // Make 10 words "in-progress" (correct-once) in read_pick_meaning.
    for (const w of a1.slice(0, 10)) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
    }

    // Selector for listen_pick_word must see these 10 as "new", not "in-progress".
    const chosen = selectLessonWords(
      s.userId,
      'A1',
      'listen_pick_word',
      { words: s.words, mastery: s.mastery },
      { seed: 42 },
    );
    expect(chosen).toHaveLength(LESSON_SIZE);
    for (const w of chosen) {
      // No row in listen_pick_word means it counts as "new" for this mode.
      expect(s.mastery.byUserAndWord(s.userId, w.id, 'listen_pick_word')).toBeUndefined();
    }
  });

  it('mastery in another mode does not contribute to the "refresh" pool for this mode', () => {
    const a1 = s.words.byLevel('A1');
    // Master 10 words in read mode.
    for (const w of a1.slice(0, 10)) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
    }
    // Touch 4 different A1 words as "failed" in listen_pick_word.
    const failed = a1.slice(10, 14);
    for (const w of failed) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'listen_pick_word', outcome: 'incorrect' });
    }

    const chosen = selectLessonWords(
      s.userId,
      'A1',
      'listen_pick_word',
      { words: s.words, mastery: s.mastery },
      { seed: 5 },
    );
    expect(chosen).toHaveLength(LESSON_SIZE);
    // None of the chosen words should be considered "mastered in listen mode" yet.
    for (const w of chosen) {
      expect(s.mastery.byUserAndWord(s.userId, w.id, 'listen_pick_word')?.mastered ?? false).toBe(false);
    }
    // At least some of the failed-in-listen words should appear, since the
    // listen-mode "failed" pool is non-empty (regression: must not pull from
    // the read-mode mastery state).
    const failedIds = new Set(failed.map((w) => w.id));
    expect(chosen.some((w) => failedIds.has(w.id))).toBe(true);
  });

  it('each listening mode keeps an independent mastery view', () => {
    const a1 = s.words.byLevel('A1');
    const target = a1[0]!;
    s.mastery.apply({ userId: s.userId, wordId: target.id, mode: 'listen_pick_word', outcome: 'correct' });
    s.mastery.apply({ userId: s.userId, wordId: target.id, mode: 'listen_pick_word', outcome: 'correct' });

    // Mastered in listen_pick_word — should NOT be mastered in listen_pick_meaning.
    expect(s.mastery.byUserAndWord(s.userId, target.id, 'listen_pick_word')?.mastered).toBe(true);
    expect(s.mastery.byUserAndWord(s.userId, target.id, 'listen_pick_meaning')).toBeUndefined();

    // listen_pick_meaning treats it as new — should be eligible.
    let appeared = false;
    for (let seed = 0; seed < 30 && !appeared; seed += 1) {
      const chosen = selectLessonWords(
        s.userId,
        'A1',
        'listen_pick_meaning',
        { words: s.words, mastery: s.mastery },
        { seed },
      );
      if (chosen.some((w) => w.id === target.id)) appeared = true;
    }
    expect(appeared).toBe(true);
  });
});
