import { describe, it, expect, beforeEach } from 'vitest';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { MasteryRepository } from '../../../src/store/masteryRepository.js';
import { UserRepository } from '../../../src/store/userRepository.js';
import { WordRepository } from '../../../src/store/wordRepository.js';

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
  ]);
  mastery = new MasteryRepository(db);
});

function wid(base: string): number {
  return words.byBase(base)!.id;
}

describe('MasteryRepository.apply — hintUsed (FR-009)', () => {
  it('correct answer WITHOUT hint increments consecutiveCorrect as before', () => {
    const r1 = mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct' });
    expect(r1.consecutiveCorrect).toBe(1);
    const r2 = mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct' });
    expect(r2.consecutiveCorrect).toBe(2);
    expect(r2.mastered).toBe(true);
  });

  it('correct answer WITH hint keeps consecutiveCorrect at 0 — no mastery credit', () => {
    const r1 = mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct', hintUsed: true });
    expect(r1.consecutiveCorrect).toBe(0);
    expect(r1.totalCorrect).toBe(1);   // we still credit the totalCorrect counter
    expect(r1.mastered).toBe(false);
  });

  it('hint use mid-streak resets the streak even on a correct answer', () => {
    mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct' }); // streak=1
    const r2 = mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct', hintUsed: true });
    expect(r2.consecutiveCorrect).toBe(0);  // streak broken by hint
    expect(r2.mastered).toBe(false);
    // Recovering: two more clean corrects rebuild the streak.
    mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct' });
    const r4 = mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'correct' });
    expect(r4.consecutiveCorrect).toBe(2);
    expect(r4.mastered).toBe(true);
  });

  it('hintUsed on an incorrect answer behaves like a normal incorrect (streak already zero)', () => {
    const r = mastery.apply({ userId, wordId: wid('weather'), mode: 'write_type_word', outcome: 'incorrect', hintUsed: true });
    expect(r.consecutiveCorrect).toBe(0);
    expect(r.totalIncorrect).toBe(1);
    expect(r.mastered).toBe(false);
  });
});
