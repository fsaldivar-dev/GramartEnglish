import { describe, it, expect, beforeEach } from 'vitest';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { MasteryRepository } from '../../../src/store/masteryRepository.js';
import { UserRepository } from '../../../src/store/userRepository.js';
import { recommendMode } from '../../../src/lessons/modeRecommender.js';
import type { LessonMode } from '../../../src/domain/schemas.js';

interface Setup {
  words: WordRepository;
  mastery: MasteryRepository;
  userId: string;
}

function seedWords(words: WordRepository, n: number): void {
  const rows = [];
  for (let i = 0; i < n; i += 1) {
    rows.push({
      base: `w${i}`,
      pos: 'noun',
      level: 'A1' as const,
      canonicalDefinition: `def ${i}`,
      canonicalExamples: [],
      sourceTag: 'test',
      addedAt: new Date().toISOString(),
      spanishOption: `s${i}`,
      spanishDefinition: '',
    });
  }
  words.insertMany(rows);
}

function setup(): Setup {
  const db = new Database(':memory:');
  runMigrations(db);
  const user = new UserRepository(db).ensureSingleton('A1');
  const words = new WordRepository(db);
  seedWords(words, 10);
  return { words, mastery: new MasteryRepository(db), userId: user.id };
}

describe('recommendMode', () => {
  let s: Setup;
  beforeEach(() => {
    s = setup();
  });

  it('brand-new user (no mastery at all) → listen_pick_word', () => {
    const mode = recommendMode(s.userId, 'A1', { words: s.words, mastery: s.mastery });
    expect(mode).toBe('listen_pick_word' satisfies LessonMode);
  });

  it('returns argmax(pending) across shipped modes', () => {
    // Master ALL A1 words in listen_pick_word (pending=0).
    // Master 5 of 10 in read_pick_meaning (pending=5).
    // Touch nothing in listen_pick_meaning (pending=10) — should win.
    const a1 = s.words.byLevel('A1');
    for (const w of a1) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'listen_pick_word', outcome: 'correct' });
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'listen_pick_word', outcome: 'correct' });
    }
    for (const w of a1.slice(0, 5)) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
    }

    const mode = recommendMode(s.userId, 'A1', { words: s.words, mastery: s.mastery });
    expect(mode).toBe('listen_pick_meaning');
  });

  it('LRU breaks ties: same pending, mode least-recently used wins', async () => {
    const a1 = s.words.byLevel('A1');
    // Touch read_pick_meaning recently (pending stays 10, lastSeen recent).
    s.mastery.apply({ userId: s.userId, wordId: a1[0]!.id, mode: 'read_pick_meaning', outcome: 'incorrect' });
    await new Promise((r) => setTimeout(r, 5));
    // Touch listen_pick_word more recently still (also pending stays 10 — same incorrect).
    s.mastery.apply({ userId: s.userId, wordId: a1[0]!.id, mode: 'listen_pick_word', outcome: 'incorrect' });

    // listen_pick_meaning and listen_type have never been touched (null lastSeen → LRU).
    // Pending is identical (10) for every mode here, so the modes never used
    // should beat the ones that were touched.
    const mode = recommendMode(s.userId, 'A1', { words: s.words, mastery: s.mastery });
    expect(['listen_pick_meaning', 'listen_type']).toContain(mode);
    expect(mode).not.toBe('read_pick_meaning');
    expect(mode).not.toBe('listen_pick_word');
  });

  it('never returns a coming-soon mode (only SHIPPED_MODES are candidates)', () => {
    // We don't have any coming-soon mode in the enum *yet*, but the function
    // contract says it must filter against SHIPPED_MODES. We verify the
    // returned value is always one of the four shipped modes for many states.
    const a1 = s.words.byLevel('A1');
    for (const w of a1) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
    }
    const mode = recommendMode(s.userId, 'A1', { words: s.words, mastery: s.mastery });
    expect(['read_pick_meaning', 'listen_pick_word', 'listen_pick_meaning', 'listen_type']).toContain(mode);
  });

  it('when one mode has fewer pending words it loses to one with more', () => {
    const a1 = s.words.byLevel('A1');
    // Read: master 9 of 10 (pending=1).
    for (const w of a1.slice(0, 9)) {
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
      s.mastery.apply({ userId: s.userId, wordId: w.id, mode: 'read_pick_meaning', outcome: 'correct' });
    }
    // listen_type: master 1 of 10 (pending=9).
    s.mastery.apply({ userId: s.userId, wordId: a1[0]!.id, mode: 'listen_type', outcome: 'correct' });
    s.mastery.apply({ userId: s.userId, wordId: a1[0]!.id, mode: 'listen_type', outcome: 'correct' });

    const mode = recommendMode(s.userId, 'A1', { words: s.words, mastery: s.mastery });
    expect(mode).not.toBe('read_pick_meaning');
  });
});
