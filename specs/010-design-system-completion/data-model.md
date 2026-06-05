# F010 — Data model delta (v1.11.0)

No schema changes. `schemaVersion` stays at **3**.

## Corpus additions (data/cefr/)

Four new `VocabularyWordRow` entries (existing shape — `base`, `pos`,
`level`, `spanishOption`, `canonicalDefinition`, `canonicalExamples`,
`sourceTag`, optional `false_friend_es`):

| File      | Base         | POS       | Notes                              |
| --------- | ------------ | --------- | ---------------------------------- |
| `a2.json` | `record`     | verb      | NEW — Lucía's belt entry          |
| `a2.json` | `embarrassed`| adjective | EXISTING — copy refined (v1.9 → v1.11) |
| `b1.json` | `embarrassed`| adjective | EXISTING — copy refined mirror     |
| `b1.json` | `attend`     | verb      | NEW                                |
| `b1.json` | `discuss`    | verb      | NEW                                |

All five entries carry `false_friend_es`. The column was introduced
in F008 (migration `0004`); no new migration in F010.

## Client-side state

`LessonStateSnapshot` (from F007) is unchanged. The new resume CTA
on `LessonSummaryView` re-uses the existing snapshot fields
(`lessonId`, `currentQuestionIndex`, `mode`, `level`) without any
additional persistence.

## Assets

Two color asset darkHex variants flip (no schema):

- `SemanticWarning.colorset/Contents.json` — dark sRGB components
  `(0.984, 0.749, 0.141)` → `(0.961, 0.761, 0.259)`.
- `SemanticError.colorset/Contents.json` — dark sRGB components
  `(0.973, 0.443, 0.443)` → `(0.937, 0.357, 0.357)`.

The matching SPM-fallback `DesignTokens.Semantic.{warningDarkHex,
errorDarkHex}` constants move from `0xFBBF24` / `0xF87171` to
`0xF5C242` / `0xEF5B5B`.
