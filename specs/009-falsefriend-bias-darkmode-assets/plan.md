# F009 — implementation plan

## Stack reuse

- **Backend**: `data/cefr/a1.json` `data/cefr/a2.json` `data/cefr/b1.json`
  corpus updates; `backend/src/lessons/wordSelector.ts` bias hook;
  `corpusLoader.ts` zod parser unchanged (already accepts `false_friend_es`).
- **App**: `app/GramartEnglish/Resources/Assets.xcassets/` introduced
  (Package.swift gains `resources: [.process("Resources")]`); SwiftUI
  `Color("Name", bundle: .module)` lookup. `DesignTokens.swift` Semantic
  enum rewritten. `SpeakButton.swift` reads `SpeechService.shared.isMuted`
  (already polled at v1.9.0) and toggles symbol.

## TDD order (per `tasks.md`)

1. Corpus tests for the 6 new entries + the success-copy fix (xfail until corpus updated).
2. Asset-catalog Semantic-color contrast test (xfail until `.colorset` shipped).
3. `wordSelector` bias test (xfail until bias factor wired).
4. `SpeakButton` muted-icon test (xfail until icon swap shipped).
5. Implement in the same order; flip each test green.

## Concurrency notes (Swift 5.9 strict mode)

- `SpeakButton` already reads `SpeechService.shared` synchronously from `body`. No actor isolation hop is needed.
- `SemanticColorsTests` runs synchronously on the test target; we call `NSColor(named:)` directly. No `@MainActor` annotation required because `NSColor` is `Sendable` and the assertion happens before any UI host appears.
- If the asset-bundle lookup fails under SPM resource processing, fall back to `Bundle.module` via a `TestFlag` (precedent: commits b7d4814, 069e3fb).

## Performance

- Bias multiplier is a single integer compare + `*= 1.15` per candidate word; constant-time, fits well under the F005 `placementP95` budget.
- Color lookup is cached by `NSColor` after first hit, so the rendering hot path is unchanged.

## Risks

- **R1**: SPM resources for the executable target require `path: "Sources"` to coexist with a `resources:` clause. If Xcode-built app diverges from `swift build` behaviour, the asset catalog must be wired through both. Mitigation: keep the catalog inside `Sources/Resources/` so `path: "Sources"` already covers it.
- **R2**: `falseFriendEs` is `undefined` for ~95 % of rows; weight multiplication on `undefined` would NaN the result. Test pins the truthy guard.

## Versioning

- `version.json` → 1.10.0; `schemaVersion` stays at 3; `ragIndexSchemaVersion` stays at 1.
- OpenAPI `info.version` → 1.10.0 (no path changes).
