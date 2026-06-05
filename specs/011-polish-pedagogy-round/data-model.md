# F011 — Data model delta (v1.12.0)

No schema changes. `schemaVersion` stays at 3.

## Corpus delta

Three existing entries gain a refined `false_friend_es` value. No
new entries added.

| File              | Word      | Field             | Change                                  |
| ----------------- | --------- | ----------------- | --------------------------------------- |
| `data/cefr/a1.json` | `large`   | `false_friend_es` | embedded-English style refinement       |
| `data/cefr/a2.json` | `success` | `false_friend_es` | already v1.10-style — no change         |
| `data/cefr/b1.json` | `assist`  | `false_friend_es` | embedded-English style refinement       |

The corpus shape (`base`, `pos`, `level`, `spanishOption`,
`canonicalDefinition`, `canonicalExamples`, `sourceTag`,
`false_friend_es?`) is unchanged.

## Snapshot model

`LessonStateSnapshot.totalCount: Int?` (added in v1.11.0 Polish A)
is verified non-nil for every persistence path on the producer side
by `SnapshotTotalCountTests`. No schema field added, no decoder
change.
