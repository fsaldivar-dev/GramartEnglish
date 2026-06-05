# F007 Data Model Delta (v1.8.0)

`schemaVersion` stays at 3 — no SQL changes.

## New client-side type: `LessonStateSnapshot`

| Field | Type | Notes |
|---|---|---|
| `lessonId` | String (UUID) | The in-flight lesson; matched against `progress.resumable.lessonId` on resume. |
| `mode` | String | LessonMode raw value. String (not enum) so an unknown future mode degrades to "drop snapshot, start fresh" instead of failing decode. |
| `level` | String | Echoed back for the lesson-flow constructor on resume. |
| `phase` | enum `{answering, revealing}` | Question being answered vs outcome being revealed. Hint only — server re-derives. |
| `currentQuestionIndex` | Int | Zero-based index. |
| `answeredCount` | Int | Cross-check field against server-side resume payload. |
| `savedAt` | Date (ISO 8601) | For triage + future "you started this 2h ago — keep going?" prompt. |

Persisted to `~/Library/Application Support/GramartEnglish/lesson-state.json`. Encoded with `JSONEncoder` (`.iso8601` + `.sortedKeys`).

## Backend response delta: `AnswerResult.feedbackHint`

Optional Spanish teaching string the client renders post-answer.

```json
{
  "outcome": "incorrect",
  "correctIndex": 0,
  "correctOption": "went",
  "canonicalDefinition": "past tense of go",
  "typedAnswerEcho": "goed",
  "feedbackHint": "Casi — \"goed\" es el error típico, pero \"go\" es irregular. La forma correcta es **went**."
}
```

Emitted when ALL of:
- The committed answer (typed or picked) lowercases to `<verb.base>ed`.
- The lesson mode targets a verb (`conjugate_pick_form` or any typed write mode where the wordId resolves through `VerbRepository.lookupByWordId`).
- The over-regularized form is NOT the canonical simple past (regular verbs — no teaching needed).
- The outcome is `incorrect` (we don't interrupt positive feedback).

Absent otherwise.

## Swift model delta: `AnswerOutcome.feedbackHint`

Optional `String?` mirrored from the backend response, propagated through `BackendClient.AnswerLessonResponse` → `LessonViewModel` → `AnswerOutcome` → `AnswerFeedbackView`. The initializer parameter is defaulted to `nil` so existing call-sites compile unchanged.
