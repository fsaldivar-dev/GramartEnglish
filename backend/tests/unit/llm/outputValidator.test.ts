import { describe, it, expect } from 'vitest';
import { containsWord, validateDefinition, validateExamples } from '../../../src/llm/outputValidator.js';

describe('containsWord', () => {
  it('matches the base form', () => {
    expect(containsWord('She likes to run every morning.', 'run')).toBe(true);
  });

  it('matches simple inflections', () => {
    expect(containsWord('He runs fast.', 'run')).toBe(true);
    expect(containsWord('They are running.', 'run')).toBe(true);
    expect(containsWord('She ran yesterday.', 'run')).toBe(false); // irregular — caught later by output text check
    expect(containsWord('Books are useful.', 'book')).toBe(true);
  });

  it('handles -y → -ies / -ied morphology', () => {
    expect(containsWord('She tries hard.', 'try')).toBe(true);
    expect(containsWord('I tried before.', 'try')).toBe(true);
  });

  it('does not match unrelated text', () => {
    expect(containsWord('The cat is happy.', 'run')).toBe(false);
  });
});

describe('validateExamples', () => {
  it('keeps lines that contain the word and drops the rest', () => {
    const raw = `She runs every day.\nThe sky is blue.\nRunning is fun.\n`;
    const res = validateExamples(raw, 'run');
    expect(res.ok).toBe(true);
    expect(res.examples).toHaveLength(2);
    expect(res.examples[0]).toMatch(/run/i);
  });

  it('strips leading numbering and quotes', () => {
    const raw = `1. "She runs to the park."\n2. Running is fun.\n`;
    const res = validateExamples(raw, 'run');
    expect(res.ok).toBe(true);
    expect(res.examples[0]).toBe('She runs to the park.');
  });

  it('fails when no line contains the word', () => {
    const raw = 'The cat sleeps.\nThe sky is blue.\n';
    const res = validateExamples(raw, 'run');
    expect(res.ok).toBe(false);
  });

  it('caps at 3 examples', () => {
    const raw = `She runs.\nHe runs.\nWe run.\nThey run.\nI run.`;
    const res = validateExamples(raw, 'run');
    expect(res.examples).toHaveLength(3);
  });
});

describe('validateDefinition', () => {
  it('returns the first line trimmed', () => {
    const res = validateDefinition('"A small dog."\nIgnored second line.', 'puppy');
    expect(res.ok).toBe(true);
    expect(res.definition).toBe('A small dog.');
  });

  it('caps at 250 chars', () => {
    const long = 'a'.repeat(400);
    const res = validateDefinition(long, 'x');
    expect(res.definition.length).toBeLessThanOrEqual(250);
  });

  it('rejects empty input', () => {
    expect(validateDefinition('', 'x').ok).toBe(false);
    expect(validateDefinition('   \n\n', 'x').ok).toBe(false);
  });
});
