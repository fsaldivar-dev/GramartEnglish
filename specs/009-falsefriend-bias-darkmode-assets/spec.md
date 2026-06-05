# F009 — False-friend bias + Dark Mode assets + corpus belt v2

**Version**: v1.10.0
**Schema**: 3 (unchanged)
**Status**: in-flight

## Why this release exists

The v1.9.0 five-panel review surfaced four items that the team agreed were
locked-scope for v1.10.0. Each is small individually; together they close
the loop on the v1.9.0 false-friend belt (Lucía) and the v1.8.0 design-token
introduction (Mariana).

## Scope (locked — 4 items)

### Item 1 — Semantic colors via asset catalog (Dark Mode)

`DesignTokens.Semantic.{success, warning, error}` currently aliases
`Color.green/.orange/.red` with a v1.8.0 TODO comment. Both Lucía
(accessibility) and Mariana (visual debt) flagged that the system primaries
collapse to indistinguishable washed shades against the macOS Dark Mode
"window background" surface that lesson views render on.

Introduce three named colors via `Assets.xcassets`:

| Token              | Light hex   | Dark hex   | Source surface (target ≥ 4.5:1) |
|--------------------|-------------|------------|---------------------------------|
| `SemanticSuccess`  | `#0E7C3A`   | `#4ADE80`  | `NSColor.windowBackgroundColor` |
| `SemanticWarning`  | `#B45309`   | `#FBBF24`  | `NSColor.windowBackgroundColor` |
| `SemanticError`    | `#B91C1C`   | `#F87171`  | `NSColor.windowBackgroundColor` |

Light hexes are AA on `#FFFFFF`; dark hexes are AA on `#1E1E1E` (the
macOS dark window background). Both targets verified via the
`SemanticColorsTests` luminance calculator.

### Item 2 — A1 false-friend belt + missing high-frequency entries

Six new false-friend entries split A1 (4) + B1 (2), plus a copy fix on the
already-shipped A2 `success`:

- **A1**: `large`, `rope`, `once`, `soap`
- **B1**: `constipated`, `molest`
- **A2 fix**: `success` — "OJO: 'success' = triunfo, éxito. NO es 'suceso' (que es un evento o noticia)."

The A1 entries are NEW words in the corpus (not yet shipped). They follow
the same shape as existing A1 rows: `base`, `pos`, `level`, `spanishOption`,
`canonicalDefinition`, `canonicalExamples`, `sourceTag`, and the optional
`false_friend_es` (snake_case in JSON, normalised to `falseFriendEs`).

### Item 3 — False-friend bias (+15 % selection weight)

When `selectLessonWords` is building a lesson, candidate words that carry
`falseFriendEs` AND are NOT yet mastered in the current mode get a +15 %
selection weight. Mastered false-friend words revert to baseline so the
belt doesn't dominate review lessons.

The constant `FALSE_FRIEND_BIAS_FACTOR = 1.15` is exported from
`wordSelector.ts` with a top-of-file pedagogical-rationale comment.

### Item 4 — Per-question muted-state indicator on every `SpeakButton`

v1.9.0 dimmed `SpeakButton`'s glyph to `.secondary` while
`SpeechService.shared.isMuted`. Priya's panel asked for one more signal —
the icon itself should flip to `speaker.slash.fill` so the affordance
matches the chrome `MuteToggleButton`. Tap behaviour is unchanged (the
`isUserInitiated` bypass from v1.4.1 still plays audio on explicit tap),
but the VoiceOver label appends "(audio silenciado)" so screen-reader
users learn the same state.

## Out of scope

- New lesson modes
- Schema-version bump
- Any UI not already on the locked list
- Spacing/radius token propagation outside Semantic colors
- Settings → Appearance toggle (we follow the system Light/Dark setting)

## Acceptance

- All four items shipped with TDD test coverage
- Asset-catalog colors verified to ≥ 4.5:1 in both appearances by automated test
- `selectLessonWords` bias test: ≥ 1 false-friend in first 10 questions in
  ≥ 80 % of seeded runs (50-run sample, 40-word pool, 4 false-friends)
- `SpeakButton` icon + a11y label change with `isMuted`
- `version.json` → 1.10.0, OpenAPI `info.version` → 1.10.0
- README, CLAUDE.md updated to point at F009
