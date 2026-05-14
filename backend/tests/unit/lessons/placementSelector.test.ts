import { describe, it, expect, beforeEach } from 'vitest';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { runMigrations } from '../../../src/store/migrations/runner.js';
import { loadCorpusIfEmpty } from '../../../src/store/corpusLoader.js';
import { WordRepository } from '../../../src/store/wordRepository.js';
import { ALL_LEVELS, QUESTIONS_PER_LEVEL, selectPlacementQuestions } from '../../../src/lessons/placementSelector.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
const CORPUS = join(REPO_ROOT, 'data', 'cefr');

function fixtureRepo(): WordRepository {
  const db = new Database(':memory:');
  runMigrations(db);
  loadCorpusIfEmpty(db, CORPUS);
  return new WordRepository(db);
}

describe('selectPlacementQuestions', () => {
  let repo: WordRepository;
  beforeEach(() => {
    repo = fixtureRepo();
  });

  it('emits QUESTIONS_PER_LEVEL questions per level when corpus has enough material', () => {
    const questions = selectPlacementQuestions(repo, { seed: 1 });
    expect(QUESTIONS_PER_LEVEL).toBeGreaterThanOrEqual(3);
    expect(questions.length).toBe(ALL_LEVELS.length * QUESTIONS_PER_LEVEL);
    for (const lvl of ALL_LEVELS) {
      expect(questions.filter((q) => q.level === lvl).length).toBe(QUESTIONS_PER_LEVEL);
    }
  });

  it('attaches a sentence containing the target word when an example exists', () => {
    const questions = selectPlacementQuestions(repo, { seed: 99 });
    for (const q of questions) {
      if (q.sentence.length > 0) {
        expect(q.sentence.toLowerCase()).toContain(q.word.toLowerCase());
      }
    }
  });

  it('each question has 4 distinct options with exactly 1 correct index', () => {
    const questions = selectPlacementQuestions(repo, { seed: 42 });
    for (const q of questions) {
      expect(q.options).toHaveLength(4);
      const unique = new Set(q.options);
      expect(unique.size).toBe(4);
      expect(q.correctIndex).toBeGreaterThanOrEqual(0);
      expect(q.correctIndex).toBeLessThanOrEqual(3);
    }
  });

  it('does not reuse the same word twice', () => {
    const questions = selectPlacementQuestions(repo, { seed: 7 });
    const wordIds = questions.map((q) => q.wordId);
    expect(new Set(wordIds).size).toBe(wordIds.length);
  });

  it('produces deterministic output for a fixed seed', () => {
    const a = selectPlacementQuestions(repo, { seed: 999 });
    const b = selectPlacementQuestions(repo, { seed: 999 });
    expect(a.map((q) => q.wordId)).toEqual(b.map((q) => q.wordId));
  });
});
