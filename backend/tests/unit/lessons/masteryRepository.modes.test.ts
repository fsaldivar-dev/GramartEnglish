import { describe, it, expect, beforeEach } from 'vitest';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { MasteryRepository } from '../../../src/store/masteryRepository.js';
import { UserRepository } from '../../../src/store/userRepository.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import type { LessonMode } from '../../../src/domain/schemas.js';

let mastery: MasteryRepository;
let userId: string;
let words: WordRepository;

beforeEach(() => {
  const db = new Database(':memory:');
  runMigrations(db);
  const user = new UserRepository(db).ensureSingleton('A1');
  userId = user.id;
  words = new WordRepository(db);
  words.insertMany([
    { base: 'weather', pos: 'noun', level: 'A1', canonicalDefinition: 'climate', canonicalExamples: [], sourceTag: 'test', addedAt: new Date().toISOString(), spanishOption: 'clima', spanishDefinition: '' },
    { base: 'language', pos: 'noun', level: 'A1', canonicalDefinition: 'speech', canonicalExamples: [], sourceTag: 'test', addedAt: new Date().toISOString(), spanishOption: 'idioma', spanishDefinition: '' },
  ]);
  mastery = new MasteryRepository(db);
});

function wid(base: string): number {
  return words.byBase(base)!.id;
}

describe('MasteryRepository — per-mode keying', () => {
  it('apply records separate rows for the same (userId, wordId) under different modes', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'listen_pick_word', outcome: 'incorrect' });

    const readRow = mastery.byUserAndWord(userId, wid('weather'), 'read_pick_meaning');
    const listenRow = mastery.byUserAndWord(userId, wid('weather'), 'listen_pick_word');

    expect(readRow?.totalCorrect).toBe(1);
    expect(readRow?.totalIncorrect).toBe(0);
    expect(listenRow?.totalCorrect).toBe(0);
    expect(listenRow?.totalIncorrect).toBe(1);
  });

  it('byUserAndWord returns undefined for a mode that has no row even when other modes do', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    expect(mastery.byUserAndWord(userId, wid('weather'), 'listen_type')).toBeUndefined();
  });

  it('mastering a word in one mode does NOT mark it mastered in another mode', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });

    expect(mastery.byUserAndWord(userId, wid('weather'), 'read_pick_meaning')?.mastered).toBe(true);
    expect(mastery.byUserAndWord(userId, wid('weather'), 'listen_pick_word')).toBeUndefined();
    expect(mastery.byUserAndWord(userId, wid('weather'), 'listen_pick_meaning')).toBeUndefined();
    expect(mastery.byUserAndWord(userId, wid('weather'), 'listen_type')).toBeUndefined();
  });

  it('countMastered(mode) is mode-scoped', () => {
    // Master "weather" in read_pick_meaning.
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    // Master "language" in listen_pick_word.
    mastery.apply({ userId, wordId: wid('language'), mode: 'listen_pick_word', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('language'), mode: 'listen_pick_word', outcome: 'correct' });
    // Touch "weather" in listen_type once (not mastered).
    mastery.apply({ userId, wordId: wid('weather'), mode: 'listen_type', outcome: 'correct' });

    expect(mastery.countMastered(userId, 'read_pick_meaning')).toBe(1);
    expect(mastery.countMastered(userId, 'listen_pick_word')).toBe(1);
    expect(mastery.countMastered(userId, 'listen_pick_meaning')).toBe(0);
    expect(mastery.countMastered(userId, 'listen_type')).toBe(0);
    // Unscoped: counts across all modes.
    expect(mastery.countMastered(userId)).toBe(2);
  });

  it('countToReview(mode) is mode-scoped', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'listen_pick_word', outcome: 'incorrect' });
    mastery.apply({ userId, wordId: wid('language'), mode: 'listen_pick_word', outcome: 'skipped' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });

    expect(mastery.countToReview(userId, 'listen_pick_word')).toBe(2);
    expect(mastery.countToReview(userId, 'read_pick_meaning')).toBe(0);
    expect(mastery.countToReview(userId, 'listen_type')).toBe(0);
  });

  it('allForUser(mode) returns only rows for that mode; allForUser() returns every row', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'listen_pick_word', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('language'), mode: 'listen_pick_meaning', outcome: 'incorrect' });

    const readRows = mastery.allForUser(userId, 'read_pick_meaning');
    expect(readRows).toHaveLength(1);
    expect(readRows[0]?.mode).toBe('read_pick_meaning');

    const listenWordRows = mastery.allForUser(userId, 'listen_pick_word');
    expect(listenWordRows).toHaveLength(1);
    expect(listenWordRows[0]?.wordId).toBe(wid('weather'));

    const all = mastery.allForUser(userId);
    expect(all).toHaveLength(3);
    const seenModes = new Set(all.map((r) => r.mode));
    expect(seenModes).toEqual(new Set<LessonMode>(['read_pick_meaning', 'listen_pick_word', 'listen_pick_meaning']));
  });

  it('lastSeenForMode returns null when no row exists, latest ISO timestamp otherwise', async () => {
    expect(mastery.lastSeenForMode(userId, 'listen_type')).toBeNull();

    mastery.apply({ userId, wordId: wid('weather'), mode: 'listen_type', outcome: 'correct' });
    await new Promise((r) => setTimeout(r, 5));
    mastery.apply({ userId, wordId: wid('language'), mode: 'listen_type', outcome: 'correct' });

    const latest = mastery.lastSeenForMode(userId, 'listen_type');
    expect(latest).not.toBeNull();
    const languageRow = mastery.byUserAndWord(userId, wid('language'), 'listen_type');
    expect(latest).toBe(languageRow!.lastSeenAt);

    // Other modes still null.
    expect(mastery.lastSeenForMode(userId, 'listen_pick_word')).toBeNull();
  });

  it('accumulating answers across modes does not leak counters between modes', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'read_pick_meaning', outcome: 'incorrect' });
    mastery.apply({ userId, wordId: wid('weather'), mode: 'listen_pick_word', outcome: 'correct' });

    const read = mastery.byUserAndWord(userId, wid('weather'), 'read_pick_meaning')!;
    const listen = mastery.byUserAndWord(userId, wid('weather'), 'listen_pick_word')!;
    expect(read.totalCorrect).toBe(1);
    expect(read.totalIncorrect).toBe(1);
    expect(read.consecutiveCorrect).toBe(0);
    expect(listen.totalCorrect).toBe(1);
    expect(listen.totalIncorrect).toBe(0);
    expect(listen.consecutiveCorrect).toBe(1);
  });
});
