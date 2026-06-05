# F009 — data-model delta

## Schema

No SQLite schema migration. `falseFriendEs` column was already added by
F008 migration `0004_false_friend.sql`; F009 just adds new rows that
populate it.

## Corpus additions

### `data/cefr/a1.json` (4 new rows)

| base       | pos       | spanishOption | false_friend_es |
|------------|-----------|---------------|-----------------|
| large      | adjective | grande        | OJO: 'large' = grande. NO es 'largo' (que significa long). |
| rope       | noun      | cuerda        | OJO: 'rope' = cuerda. NO es 'ropa' (que significa clothes). |
| once       | adverb    | una vez       | OJO: 'once' = una vez. NO es 'once' en español (que es el número eleven). |
| soap       | noun      | jabón         | OJO: 'soap' = jabón. NO es 'sopa' (que significa soup). |

### `data/cefr/b1.json` (2 new rows)

| base         | pos       | spanishOption           | false_friend_es |
|--------------|-----------|--------------------------|-----------------|
| constipated  | adjective | estreñido                | OJO: 'constipated' = estreñido. NO es 'constipado' (que en español significa resfriado, con catarro). |
| molest       | verb      | abusar sexualmente       | OJO: 'molest' = abusar sexualmente (palabra muy grave). NO es 'molestar' (que significa to bother). |

### `data/cefr/a2.json` (1 row updated)

- `success` — copy fix: `(event)` → `(un evento o noticia)`.

## Runtime model

### `VocabularyWordRow.falseFriendEs?: string`

Already present (F008). F009 only adds population.

### `wordSelector.ts` exported constant

```ts
export const FALSE_FRIEND_BIAS_FACTOR = 1.15;
```

The selector applies this per-candidate when the word has `falseFriendEs`
AND isn't mastered in the current mode.

## Asset catalog

`app/GramartEnglish/Sources/Resources/Assets.xcassets/` (created):

```
Assets.xcassets/
  Contents.json
  SemanticSuccess.colorset/Contents.json
  SemanticWarning.colorset/Contents.json
  SemanticError.colorset/Contents.json
```

Each colorset declares both a `light` (default) and `dark` (appearance
`luminosity` = `dark`) variant with sRGB float components.
