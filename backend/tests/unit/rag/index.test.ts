import { describe, it, expect, beforeEach } from 'vitest';
import { mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { RagIndex } from '../../../src/rag/index.js';

function dir(): string {
  return mkdtempSync(join(tmpdir(), 'gramart-rag-'));
}

function vec(seed: number, dim: number): number[] {
  return Array.from({ length: dim }, (_, i) => Math.sin(seed * 0.1 + i));
}

describe('RagIndex', () => {
  let storage: string;
  beforeEach(() => {
    storage = dir();
  });

  it('rebuilds and answers k-NN', () => {
    const idx = new RagIndex(storage, 1, 8);
    idx.rebuild([
      { ragSourceId: 10, embedding: vec(1, 8) },
      { ragSourceId: 20, embedding: vec(2, 8) },
      { ragSourceId: 30, embedding: vec(3, 8) },
    ]);
    expect(idx.size()).toBe(3);
    const res = idx.knn(vec(1, 8), 2);
    expect(res).toHaveLength(2);
    expect(res[0]?.ragSourceId).toBe(10);
  });

  it('loads an existing on-disk index when the schema matches', () => {
    const a = new RagIndex(storage, 1, 8);
    a.rebuild([{ ragSourceId: 7, embedding: vec(9, 8) }]);
    const b = new RagIndex(storage, 1, 8);
    expect(b.load()).toBe(true);
    expect(b.size()).toBe(1);
    expect(b.knn(vec(9, 8), 1)[0]?.ragSourceId).toBe(7);
  });

  it('refuses to load when schemaVersion mismatches and clears stale files', () => {
    const a = new RagIndex(storage, 1, 8);
    a.rebuild([{ ragSourceId: 1, embedding: vec(0, 8) }]);
    const b = new RagIndex(storage, 2, 8);
    expect(b.load()).toBe(false);
  });

  it('rejects mismatched embedding dimensions', () => {
    const idx = new RagIndex(storage, 1, 8);
    expect(() => idx.rebuild([{ ragSourceId: 1, embedding: vec(0, 7) }])).toThrow(/dim/);
  });
});
