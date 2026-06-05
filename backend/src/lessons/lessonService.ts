import type { CefrLevel, LessonMode } from '../domain/schemas.js';
import type { LessonRepository, LessonRow } from '../store/lessonRepository.js';
import type { QuestionRepository, QuestionRow } from '../store/questionRepository.js';
import type { WordRepository } from '../store/wordRepository.js';
import type { MasteryRepository } from '../store/masteryRepository.js';
import type { VerbRepository } from '../store/verbRepository.js';
import { LESSON_SIZE, selectLessonWords } from './wordSelector.js';
import { buildOptions } from './distractorBuilder.js';
import { buildVerbQuestion, isAmbiguousForPickForm, overRegularize } from './verbConjugationBuilder.js';
import { levenshteinAtMost } from './levenshtein.js';
import { maskWord } from './gapMasker.js';

const TYPED_TOLERANCE = 1;

export interface LessonServiceDeps {
  lessons: LessonRepository;
  questions: QuestionRepository;
  words: WordRepository;
  mastery: MasteryRepository;
  /** v1.6+. Optional — required only when the server is configured to serve
   *  `conjugate_pick_form` lessons. Other modes do not touch this. */
  verbs?: VerbRepository;
}

export interface ClientLessonQuestion {
  id: string;
  word: string;
  options: string[];
  position: number;
  /** v1.3+. Populated for write modes — Spanish meaning the client should
   *  render as the prompt instead of `word`. Absent for read/listen modes. */
  prompt?: string;
  /** v1.5+. Populated only for `write_fill_gaps` questions where the target
   *  word is long enough to mask (length > 3). Holds the scaffolded English
   *  word with underscores in removed positions (e.g. `w__th_r`). When the
   *  target word is ≤ 3 letters the masker auto-promotes the question to
   *  plain typed-answer behavior server-side — `maskedWord` is omitted and
   *  the client renders the same way it does for `write_type_word`. The
   *  lesson row stays mode=`write_fill_gaps` so mastery accounting is per
   *  the chosen axis (FR-007). */
  maskedWord?: string;
  /** v1.6+. Populated for `conjugate_pick_form` only — English base form of
   *  the verb (e.g. "go" when the answer is "went"). */
  verbBase?: string;
  /** v1.6+. Populated for `conjugate_pick_form` only — target tense string
   *  (`"simple_past"` for v1.6.0). */
  targetTense?: 'simple_past';
  /** v1.6.0 patch (Blocker 2). Populated for `conjugate_pick_form` only.
   *  Spanish example sentence with `___` marking the verb slot. Renders
   *  below the "Pasado simple de …" header to disambiguate tenses Spanish
   *  distinguishes (preterite/imperfect) but English collapses. */
  exampleEs?: string;
  /** v1.6.0 patch (Blocker 2). Populated for `conjugate_pick_form` only.
   *  English translation with the verb already conjugated. The client
   *  reveals it after the answer for reinforcement, not before. */
  exampleEn?: string;
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
  /** F007 (v1.8.0). Optional teaching string the client surfaces in
   *  `AnswerFeedbackView` when present. Populated when the learner
   *  committed to the over-regularized form of an irregular verb (e.g.
   *  typed "goed" / picked an option that matches `<base>ed`), to make
   *  the L1-interference error visible at the moment it lands instead
   *  of letting the wrong spelling rehearse silently. Absent otherwise. */
  feedbackHint?: string;
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
    // v1.6 F004 US1: conjugate_pick_form takes a verb-corpus path. Mastery
    // axis is still (userId, wordId, mode); wordId resolves to the verb's
    // vocabulary_words row via verbs.json provenance.
    if (mode === 'conjugate_pick_form') {
      return this.startConjugationLesson({ ...input, mode });
    }
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
    const isWriting = mode === 'write_pick_word' || mode === 'write_type_word' || mode === 'write_fill_gaps';
    const clientQuestions: ClientLessonQuestion[] = rows.map((r) => {
      const word = words[r.position]!;
      const base: ClientLessonQuestion = {
        id: r.id,
        word: word.base,
        options: r.options,
        position: r.position,
      };
      // v1.3 F003: write modes need the Spanish meaning rendered as the prompt
      // because `word` (English) is what TTS plays and what the answer key is.
      if (isWriting) {
        base.prompt = word.spanishOption;
      }
      // v1.5 F003 US3: write_fill_gaps adds a scaffolded mask. v1.5.1 — for
      // words ≤ 3 letters the masker still auto-promotes (rule 1 in research
      // §1) but now returns a first-letter scaffold (`eat` → `e__`), which we
      // forward as `maskedWord` so the "completa la palabra" UI promise is
      // honored. Lesson row stays mode=write_fill_gaps, mastery axis intact
      // (FR-007). `maskedWord` is omitted only when the masker produced no
      // usable scaffold (1-letter defensive case).
      if (mode === 'write_fill_gaps') {
        const { masked } = maskWord(word.base);
        if (masked && masked !== word.base) {
          base.maskedWord = masked;
        }
      }
      return base;
    });
    return { lesson, questions: clientQuestions };
  }

  /** v1.6 F004 US1 — conjugate_pick_form lesson assembly. Picks `LESSON_SIZE`
   *  verbs at the target level, builds an MCQ per verb via
   *  `verbConjugationBuilder`, persists rows keyed by the verb's wordId so
   *  the existing answer + mastery pipeline applies unchanged. */
  private startConjugationLesson(input: {
    userId: string;
    level: CefrLevel;
    correlationId: string;
    mode: 'conjugate_pick_form';
    seed?: number;
  }): StartLessonResult {
    if (!this.deps.verbs) {
      throw new Error('verb corpus not configured (conjugate_pick_form requires VerbRepository)');
    }
    const verbsRepo = this.deps.verbs;
    // v1.6.0 patch (Blocker 1): drop verbs whose base spells identically to
    // their simple_past (e.g. read/read, cut/cut). MCQ collapses to
    // {correct, "base"} where both are the same string — unanswerable.
    const pool = verbsRepo.atLevel(input.level).filter((v) => !isAmbiguousForPickForm(v));
    if (pool.length < LESSON_SIZE) {
      throw new Error(
        `Not enough verbs at ${input.level} to start a ${LESSON_SIZE}-question lesson (have ${pool.length})`,
      );
    }
    // Seeded shuffle for deterministic tests.
    const seedSource = input.seed ?? Math.floor(Math.random() * 2 ** 32);
    let s = seedSource >>> 0;
    const shuffled = [...pool];
    for (let i = shuffled.length - 1; i > 0; i -= 1) {
      s = (s * 1664525 + 1013904223) >>> 0;
      const j = s % (i + 1);
      [shuffled[i]!, shuffled[j]!] = [shuffled[j]!, shuffled[i]!];
    }
    const chosenVerbs = shuffled.slice(0, LESSON_SIZE);

    const lesson = this.deps.lessons.create({
      userId: input.userId,
      level: input.level,
      mode: input.mode,
      correlationId: input.correlationId,
    });

    const newQuestions = chosenVerbs.map((verb, position) => {
      const built = buildVerbQuestion(verb, verbsRepo, {
        level: input.level,
        seed: seedSource + position,
      });
      return {
        lessonId: lesson.id,
        position,
        wordId: verb.wordId,
        options: built.options,
        correctIndex: built.correctIndex,
      };
    });
    const rows = this.deps.questions.createMany(newQuestions);

    const clientQuestions: ClientLessonQuestion[] = rows.map((r, idx) => {
      const verb = chosenVerbs[idx]!;
      return {
        id: r.id,
        word: verb.base, // English base — TTS plays this; client shows Spanish prompt
        options: r.options,
        position: r.position,
        prompt: `Pasado simple de **${verb.es}**`,
        verbBase: verb.base,
        targetTense: 'simple_past' as const,
        exampleEs: verb.exampleEs,
        exampleEn: verb.exampleEn,
      };
    });
    return { lesson, questions: clientQuestions };
  }

  submitAnswer(input: {
    lessonId: string;
    questionId: string;
    optionIndex?: number;
    typedAnswer?: string;
    /** v1.3 (F003 FR-009): user revealed letters via hint — zeroes the
     *  consecutiveCorrect streak even on a correct typed answer. */
    hintUsed?: boolean;
    answerMs: number;
    userId: string;
  }): AnswerResult {
    const question = this.deps.questions.byId(input.questionId);
    if (!question) throw new Error('question not found');
    if (question.lessonId !== input.lessonId) throw new Error('question/lesson mismatch');

    const lesson = this.deps.lessons.byId(input.lessonId);
    const mode: LessonMode = (lesson?.mode as LessonMode | undefined) ?? 'read_pick_meaning';
    const word = this.deps.words.byId(question.wordId);
    const isTyped = mode === 'listen_type' || mode === 'write_type_word' || mode === 'write_fill_gaps';

    if (isTyped) {
      if (input.typedAnswer === undefined) throw new Error(`typedAnswer required for ${mode}`);
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
        ...(input.hintUsed ? { hintUsed: true } : {}),
      });
      const hint = this.maybeOverRegularizationHint({
        mode,
        wordId: question.wordId,
        committed: typedNorm,
        correct,
      });
      return {
        outcome: correct ? 'correct' : 'incorrect',
        correctIndex: 0,
        correctOption: word?.base ?? '',
        canonicalDefinition: word?.canonicalDefinition ?? '',
        typedAnswerEcho: typedTrimmed,
        ...(hint ? { feedbackHint: hint } : {}),
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
      ...(input.hintUsed ? { hintUsed: true } : {}),
    });

    const pickedOption = (question.options[input.optionIndex] ?? '').toLowerCase();
    const hint = this.maybeOverRegularizationHint({
      mode,
      wordId: question.wordId,
      committed: pickedOption,
      correct,
    });
    return {
      outcome: correct ? 'correct' : 'incorrect',
      correctIndex: question.correctIndex,
      correctOption: question.options[question.correctIndex] ?? '',
      canonicalDefinition: word?.canonicalDefinition ?? '',
      ...(hint ? { feedbackHint: hint } : {}),
    };
  }

  /**
   * F007 (v1.8.0). When the learner's committed answer matches the
   * over-regularized form of the target verb (e.g. typed "goed" for `go`,
   * or in a future picker variant picks an option that happens to be
   * `<base>ed`), return a Spanish teaching string that names the error.
   * Returns undefined for correct answers (no need to interrupt the
   * positive feedback), for non-verb questions, or when the verbs
   * repository is unavailable.
   */
  private maybeOverRegularizationHint(input: {
    mode: LessonMode;
    wordId: number;
    committed: string;
    correct: boolean;
  }): string | undefined {
    if (input.correct) return undefined;
    // Surface the hint when the learner is being assessed on a verb form:
    // conjugate_pick_form (post-F007: rare, since the option pool no longer
    // includes the over-regularized form, but a future custom drill or
    // distractor-pool override could resurface it — keep the defensive
    // path) OR a typed write mode where the canonical answer is a verb
    // base/past and the learner produced `<base>ed`.
    const verb = this.deps.verbs?.lookupByWordId(input.wordId);
    if (!verb) return undefined;
    const isVerbBearingMode =
      input.mode === 'conjugate_pick_form' ||
      input.mode === 'write_type_word' ||
      input.mode === 'write_fill_gaps' ||
      input.mode === 'listen_type';
    if (!isVerbBearingMode) return undefined;
    const over = overRegularize(verb.base).toLowerCase();
    if (input.committed.trim().toLowerCase() !== over) return undefined;
    // Skip the rare case where the over-regularized spelling is also the
    // canonical simple past (regular verbs) — there's nothing to teach.
    if (over === verb.simplePast.toLowerCase()) return undefined;
    return (
      `Casi — "${overRegularize(verb.base)}" es el error típico, pero ` +
      `"${verb.base}" es irregular. La forma correcta es **${verb.simplePast}**.`
    );
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
      const missed = questions.filter((q) => q.correct === false || q.skipped);
      const missedWords: LessonSummary['missedWords'] = missed
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
      const skipped = questions.filter((q) => q.skipped).length;
      const wrong = questions.filter((q) => q.correct === false && !q.skipped).length;
      return {
        kind: 'completed',
        lesson,
        summary: {
          lessonId: lesson.id,
          score: lesson.score ?? questions.filter((q) => q.correct === true).length,
          skipped,
          wrong,
          total: questions.length,
          missedWords,
        },
      };
    }
    const lessonMode: LessonMode = (lesson.mode as LessonMode | undefined) ?? 'read_pick_meaning';
    const isWriting = lessonMode === 'write_pick_word' || lessonMode === 'write_type_word' || lessonMode === 'write_fill_gaps';
    const remaining = questions
      .filter((q) => q.selectedIndex === null)
      .map((q): ClientLessonQuestion => {
        const word = this.deps.words.byId(q.wordId);
        const base: ClientLessonQuestion = {
          id: q.id,
          word: word?.base ?? '',
          options: q.options,
          position: q.position,
        };
        // F007 patch (v1.8.0). Match `startLesson`'s per-mode enrichment so a
        // resumed write/fill-gaps lesson surfaces the Spanish prompt + the
        // masked scaffold — without these the client renders a blank prompt.
        if (isWriting && word) {
          base.prompt = word.spanishOption;
        }
        if (lessonMode === 'write_fill_gaps' && word) {
          const { masked } = maskWord(word.base);
          if (masked && masked !== word.base) {
            base.maskedWord = masked;
          }
        }
        if (lessonMode === 'conjugate_pick_form' && this.deps.verbs) {
          const verb = this.deps.verbs.lookupByWordId(q.wordId);
          if (verb) {
            base.prompt = `Pasado simple de **${verb.es}**`;
            base.verbBase = verb.base;
            base.targetTense = 'simple_past';
            base.exampleEs = verb.exampleEs;
            base.exampleEn = verb.exampleEn;
          }
        }
        return base;
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
