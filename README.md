<div align="center">
  <img src=".github/assets/app-icon.png" alt="GramartEnglish app icon" width="160" height="160" />

  # GramartEnglish

  A native macOS app that helps English learners build vocabulary at their own CEFR level (A1–C2), with optional AI-generated example sentences grounded in a curated local corpus via a local LLM (Ollama).

  **Latest release** · [v1.12.0](https://github.com/fsaldivar-dev/GramartEnglish/releases/latest)  ·  **Status**: MVP development. Spec-driven via [spec-kit](https://github.com/github/spec-kit).
</div>

## Principles

GramartEnglish is built under a written project constitution. The full ratified rules live in [.specify/memory/constitution.md](.specify/memory/constitution.md), but the headline is:

- **Test-First** (non-negotiable)
- **Library-First** architecture
- **Simplicity & YAGNI**
- **Observability** (structured logs + correlation id end-to-end)
- **Versioning** (SemVer, schema versions, `/v1` API prefix)
- **Security & Privacy** — no login, no telemetry, no data leaves the device
- **Accessibility** — VoiceOver, keyboard nav, Dynamic Type, Increase Contrast
- **Performance budgets** (≤ 2 s cold launch, ≤ 1.5 s LLM first token)

## What's new

- **v1.12.0 — Polish + pedagogy round (F011, 4 locked items)** —
  - **Lucía false-friend copy refinement**: `large` (A1) and `assist` (B1) updated to the v1.10 embedded-English style — the Spanish gloss now names the English target inline ("NO es 'largo' (que en inglés es long)", "NO es 'asistir' (que es to attend an event)") so learners who don't know the contrast verb can still resolve the trap. `success` (A2) already shipped in this style; verified.
  - **Mariana `.padding(N)` literal sweep (bare-number subset, ~13 % of padding sites)**: 9 bare-number `.padding(N)` call-sites across `Sources/Features/` migrated to the `Spacing.*` scale (16→md, 20→lg↑, 24→lg, 28→xl↑, 32→xl). Two round-ups (20→24 in `ExamplesPanelView`, 28→32 in `ListeningLessonView`) documented inline. `DesignTokenContractTests.testNoTokenLiteralsInFeatures` gains a fourth lint regex so future drift fails CI with the same diagnostic shape as the v1.9 / v1.10 lints. **Honest framing (Mariana, v1.12.0 patch)**: this is the bare-number subset only — ~60 named-edge `.padding(.edge, N)` literals across the codebase are still untouched and deferred to v1.13. The design system is NOT "complete" this round; the lint catches the bare-number form only.
  - **Priya keyboard cheatsheet (⌘/)**: new `ShortcutsCheatsheetView` surfaces every shortcut shipping today behind a global `⌘/` trigger — 9 entries across three sections (Audio: S/D/⌘M; Respuesta: 1–4/0/Enter/⌘H; Navegación: Esc/⌘/). Each row is a monospaced key + Spanish action; VoiceOver announces `"<key>, <action>"` as a single utterance. Hosted via a zero-size, accessibility-hidden Button in `ReadyFlowView`'s ZStack — the SwiftUI-idiomatic way to attach a global shortcut without a visible control. Esc closes via `.cancelAction`.
  - **Snapshot `totalCount` regression net**: v1.11 Polish A plumbed `totalCount` through `ResumeLessonCard` (the consumer) but left no test on the producer side. Audit confirmed every `LessonViewModel` persistence routes through `persistSnapshot()` → `snapshot(for:)` and always sets `totalCount: state.questions.count`. New `SnapshotTotalCountTests` (5 cases) pins the invariant after start, after answer, after `dismissVerbIntro`, after skip, and after mid-lesson abandon — so the next refactor that adds a new save call-site can't silently null it.
  - See [specs/011-polish-pedagogy-round/](specs/011-polish-pedagogy-round/).
- **v1.11.0 — Design system completion + Resume CTA + 4 false-friends (F010, 4 locked items)** —
  - **Token sweep finished**: Mariana's v1.10 IOU paid. 13 `cornerRadius` literals, 5 `.tint.opacity` literals, and 5 raw `.green/.red/.orange` foregrounds across `Sources/Features/` (+ one in `App/RootView`) migrated to `Radius.*`, `Tint.*`, and `Semantic.*` tokens. Rounding policy: when between scale steps, round to the lower step (the two `cornerRadius: 14` literals in `ModeCard` go to `Radius.md`=12, not `Radius.lg`=16). The contract test now lints all three literal classes with the same offender-list shape as the F008 `.system(size:)` walker.
  - **Warm-tune dark Semantic palette**: dark `SemanticWarning` flips `#FBBF24` → `#F5C242` (canary → honey amber), dark `SemanticError` flips `#F87171` → `#EF5B5B` (coral-pink → saturated coral). Both still clear WCAG AA on `#1E1E1E` (warning ≈ 10.2:1, error ≈ 5.1:1) per the updated `SemanticColorsTests`. Light variants and `SemanticSuccess` are unchanged.
  - **Resume CTA on the lesson summary**: Priya's P1. When `LessonSummaryView` renders and `LessonStateStore` still holds a snapshot for a *different* in-flight lesson, a "Continuar lección anterior" card now surfaces above the existing CTAs. Without it, an abandoned lesson would silently rot under the next "Empezar otra lección" click. New `ResumeLessonCard`; `LessonSummaryView` gains `resumableSnapshot:` + `onResumeLesson:` + a public `shouldShowResumeCard` predicate for testability.
  - **4 new Lucía false-friend belt entries**: `embarrassed` at A2 + B1 with refined copy (names the social cost: "el más peligroso socialmente"), `record` at A2 (grabar vs recordar), `attend` at B1 (asistir a vs atender), `discuss` at B1 (conversar sobre vs pelear). Round-trip pinned by `backend/tests/unit/store/falseFriend.f010.test.ts`.
  - See [specs/010-design-system-completion/](specs/010-design-system-completion/).
- **v1.10.0 — False-friend bias, Dark Mode assets, A1 belt expansion, muted speaker glyph (F009, 4 locked items)** —
  - **Dark Mode semantic colors**: `Semantic.success/warning/error` finally pay off the v1.8.0 TODO. Three named colorsets ship in `Sources/Resources/Assets.xcassets` with light + dark variants tuned to WCAG AA contrast on the macOS window background (`#0E7C3A`/`#4ADE80`, `#B45309`/`#FBBF24`, `#B91C1C`/`#F87171`). An SPM-build fallback synthesises a dynamic NSColor that auto-swaps on `ColorScheme` when the catalog isn't compiled by `actool`, so `swift build` runs stay correct.
  - **A1 + B1 false-friend belt v2**: 6 new entries — A1 ×4 (`large`/`rope`/`once`/`soap`) catch day-1 traps that the v1.9.0 A2/B1 belt didn't cover; B1 ×2 (`constipated`/`molest`) are the highest-social-cost traps. Each carries the same "OJO: …" warning pattern as the v1.9 belt.
  - **False-friend selection bias**: `FALSE_FRIEND_BIAS_FACTOR = 1.15` applied per-candidate inside `selectLessonWords` (Efraimidis-Spirakis weighted shuffle). Belt words that are NOT yet mastered in the current mode get a +15 % lift so the "OJO" cue actually surfaces during practice; mastered belt words revert to baseline so review lessons aren't dominated. Seeded statistical test: ≥ 80 % of 50 runs show ≥ 1 false-friend in the chosen 10.
  - **Per-question muted-state indicator**: every `SpeakButton` (not just chrome) now swaps to `speaker.slash.fill` while `SpeechService.shared.isMuted`. VoiceOver label appends "(audio silenciado)". Tap behaviour unchanged — explicit user taps still play (v1.4.1 F3 bypass).
  - See [specs/009-falsefriend-bias-darkmode-assets/](specs/009-falsefriend-bias-darkmode-assets/).
- **v1.9.0 — Mute toggle, token sweep, false-friend belt, summary buttons (F008, 4 locked items)** —
  - **In-lesson mute toggle**: every lesson chrome ships a top-right mute button left of the exit X. `⌘M` is the keyboard shortcut (bare `M` collided with typed-answer input). Bound to the existing `SpeechService.shared.isMuted` UserDefaults flag — no more two-hop trip through Settings to silence auto-fire TTS in a cafe. The speaker glyphs dim to `.secondary` while muted as a trust signal.
  - **Token sweep**: `Sources/Features/` is now free of `.system(size: N)` literals — every hero font is Dynamic-Type-relative (`.font(.system(.title, design: .rounded))` + `minimumScaleFactor`). A grep-based lint in `DesignTokenContractTests` fails the build if a literal sneaks back in. Sanctioned cornerRadius literals (8/12/16) migrated to `Radius.sm/.md/.lg`.
  - **False-friend belt**: 10 false-friend alerts split across A2 (`library`/`exit`/`success`/`carpet`/`fabric`/`embarrassed`) and B1 (`realize`/`actually`/`assist`/`sensible`/`embarrassed`) — `embarrassed` is duplicated at both levels because it's the highest social-cost trap. Each entry carries an optional `falseFriendEs` warning rendered as a "OJO: …" lightbulb chip in `AnswerFeedbackView` AFTER the canonical reveal — disambiguation lands at the moment of recall, not as a preemptive hint. Copy is pure Spanish (no English glosses in parentheses). Additive nullable column (migration 0004); `schemaVersion` stays at 3.
  - **L1-pattern naming**: the over-regularization `feedbackHint` now names the transfer pattern explicitly — "Casi — 'goed' es el error típico **de hispanohablantes**, pero 'go' es irregular. La forma correcta es **went**." — so the learner understands WHY they wrote `goed`.
  - **Distinct summary buttons**: "Empezar otra lección" on the lesson summary now commits straight to a new lesson in the same mode/level instead of detouring through Home. "Volver al inicio" keeps the original exit path.
  - See [specs/008-mute-tokens-falsefriends/](specs/008-mute-tokens-falsefriends/).
- **v1.8.0 — Persistence, prosody, tokens, distractor hygiene (F007, 4 locked items)** —
  - **Persistence**: in-flight lesson state is now atomically persisted to `~/Library/Application Support/GramartEnglish/lesson-state.json`. Cmd+Q mid-lesson and the next launch lands you back on the same question instead of losing ~15 min of progress.
  - **Prosody**: every speaker affordance ships a "🐢 lento" companion button (shortcut `D`). Slow rate ≈ 0.35, normal stays at 0.42. Verb-intro card additionally plays the *example sentence* at both speeds, not just the verb.
  - **Design tokens**: new `DesignTokens.swift` exports `Spacing`, `Radius`, `Tint`, `Semantic` (success/warning/error). `LessonSummaryView` and `WritingLessonView` drop the hardcoded 80pt / 44pt fonts in favour of Dynamic-Type-respecting `.largeTitle` with `minimumScaleFactor(0.5)`. Summary emojis become SF Symbols. Site-wide token propagation deferred to v1.9.
  - **Distractor hygiene**: `conjugate_pick_form` no longer surfaces over-regularized forms (`goed`, `runed`, `eated`) as visible options — the wrong spelling was teaching the error on every reading. The pattern is still recognised server-side and surfaces as `AnswerResult.feedbackHint` ("Casi — 'goed' es el error típico, pero 'go' es irregular. La forma correcta es **went**.") when the learner commits to it in a write mode.
  - See [specs/007-persistence-prosody-tokens/](specs/007-persistence-prosody-tokens/) and the evaluator personas in [specs/team-personas.md](specs/team-personas.md).
- **v1.7.0 — "Conoce el verbo" micro-card (F006 US1)** — before the first `conjugate_pick_form` question for each verb you've never seen on this Mac, a one-screen scaffolding card surfaces the Spanish infinitive, English base (with audio), and one bilingual example. CTA "Listo, vamos" + Esc dismiss and mark the verb seen — never auto-shown again. New endpoint `GET /v1/verbs/{base}/intro`; persistence is local-only via `UserDefaults` under `gramart.verbIntro.seen`. No schema delta. See [specs/006-verb-intro-card/](specs/006-verb-intro-card/).
- **v1.6.0 — Verb conjugation (F004 US1)** — `conjugate_pick_form` ships. Prompt: "Pasado simple de **<spanish_infinitive>**". 60 hand-curated verbs (40 A2 + 20 B1, ~50% irregular) drive a 4-option MCQ whose distractors target real L2 mistakes: over-regularized form (`goed`), base form (`go`), past participle (`gone`), and a random same-level past form as filler. Mastery is per `(word, conjugate_pick_form)` on the existing axis; `schemaVersion` stays at 3. See [specs/004-verb-conjugation/](specs/004-verb-conjugation/).
- **v1.5.3** — hygiene patch: README freshness, two `tsc --noEmit` landmines fixed (`lessonService` missing `outcome`, `placement` `httpErrors` undefined), `CLAUDE.md` pointer updated.
- **v1.5.0–v1.5.2** — Write modes (F003): `write_pick_word` + `write_type_word` shipped; per-mode mastery now spans read + listen + write surfaces.
- **v1.4 — Adaptive Placement (F005)** — the placement test no longer asks 24 fixed questions across all 6 levels. Instead it adapts: an optional self-report screen anchors your starting level ("Nunca / Un poco / Bastante"), then the test ramps difficulty up or down based on your answers, finishing in 12–30 items. A user who can't read past A1 now lands at A1 instead of being randomly classified as C1. The Settings level override is unchanged and continues to constrain lesson selection end-to-end — pinned by a regression test. See [specs/005-adaptive-placement/](specs/005-adaptive-placement/).

## Active feature

Active feature: `011-polish-pedagogy-round` (v1.12.0 shipped). Most recent design artifacts live under [specs/011-polish-pedagogy-round/](specs/011-polish-pedagogy-round/); prior releases under [specs/010-design-system-completion/](specs/010-design-system-completion/), [specs/009-falsefriend-bias-darkmode-assets/](specs/009-falsefriend-bias-darkmode-assets/), [specs/008-mute-tokens-falsefriends/](specs/008-mute-tokens-falsefriends/), [specs/007-persistence-prosody-tokens/](specs/007-persistence-prosody-tokens/), [specs/006-verb-intro-card/](specs/006-verb-intro-card/), [specs/004-verb-conjugation/](specs/004-verb-conjugation/), [specs/005-adaptive-placement/](specs/005-adaptive-placement/) and [specs/003-writing-modes/](specs/003-writing-modes/).

The MVP foundation (still authoritative for unchanged areas) is documented under [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/), with listening modes in [specs/002-listening-modes/](specs/002-listening-modes/).

## Lesson modes

Feature 002 introduces four lesson modes, each tracked as an **independent** mastery axis. Mastering "weather" by reading does NOT mark it mastered by ear — they're separate skills.

| Mode | Icon | What you do | Status |
|---|---|---|---|
| `read_pick_meaning` | 📖 | See the English word in context, pick the Spanish meaning | Shipped (F001) |
| `listen_pick_word` | 👂 | Hear audio, pick the English word from 4 options | Shipped (F002) |
| `listen_pick_meaning` | 👂 | Hear audio, pick the Spanish meaning from 4 options | Shipped (F002) |
| `listen_type` | 🎧 | Hear audio, type the word (typos within Levenshtein ≤ 1 accepted) | Shipped (F002) |
| `write_pick_word` | ✏️ | See the Spanish meaning, pick the English word from 4 options | Shipped (F003) |
| `write_type_word` | ✏️ | See the Spanish meaning, type the English word (Levenshtein ≤ 1 + hint button) | Shipped (F003) |
| `write_fill_gaps` | ✏️ | See Spanish + masked English (e.g. `w__th_r`), type the missing letters | Shipped (v1.5.0) |
| `conjugate_pick_form` | 🔁 | See "Pasado simple de **<es>**", pick the English past form from 4 options. v1.6.0 ships simple past at A2 + B1, 60-verb corpus. | Shipped (v1.6.0 — F004 US1) |

Per-mode mastery is surfaced in three places: the Home cards (pending counts + "Recomendado para ti" tag), the post-lesson summary (per-mode badge strip), and the **Mis palabras** screen.

**Read vs. Write modes** train the same vocabulary in opposite directions: read modes test recognition (you see English, prove you know its meaning), write modes test active recall (you see Spanish, prove you can produce the English). A word can be mastered in `read_pick_meaning` and still pending in `write_type_word` — that's the "I recognize but can't produce" gap that productive practice closes.

## Repository layout

```
.specify/         Spec-kit configuration, memory, templates
app/              SwiftUI macOS app (SwiftPM)
  GramartEnglish/ Executable target
  Packages/       Local Swift packages
    LessonKit/      Pure-Swift lesson state machine
    BackendClient/  Typed HTTP client
backend/          Embedded Node.js + TypeScript backend
data/cefr/        Curated vocabulary corpus (CEFR-leveled)
scripts/          Build + tooling
specs/            Feature design artifacts (spec-driven)
```

## Tooling

- macOS 14 (Sonoma) or later, Apple Silicon (M1+), 16 GB RAM
- Xcode 15.4+ (or Xcode that opens SwiftPM `Package.swift`)
- Node.js 20 LTS (NOT odd-numbered "Current" releases — those break native modules)
- pnpm 9.x (npm and yarn are blocked by a `preinstall` script)
- Ollama with `nomic-embed-text` and a chat model (e.g. `qwen2.5:7b` or `llama3.1:8b-instruct-q4_K_M`)

Quick setup:

```bash
# Node 20 LTS
brew install mise && mise use --global node@20

# pnpm 9 via Corepack
corepack enable
corepack prepare pnpm@9.12.0 --activate

# Ollama models
brew install ollama
ollama serve &
ollama pull nomic-embed-text
ollama pull qwen2.5:7b   # or your preferred chat model
```

## Run

```bash
# Terminal 1 — backend
cd backend
pnpm install
GRAMART_CHAT_MODEL=qwen2.5:7b pnpm run dev
# Backend prints a single handshake line: {"port":N,"pid":N,"version":"x.y.z"}

# Terminal 2 — app
cd app/GramartEnglish
GRAMART_BACKEND_URL=http://127.0.0.1:<PORT> swift run
```

First launch flow: Welcome → Placement test (~12 questions) → estimated level → Home → first lesson → score.

## Test

```bash
cd backend && pnpm test                              # backend (vitest)
cd app/Packages/LessonKit && swift test              # state machine
cd app/Packages/BackendClient && swift test          # HTTP client
cd app/GramartEnglish && swift test                  # view models
```

## Spec-driven workflow

When evolving the project, use the slash commands provided by spec-kit:

1. `/speckit-constitution` — amend project rules (rare)
2. `/speckit-specify` — describe a new feature in natural language
3. `/speckit-clarify` — resolve ambiguities (optional)
4. `/speckit-plan` — produce the implementation plan
5. `/speckit-tasks` — generate the dependency-ordered task list
6. `/speckit-analyze` — cross-check spec, plan, tasks (optional)
7. `/speckit-implement` — execute the tasks

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full developer workflow.

## License & sources

- Vocabulary corpus assembled from openly licensed sources (CEFR-J Wordlist CC BY-SA 4.0, English Vocabulary Profile, Tatoeba CC BY 2.0 FR). Definitions and examples are author-written or paraphrased. See [data/cefr/README.md](data/cefr/README.md) for provenance per source.
