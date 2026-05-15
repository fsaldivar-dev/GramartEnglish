import { createHash } from 'node:crypto';
import type { RetrievalContext } from './retriever.js';
import type { AiKind } from '../store/aiGenerationRepository.js';

const SYSTEM_PROMPT = `You are GramartEnglish, an English vocabulary tutor.
Rules — non-negotiable:
1. Use the WORD ENTRY and SOURCES as the only sources of truth. Do not invent meanings, facts, or examples beyond them.
2. If asked for example sentences, write 2 to 3 sentences. Each MUST contain the target word or a valid inflection (plural, tense, comparative).
3. If asked for a contextual definition, write a single clear sentence appropriate for the target CEFR level. No more than 25 words.
4. Output plain text only. No JSON, no bullet markers, no quotes, no markdown headings.
5. Do not include explanations about your reasoning.`;

export interface PromptParts {
  system: string;
  user: string;
  promptHash: string;
}

export function buildExamplesPrompt(ctx: RetrievalContext): PromptParts {
  const lines: string[] = [];
  lines.push(`WORD: ${ctx.word.base}`);
  lines.push(`PART OF SPEECH: ${ctx.word.pos}`);
  lines.push(`LEVEL: ${ctx.word.level}`);
  lines.push(`CANONICAL DEFINITION: ${ctx.word.canonicalDefinition}`);
  if (ctx.word.canonicalExamples.length > 0) {
    lines.push('CANONICAL EXAMPLES:');
    for (const ex of ctx.word.canonicalExamples) lines.push(`- ${ex}`);
  }
  if (ctx.sources.length > 0) {
    lines.push('SOURCES:');
    for (const src of ctx.sources) lines.push(`- (${src.kind}) ${src.content}`);
  }
  lines.push('');
  lines.push(`TASK: Write 2 to 3 example sentences using "${ctx.word.base}" that an English learner at the ${ctx.level} CEFR level can understand. One sentence per line. No numbering or bullets.`);
  const user = lines.join('\n');
  return { system: SYSTEM_PROMPT, user, promptHash: hash(SYSTEM_PROMPT + '\n' + user) };
}

export function buildDefinitionPrompt(ctx: RetrievalContext): PromptParts {
  const lines: string[] = [];
  lines.push(`WORD: ${ctx.word.base}`);
  lines.push(`PART OF SPEECH: ${ctx.word.pos}`);
  lines.push(`LEVEL OF THE WORD: ${ctx.word.level}`);
  lines.push(`READER LEVEL: ${ctx.level}`);
  lines.push(`CANONICAL DEFINITION: ${ctx.word.canonicalDefinition}`);
  if (ctx.sources.length > 0) {
    lines.push('SOURCES:');
    for (const src of ctx.sources) lines.push(`- (${src.kind}) ${src.content}`);
  }
  lines.push('');
  lines.push(`TASK: Write ONE sentence (max 25 words) explaining "${ctx.word.base}" in a way a ${ctx.level} learner can understand.`);
  const user = lines.join('\n');
  return { system: SYSTEM_PROMPT, user, promptHash: hash(SYSTEM_PROMPT + '\n' + user) };
}

export function buildPromptFor(kind: AiKind, ctx: RetrievalContext): PromptParts {
  return kind === 'examples' ? buildExamplesPrompt(ctx) : buildDefinitionPrompt(ctx);
}

function hash(input: string): string {
  return createHash('sha256').update(input).digest('hex').slice(0, 16);
}
