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
    { base: 'one', pos: 'noun', level: 'A1', canonicalDefinition: 'one', canonicalExamples: [], sourceTag: 'test', addedAt: new Date().toISOString(), spanishOption: 'uno', spanishDefinition: '' },
    { base: 'two', pos: 'noun', level: 'A1', canonicalDefinition: 'two', canonicalExamples: [], sourceTag: 'test', addedAt: new Date().toISOString(), spanishOption: 'dos', spanishDefinition: '' },
  ]);
  mastery = new MasteryRepository(db);
});

function wid(base: string): number {
  return words.byBase(base)!.id;
}

describe('MasteryRepository.apply', () => {
  it('marks mastered after 2 consecutive corrects', () => {
    const first = mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    expect(first.consecutiveCorrect).toBe(1);
    expect(first.mastered).toBe(false);
    const second = mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    expect(second.consecutiveCorrect).toBe(2);
    expect(second.mastered).toBe(true);
  });

  it('resets consecutiveCorrect on a miss and unsets mastered', () => {
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    const miss = mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'incorrect' });
    expect(miss.consecutiveCorrect).toBe(0);
    expect(miss.mastered).toBe(false);
    expect(miss.totalIncorrect).toBe(1);
    expect(miss.totalSkipped).toBe(0);
  });

  it('resets consecutiveCorrect on a skip and tracks totalSkipped separately', () => {
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    const skip = mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'skipped' });
    expect(skip.consecutiveCorrect).toBe(0);
    expect(skip.mastered).toBe(false);
    expect(skip.totalIncorrect).toBe(0); // skip is NOT an incorrect answer
    expect(skip.totalSkipped).toBe(1);
  });

  it('accumulates counters across outcomes', () => {
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'incorrect' });
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'skipped' });
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'correct' });
    const final = mastery.byUserAndWord(userId, wid('two'))!;
    expect(final.totalCorrect).toBe(3);
    expect(final.totalIncorrect).toBe(1);
    expect(final.totalSkipped).toBe(1);
    expect(final.mastered).toBe(true);
  });

  it('countMastered reflects only mastered=true rows', () => {
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' });
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' }); // mastered
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'incorrect' });
    expect(mastery.countMastered(userId)).toBe(1);
  });

  it('countToReview includes skipped, incorrect, and in-progress (single-correct) words', () => {
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'skipped' });
    mastery.apply({ userId, wordId: wid('two'), mode: 'read_pick_meaning', outcome: 'incorrect' });
    expect(mastery.countToReview(userId)).toBe(2);
  });

  it('countToReview includes a word answered correctly once (not yet mastered)', () => {
    mastery.apply({ userId, wordId: wid('one'), mode: 'read_pick_meaning', outcome: 'correct' }); // single correct
    expect(mastery.countToReview(userId)).toBe(1);
  });
});
