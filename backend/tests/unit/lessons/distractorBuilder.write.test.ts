import { describe, it, expect, beforeEach } from 'vitest';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { buildOptions } from '../../../src/lessons/distractorBuilder.js';

let words: WordRepository;

beforeEach(() => {
  const db = new Database(':memory:');
  runMigrations(db);
  words = new WordRepository(db);
  words.insertMany(
    Array.from({ length: 12 }).map((_, i) => ({
      base: `word${i}`,
      pos: 'noun',
      level: 'A1' as const,
      canonicalDefinition: `def ${i}`,
      canonicalExamples: [],
      sourceTag: 'test',
      addedAt: new Date().toISOString(),
      spanishOption: `palabra${i}`,
      spanishDefinition: '',
    })),
  );
});

describe('buildOptions — write modes', () => {
  it('write_pick_word: options are 4 English words including the canonical', () => {
    const target = words.byBase('word0')!;
    const built = buildOptions(target, words, { mode: 'write_pick_word', seed: 7 });
    expect(built.options).toHaveLength(4);
    // All options are English (match the word_N naming pattern in this fixture).
    for (const opt of built.options) {
      expect(opt).toMatch(/^word\d+$/);
    }
    expect(built.options[built.correctIndex]).toBe('word0');
    // No Spanish leakage.
    for (const opt of built.options) {
      expect(opt).not.toMatch(/^palabra/);
    }
  });

  it('write_type_word: options text axis is still English (caller may ignore options)', () => {
    const target = words.byBase('word3')!;
    const built = buildOptions(target, words, { mode: 'write_type_word', seed: 7 });
    expect(built.options[built.correctIndex]).toBe('word3');
    for (const opt of built.options) {
      expect(opt).toMatch(/^word\d+$/);
    }
  });

  it('write_fill_gaps: same English option axis as the other write modes', () => {
    const target = words.byBase('word5')!;
    const built = buildOptions(target, words, { mode: 'write_fill_gaps', seed: 7 });
    expect(built.options[built.correctIndex]).toBe('word5');
  });

  it('distractors are distinct from the target word and from each other', () => {
    const target = words.byBase('word0')!;
    const built = buildOptions(target, words, { mode: 'write_pick_word', seed: 11 });
    expect(new Set(built.options).size).toBe(4); // no duplicates
    const distractors = built.options.filter((_, i) => i !== built.correctIndex);
    expect(distractors).not.toContain('word0');
  });
});
