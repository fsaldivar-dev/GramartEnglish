import type { CefrLevel, LessonMode } from '../domain/schemas.js';
import type { LessonRepository, LessonRow } from '../store/lessonRepository.js';
import type { QuestionRepository, QuestionRow } from '../store/questionRepository.js';
import type { WordRepository } from '../store/wordRepository.js';
import type { MasteryRepository } from '../store/masteryRepository.js';
import { LESSON_SIZE, selectLessonWords } from './wordSelector.js';
import { buildOptions } from './distractorBuilder.js';
import { levenshteinAtMost } from './levenshtein.js';

const TYPED_TOLERANCE = 1;

export interface LessonServiceDeps {
  lessons: LessonRepository;
  questions: QuestionRepository;
  words: WordRepository;
  mastery: MasteryRepository;
}

export interface ClientLessonQuestion {
  id: string;
  word: string;
  options: string[];
  position: number;
}

export interface StartLessonResult {
  lesson: LessonRow;
  questions: ClientLessonQuestion[];
}

export interface AnswerResult {
  outcome: 'correct' | 'incorrect' | 'skipped';
  correctIndex: number;
  correctOption: string;
  canonicalDefinition: string;
  typedAnswerEcho?: string;
}

export interface LessonSummary {
  lessonId: string;
  score: number;
  skipped: number;
  wrong: number;
  total: number;
  missedWords: { word: string; canonicalDefinition: string; outcome: 'incorrect' | 'skipped' }[];
}

export type ResumeLessonResult =
  | {
      kind: 'in_progress';
      lesson: LessonRow;
      answeredCount: number;
      totalCount: number;
      remaining: ClientLessonQuestion[];
    }
  | { kind: 'completed'; lesson: LessonRow; summary: LessonSummary };

export class LessonService {
  constructor(private deps: LessonServiceDeps) {}

  startLesson(input: { userId: string; level: CefrLevel; correlationId: string; mode?: LessonMode; seed?: number }): StartLessonResult {
    const mode: LessonMode = input.mode ?? 'read_pick_meaning';
    const words = selectLessonWords(input.userId, input.level, mode, this.deps, input.seed !== undefined ? { seed: input.seed } : {});
    if (words.length < LESSON_SIZE) {
      throw new Error(
        `Not enough corpus to start a ${LESSON_SIZE}-question lesson at ${input.level} (have ${words.length})`,
      );
    }
    const lesson = this.deps.lessons.create({
      userId: input.userId,
      level: input.level,
      mode,
      correlationId: input.correlationId,
    });
    const newQuestions = words.map((w, position) => {
      const built = buildOptions(w, this.deps.words, {
        mode,
        ...(input.seed !== undefined ? { seed: input.seed + position } : {}),
      });
      return {
        lessonId: lesson.id,
        position,
        wordId: w.id,
        options: built.options,
        correctIndex: built.correctIndex,
      };
    });
    const rows = this.deps.questions.createMany(newQuestions);
    const clientQuestions: ClientLessonQuestion[] = rows.map((r) => {
      const word = words[r.position]!;
      return { id: r.id, word: word.base, options: r.options, position: r.position };
    });
    return { lesson, questions: clientQuestions };
  }

  submitAnswer(input: {
    lessonId: string;
    questionId: string;
    optionIndex?: number;
    typedAnswer?: string;
    answerMs: number;
    userId: string;
  }): AnswerResult {
    const question = this.deps.questions.byId(input.questionId);
    if (!question) throw new Error('question not found');
    if (question.lessonId !== input.lessonId) throw new Error('question/lesson mismatch');

    const lesson = this.deps.lessons.byId(input.lessonId);
    const mode: LessonMode = (lesson?.mode as LessonMode | undefined) ?? 'read_pick_meaning';
    const word = this.deps.words.byId(question.wordId);

    if (mode === 'listen_type') {
      if (input.typedAnswer === undefined) throw new Error('typedAnswer required for listen_type');
      const canonical = (word?.base ?? '').trim().toLowerCase();
      const typedTrimmed = input.typedAnswer.trim();
      const typedNorm = typedTrimmed.toLowerCase();
      const distance = levenshteinAtMost(typedNorm, canonical, TYPED_TOLERANCE);
      const correct = distance <= TYPED_TOLERANCE;
      this.deps.questions.recordAnswer({
        questionId: input.questionId,
        selectedIndex: null,
        correct,
        answerMs: input.answerMs,
        typedAnswer: typedTrimmed,
      });
      this.deps.mastery.apply({
        userId: input.userId,
        wordId: question.wordId,
        mode,
        outcome: correct ? 'correct' : 'incorrect',
      });
      return {
        outcome: correct ? 'correct' : 'incorrect',
        correctIndex: 0,
        correctOption: word?.base ?? '',
        canonicalDefinition: word?.canonicalDefinition ?? '',
        typedAnswerEcho: typedTrimmed,
      };
    }

    if (input.optionIndex === undefined) throw new Error('optionIndex required');
    const correct = input.optionIndex === question.correctIndex;
    this.deps.questions.recordAnswer({
      questionId: input.questionId,
      selectedIndex: input.optionIndex,
      correct,
      answerMs: input.answerMs,
    });
    this.deps.mastery.apply({
      userId: input.userId,
      wordId: question.wordId,
      mode,
      outcome: correct ? 'correct' : 'incorrect',
    });

    return {
      outcome: correct ? 'correct' : 'incorrect',
      correctIndex: question.correctIndex,
      correctOption: question.options[question.correctIndex] ?? '',
      canonicalDefinition: word?.canonicalDefinition ?? '',
    };
  }

  submitSkip(input: {
    lessonId: string;
    questionId: string;
    answerMs: number;
    userId: string;
  }): AnswerResult {
    const question = this.deps.questions.byId(input.questionId);
    if (!question) throw new Error('question not found');
    if (question.lessonId !== input.lessonId) throw new Error('question/lesson mismatch');

    this.deps.questions.recordSkip({ questionId: input.questionId, answerMs: input.answerMs });
    const skipLesson = this.deps.lessons.byId(input.lessonId);
    const skipMode: LessonMode = (skipLesson?.mode as LessonMode | undefined) ?? 'read_pick_meaning';
    this.deps.mastery.apply({ userId: input.userId, wordId: question.wordId, mode: skipMode, outcome: 'skipped' });

    const word = this.deps.words.byId(question.wordId);
    return {
      outcome: 'skipped',
      correctIndex: question.correctIndex,
      correctOption: question.options[question.correctIndex] ?? '',
      canonicalDefinition: word?.canonicalDefinition ?? '',
    };
  }

  /** Returns a resumable view of a lesson: either remaining questions or its final summary. */
  describeLesson(input: { lessonId: string }): ResumeLessonResult | null {
    const lesson = this.deps.lessons.byId(input.lessonId);
    if (!lesson) return null;
    const questions = this.deps.questions.byLessonId(input.lessonId);
    if (lesson.state === 'completed') {
      const missed = questions.filter((q) => q.correct === false);
      const missedWords = missed
        .map((q) => {
          const w = this.deps.words.byId(q.wordId);
          return w ? { word: w.base, canonicalDefinition: w.canonicalDefinition } : null;
        })
        .filter((m): m is { word: string; canonicalDefinition: string } => m !== null);
      return {
        kind: 'completed',
        lesson,
        summary: {
          lessonId: lesson.id,
          score: lesson.score ?? questions.filter((q) => q.correct === true).length,
          total: questions.length,
          missedWords,
        },
      };
    }
    const remaining = questions
      .filter((q) => q.selectedIndex === null)
      .map((q) => {
        const word = this.deps.words.byId(q.wordId);
        return {
          id: q.id,
          word: word?.base ?? '',
          options: q.options,
          position: q.position,
        };
      });
    return {
      kind: 'in_progress',
      lesson,
      answeredCount: questions.length - remaining.length,
      totalCount: questions.length,
      remaining,
    };
  }

  completeLesson(input: { lessonId: string }): LessonSummary {
    const lesson = this.deps.lessons.byId(input.lessonId);
    if (!lesson) throw new Error('lesson not found');
    const questions: QuestionRow[] = this.deps.questions.byLessonId(input.lessonId);
    const score = questions.filter((q) => q.correct === true && !q.skipped).length;
    const skipped = questions.filter((q) => q.skipped).length;
    const wrong = questions.filter((q) => q.correct === false && !q.skipped).length;
    this.deps.lessons.markCompleted(input.lessonId, score);
    const missedWords: LessonSummary['missedWords'] = questions
      .filter((q) => q.correct === false || q.skipped)
      .map((q) => {
        const w = this.deps.words.byId(q.wordId);
        if (!w) return null;
        return {
          word: w.base,
          canonicalDefinition: w.canonicalDefinition,
          outcome: q.skipped ? ('skipped' as const) : ('incorrect' as const),
        };
      })
      .filter((m): m is { word: string; canonicalDefinition: string; outcome: 'incorrect' | 'skipped' } => m !== null);
    return { lessonId: input.lessonId, score, skipped, wrong, total: questions.length, missedWords };
  }
}
