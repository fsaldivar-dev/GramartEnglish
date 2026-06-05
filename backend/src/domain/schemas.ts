import { z } from 'zod';

export const CefrLevel = z.enum(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
export type CefrLevel = z.infer<typeof CefrLevel>;

export const LessonMode = z.enum([
  'read_pick_meaning',
  'listen_pick_word',
  'listen_pick_meaning',
  'listen_type',
  'write_pick_word',
  'write_type_word',
  'write_fill_gaps',
  'conjugate_pick_form',
]);
export type LessonMode = z.infer<typeof LessonMode>;

/** Modes shipped in v1.6 (F004 US1 adds `conjugate_pick_form`). All eight
 *  modes are live and eligible for `modeRecommender`'s argmax(pendingWords). */
export const SHIPPED_MODES: readonly LessonMode[] = [
  'read_pick_meaning',
  'listen_pick_word',
  'listen_pick_meaning',
  'listen_type',
  'write_pick_word',
  'write_type_word',
  'write_fill_gaps',
  'conjugate_pick_form',
];

/** Conjugation modes — Spanish prompt "Pasado simple de <es>" → pick English form.
 *  Mastery axis is the existing (userId, wordId, mode); `wordId` resolves to the
 *  verb's `vocabulary_words` row by `base`. */
export const CONJUGATION_MODES: readonly LessonMode[] = ['conjugate_pick_form'];

/** Listening modes — auto-play TTS on appear, reveal re-speaks (FR-006, FR-012). */
export const LISTENING_MODES: readonly LessonMode[] = [
  'listen_pick_word',
  'listen_pick_meaning',
  'listen_type',
];

/** Writing modes — Spanish prompt on screen, English answer. Options or typed. */
export const WRITING_MODES: readonly LessonMode[] = [
  'write_pick_word',
  'write_type_word',
  'write_fill_gaps',
];

export function isListeningMode(mode: LessonMode): boolean {
  return LISTENING_MODES.includes(mode);
}

export function isWritingMode(mode: LessonMode): boolean {
  return WRITING_MODES.includes(mode);
}

export function isTypedMode(mode: LessonMode): boolean {
  return mode === 'listen_type' || mode === 'write_type_word' || mode === 'write_fill_gaps';
}

export function isConjugationMode(mode: LessonMode): boolean {
  return CONJUGATION_MODES.includes(mode);
}

export const Uuid = z.string().uuid();

export const HealthResponse = z.object({
  status: z.literal('ok'),
  version: z.string(),
  schemaVersion: z.number().int(),
  ollamaAvailable: z.boolean(),
});

export const LevelInfo = z.object({
  code: CefrLevel,
  label: z.string(),
});

export const PlacementQuestion = z.object({
  id: Uuid,
  word: z.string(),
  options: z.array(z.string()).length(4),
  level: CefrLevel,
});

export const PlacementStartResponse = z.object({
  placementId: Uuid,
  questions: z.array(PlacementQuestion).min(6),
});

export const PlacementSubmitRequest = z.object({
  placementId: Uuid,
  answers: z
    .array(
      z.object({
        questionId: Uuid,
        optionIndex: z.number().int().min(0).max(3),
      }),
    )
    .min(1),
});

export const PlacementResultResponse = z.object({
  estimatedLevel: CefrLevel,
  perLevelScores: z.record(
    CefrLevel,
    z.object({
      attempted: z.number().int().nonnegative(),
      correct: z.number().int().nonnegative(),
    }),
  ),
});

export const LessonStartRequest = z.object({ level: CefrLevel });

export const LessonQuestion = z.object({
  id: Uuid,
  word: z.string(),
  options: z.array(z.string()).length(4),
  position: z.number().int().nonnegative(),
  /** v1.6+. For `conjugate_pick_form`: English base form of the verb being
   *  conjugated (e.g. "go" when the answer is "went"). Omitted for other modes. */
  verbBase: z.string().optional(),
  /** v1.6+. For `conjugate_pick_form`: target tense. v1.6.0 ships only
   *  "simple_past"; the field is reserved for additional tenses in later
   *  releases. Omitted for other modes. */
  targetTense: z.enum(['simple_past']).optional(),
});

export const LessonStartResponse = z.object({
  lessonId: Uuid,
  questions: z.array(LessonQuestion).length(10),
});

export const AnswerRequest = z.object({
  questionId: Uuid,
  optionIndex: z.number().int().min(0).max(3),
  answerMs: z.number().int().nonnegative(),
});

export const AnswerResponse = z.object({
  correct: z.boolean(),
  correctIndex: z.number().int().min(0).max(3),
  canonicalDefinition: z.string(),
});

export const LessonSummaryResponse = z.object({
  lessonId: Uuid,
  score: z.number().int().min(0).max(10),
  total: z.number().int(),
  missedWords: z.array(z.object({ word: z.string(), canonicalDefinition: z.string() })),
});

export const ExamplesResponse = z.object({
  examples: z.array(z.string()).min(1).max(3),
  sourceIds: z.array(z.number().int()).default([]),
  generatedBy: z.enum(['llm', 'fallback_canonical']),
  fallback: z.boolean(),
});

export const ContextualDefinitionResponse = z.object({
  definition: z.string(),
  sourceIds: z.array(z.number().int()).default([]),
  generatedBy: z.enum(['llm', 'fallback_canonical']),
  fallback: z.boolean(),
});

export const ErrorResponse = z.object({
  code: z.string(),
  message: z.string(),
  correlationId: Uuid.optional(),
});
