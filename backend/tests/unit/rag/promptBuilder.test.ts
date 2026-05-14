import { describe, it, expect } from 'vitest';
import { buildExamplesPrompt, buildDefinitionPrompt, buildPromptFor } from '../../../src/rag/promptBuilder.js';
import type { RetrievalContext } from '../../../src/rag/retriever.js';

const sampleCtx: RetrievalContext = {
  word: {
    id: 1,
    base: 'ephemeral',
    pos: 'adjective',
    level: 'B2',
    canonicalDefinition: 'Lasting for a very short time.',
    canonicalExamples: ['The beauty of cherry blossoms is ephemeral.'],
    sourceTag: 'author',
    addedAt: new Date().toISOString(),
  },
  level: 'B2',
  sources: [
    {
      id: 10,
      kind: 'example',
      wordId: 1,
      level: 'B2',
      content: 'The fame was ephemeral, gone in days.',
      embedding: null,
      embeddingModel: 'test',
      schemaVersion: 1,
      addedAt: new Date().toISOString(),
    },
  ],
};

describe('promptBuilder', () => {
  it('builds an examples prompt with system rules + word entry + sources', () => {
    const p = buildExamplesPrompt(sampleCtx);
    expect(p.system).toMatch(/non-negotiable/i);
    expect(p.user).toContain('WORD: ephemeral');
    expect(p.user).toContain('LEVEL: B2');
    expect(p.user).toContain('CANONICAL DEFINITION: Lasting for a very short time');
    expect(p.user).toContain('SOURCES:');
    expect(p.user).toContain('The fame was ephemeral');
    expect(p.user).toMatch(/2 to 3 example sentences/);
    expect(p.promptHash).toHaveLength(16);
  });

  it('forbids invention in system prompt', () => {
    const p = buildExamplesPrompt(sampleCtx);
    expect(p.system).toMatch(/Do not invent/i);
  });

  it('builds a definition prompt asking for a single sentence ≤25 words', () => {
    const p = buildDefinitionPrompt(sampleCtx);
    expect(p.user).toMatch(/ONE sentence/);
    expect(p.user).toMatch(/max 25 words/);
  });

  it('buildPromptFor dispatches by kind', () => {
    expect(buildPromptFor('examples', sampleCtx).user).toMatch(/example sentences/);
    expect(buildPromptFor('contextual_definition', sampleCtx).user).toMatch(/ONE sentence/);
  });
});
