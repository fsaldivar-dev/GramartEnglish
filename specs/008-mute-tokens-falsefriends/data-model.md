# F008 — Data model delta

## `vocabulary_words` — new nullable column

Migration `0004_false_friend.sql`:

```sql
ALTER TABLE vocabulary_words ADD COLUMN falseFriendEs TEXT;
```

`schemaVersion` stays at **3**. The column is additive and nullable; existing
clients tolerate its absence both on the wire (`falseFriendEs?` on the DTO)
and at rest (`falseFriendEs: string | null` in the raw row, normalized to
`falseFriendEs?: string` in the domain type by `decode()` in WordRepository).

## Corpus JSON shape

Curated belt entries in `data/cefr/a2.json` and `data/cefr/b1.json` carry a
`false_friend_es` key (snake_case to match the existing file convention).
`corpusLoader.ts` normalizes to camelCase before persisting.

Belt entries shipped in v1.9.0:

| Word | Level | false_friend_es |
|---|---|---|
| library | A2 | `OJO: no es 'librería' (bookstore — that's 'bookstore')` |
| exit | A2 | `OJO: no es 'éxito' (success)` |
| success | A2 | `OJO: no es 'suceso' (event)` |
| carpet | A2 | `OJO: no es 'carpeta' (folder)` |
| fabric | A2 | `OJO: no es 'fábrica' (factory)` |
| realize | B1 | `OJO: no es 'realizar' (do/carry out)` |
| actually | B1 | `OJO: no es 'actualmente' (currently/nowadays)` |
| assist | B1 | `OJO: no es 'asistir' (attend)` |
| sensible | B1 | `OJO: no es 'sensible' (sensitive)` |
| embarrassed | B1 | `OJO: no es 'embarazada' (pregnant)` |

## On-wire DTO

`LessonQuestion.falseFriendEs?: string` propagates through:

```
WordRepository.byBase()
  → LessonService.startLesson() / .describeLesson()
  → routes/lessons.ts response body
  → BackendClient.LessonQuestionDTO.falseFriendEs
  → LessonKit.LessonQuestion.falseFriendEs
  → AnswerFeedbackView (rendered as a warning chip post-answer)
```

No new endpoint, no new schema version, no new persistence on the client.
