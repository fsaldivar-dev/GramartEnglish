# F008 — Mute toggle, token sweep, false-friend belt, summary buttons

**Release**: v1.9.0
**Branch**: `feat/008-mute-tokens-falsefriends-v1.9.0`
**Base**: v1.8.0 (commit 206927a)

## Why now

The five-persona panel converged on four high-leverage, low-risk polish items
for v1.9. Each addresses a real complaint logged in v1.4–v1.8 QA but doesn't
require new feature scaffolding.

## Scope (locked, 4 items, NO additions)

### 1. Mute icon in lesson chrome — Marisol + Priya (S)
Currently the only way to mute auto-fire TTS is via Settings → 2 hops mid-
lesson. Add a top-left mute toggle next to the exit X in every lesson view
(`LessonQuestionView`, `ListeningLessonView`, `WritingLessonView`,
`ConjugationLessonView`). Bound to `SpeechService.shared.isMuted`. `M` is the
bare-key shortcut. VoiceOver: label "Silenciar audio", value reflects state,
hint mentions the `M` shortcut.

### 2. Token propagation sweep — Mariana (M)
v1.8.0 introduced `Spacing` / `Radius` / `Tint` / `Semantic` tokens but only
migrated two call-sites. Sweep `Sources/Features/` so it contains zero
`.system(size: N)` literals — every hardcoded point size becomes a Dynamic-
Type-relative `.font(.system(.TextStyle, …))` with `minimumScaleFactor(...)`.
Migrate cornerRadius literals at the three sanctioned steps (8 → `Radius.sm`,
12 → `Radius.md`, 16 → `Radius.lg`). Lint test in `DesignTokenContractTests`
fails the build if any feature view reintroduces a point literal.

### 3. False-friend belt + L1 transfer copy — Lucía (S)
Add optional `falseFriendEs: string?` to vocabulary entries. Curate ~10
high-frequency belt entries (`realize`, `actually`, `library`, `exit`,
`success`, `embarrassed`, `fabric`, `carpet`, `sensible`, `assist`).
Server forwards the warning on every mode; `AnswerFeedbackView` renders a
small warning chip after the canonical reveal. Also: tighten the existing
over-regularization `feedbackHint` to name the L1 pattern ("**de
hispanohablantes**") so the learner understands WHY they wrote `goed`.

### 4. Differentiate onStartAnother vs onBackHome — Priya (S)
`LessonSummaryView` already exposes two callbacks, but `RootView` wires
both to the same `onExit` → "Empezar otra lección" forces a Home detour.
Wire `onStartAnother` to reset the VM and call `vm.start(resumeId: nil)`
directly so the next lesson starts in-place.

## Out of scope (explicitly)

- No new lesson modes.
- No new RAG sources.
- No Dynamic-Type re-audit (Mariana's full audit is queued for v1.10).
- No asset-catalog migration of `Semantic.*` colors (still v1.10).

## Constitutional callouts

- **Principle III (TDD)**: failing tests first for every layer.
- **Principle VII (Accessibility)**: mute toggle ships with label/value/hint;
  font migrations preserve Dynamic Type at accessibility5.
- **Privacy-first**: no telemetry added. Mute preference stays in local
  UserDefaults under the existing `gramart.speech.muted` key.

## Schema version

`schemaVersion` stays at **3**. The `falseFriendEs` column is additive and
nullable (migration `0004_false_friend.sql`); existing clients tolerate the
absence.
