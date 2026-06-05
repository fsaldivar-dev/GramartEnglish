<div align="center">
  <img src=".github/assets/app-icon.png" alt="GramartEnglish app icon" width="160" height="160" />

  # GramartEnglish

  A native macOS app that helps English learners build vocabulary at their own CEFR level (A1–C2), with optional AI-generated example sentences grounded in a curated local corpus via a local LLM (Ollama).

  **Latest release** · [v1.6.0](https://github.com/fsaldivar-dev/GramartEnglish/releases/latest)  ·  **Status**: MVP development. Spec-driven via [spec-kit](https://github.com/github/spec-kit).
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

- **v1.6.0 — Verb conjugation (F004 US1)** — `conjugate_pick_form` ships. Prompt: "Pasado simple de **<spanish_infinitive>**". 60 hand-curated verbs (40 A2 + 20 B1, ~50% irregular) drive a 4-option MCQ whose distractors target real L2 mistakes: over-regularized form (`goed`), base form (`go`), past participle (`gone`), and a random same-level past form as filler. Mastery is per `(word, conjugate_pick_form)` on the existing axis; `schemaVersion` stays at 3. See [specs/004-verb-conjugation/](specs/004-verb-conjugation/).
- **v1.5.3** — hygiene patch: README freshness, two `tsc --noEmit` landmines fixed (`lessonService` missing `outcome`, `placement` `httpErrors` undefined), `CLAUDE.md` pointer updated.
- **v1.5.0–v1.5.2** — Write modes (F003): `write_pick_word` + `write_type_word` shipped; per-mode mastery now spans read + listen + write surfaces.
- **v1.4 — Adaptive Placement (F005)** — the placement test no longer asks 24 fixed questions across all 6 levels. Instead it adapts: an optional self-report screen anchors your starting level ("Nunca / Un poco / Bastante"), then the test ramps difficulty up or down based on your answers, finishing in 12–30 items. A user who can't read past A1 now lands at A1 instead of being randomly classified as C1. The Settings level override is unchanged and continues to constrain lesson selection end-to-end — pinned by a regression test. See [specs/005-adaptive-placement/](specs/005-adaptive-placement/).

## Active feature

Active feature: `004-verb-conjugation` (v1.6.0 shipped). Most recent design artifacts live under [specs/004-verb-conjugation/](specs/004-verb-conjugation/); prior releases under [specs/005-adaptive-placement/](specs/005-adaptive-placement/) and [specs/003-writing-modes/](specs/003-writing-modes/).

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
