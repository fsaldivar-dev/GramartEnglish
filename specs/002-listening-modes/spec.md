# Feature Specification: Listening Modes

**Feature Branch**: `002-listening-modes`
**Created**: 2026-05-14
**Status**: Clarified — ready for plan
**Depends on**: 001-vocabulary-lesson-mvp (uses corpus, TTS, mastery, lesson flow)

## Clarifications

### Session 2026-05-14

- Q: ¿Cómo se ve el selector de modo en Home? → **A: Cards grandes tipo "elige tu lección de hoy"**. Cada modo (Leer / Escuchar / Escribir / Conjugar) es una card seleccionable con icono, nombre, subtítulo corto y contador de palabras por dominar.
- Q: ¿Los modos se desbloquean progresivamente o están todos disponibles desde el inicio? → **A: Todos visibles desde el primer arranque, sin gating**. Cada card lleva un tag "Recomendado para ti" calculado a partir de la mastery actual (el modo con más palabras pendientes / menos lecciones recientes).
- Q: ¿Auto-play del audio? → **A: Siempre on en modos de listening**. No hay toggle en Settings para esta versión; la inmersión es el objetivo.
- Q: ¿Tolerancia de typos en `listen_type` (y `write_type_word` futuro)? → **A: Levenshtein ≤ 1**. "wether" cuenta como "weather". 2+ caracteres de distancia = incorrecto. La pantalla de feedback muestra lo que el usuario escribió y la palabra correcta lado a lado.
- Q: ¿La mastery por modo se muestra al usuario? → **A: Sí, con badge por modo**. Cada palabra "dominada" muestra un icono pequeño por cada modo en el que está dominada (libro 📖 / oído 👂 / lápiz ✏️ / verbo 🔁). El total "Dominadas" en Home se desglosa por modo en un tooltip.

## Why this feature

The MVP exercises **reading**. A learner who reads English fine often can't follow the same words when spoken. This feature adds **listening** as a lesson mode, reusing the same 300-word corpus and TTS already in place.

## User Scenarios *(mandatory)*

### US1 — Listen and pick the English word (Priority: P1)

Student opens Home, chooses "Modo: Escuchar". A lesson starts where each question plays an English word (audio only) and shows 4 written English options. The student picks the option that matches what they heard.

**Why P1**: Smallest engineering footprint (reuses TTS, multi-choice, corpus, mastery). Closes the most common gap: "I can read it but not understand it spoken."

**Independent Test**: Open app → pick "Escuchar" → 10 audio-only questions → 4 English options → score at end.

**Acceptance**:
1. **Given** the student is on Home, **When** picks "Escuchar" and starts a lesson, **Then** sees a 🔊 prominent button (not the written word) and 4 English-word option cards.
2. **Given** an audio plays automatically on appear, **When** the student presses `S` or clicks 🔊, **Then** the same audio plays again.
3. **Given** the student picks an option, **When** correct/incorrect, **Then** the written English word is revealed plus its Spanish meaning + audio of the word again.

### US2 — Listen and pick the Spanish meaning (Priority: P2)

Same as US1 but options are Spanish translations. Tests "from-sound to meaning" directly.

**Independent Test**: Pick "Escuchar (significado)" → audio plays → pick Spanish meaning → score.

**Acceptance**:
1. Audio plays on appear; 4 Spanish options shown.
2. Same skip-and-feedback flow as the existing read mode.

### US3 — Listen and type (Priority: P3)

Audio plays; user types what they heard. Spelling tolerated within Levenshtein distance 1 (e.g., "wether" still counted as correct, with a kind note).

**Independent Test**: Pick "Escuchar y escribir" → audio plays → text field → user types → graded.

**Acceptance**:
1. Audio plays; no written prompt anywhere on screen.
2. Text field is monospaced, autocorrect off.
3. Submit on `↩`. Tolerates 1-character typo. Reveal shows the correct spelling with the typed version above for comparison.

### Edge Cases

- Audio fails to play (rare, but possible): fall back to showing the word text after 3 s timeout.
- User cannot stand auto-play: a toggle in Settings "Reproducir audio al aparecer" (default on).
- Repeated taps on 🔊 cancel previous playback (already handled in SpeechService).

## Functional Requirements *(mandatory)*

- **FR-001**: System MUST support a `LessonMode` enum with at least: `read_pick_meaning` (current MVP), `listen_pick_word`, `listen_pick_meaning`, `listen_type`.
- **FR-002**: `POST /v1/lessons` MUST accept an optional `mode` field; absent defaults to `read_pick_meaning`.
- **FR-003**: Home MUST replace the single "Empezar nueva lección" CTA with a **card grid** of available modes (Leer / Escuchar / Escribir / Conjugar). Each card shows: icon, mode name, one-line subtitle, and a pending-words counter for that mode. One card carries a "Recomendado para ti" tag at any time — the recommendation is the mode with the highest count of words not-yet-mastered for that mode (ties broken by least-recently-used).
- **FR-004**: Mastery MUST be tracked per `(userId, wordId, mode)` so that mastering a word by reading does not count as mastering it by ear.
- **FR-005**: Word-selection (50/30/20 mix) MUST operate on per-mode mastery, not global mastery.
- **FR-006**: Listening modes MUST auto-play the target audio when each question appears. No user-facing toggle for auto-play in this feature.
- **FR-007**: For `listen_type`, the system MUST accept answers within Levenshtein distance ≤ 1 of the correct spelling (case-insensitive, trimmed). Distance ≥ 2 = incorrect.
- **FR-007a**: When the typed answer is within Levenshtein 1 (not exact match), the reveal MUST show both the user's typed version and the canonical spelling side by side (e.g., "Escribiste: *wether* · Correcto: *weather*") so the user learns the right spelling.
- **FR-008**: Reveal screen MUST always show the correct spelling AND speak it again for reinforcement.
- **FR-009**: Mode selection MUST be persisted per user and recalled on next launch.
- **FR-010**: Per-(word, mode) mastery MUST be surfaced to the user as small mode-icon badges on any "dominada" view. The Home Dominadas counter MUST show a tooltip / detail screen breaking down the total by mode (📖 read · 👂 listen · ✏️ write · 🔁 conjugate).
- **FR-011**: The Home card grid MUST render all 4 modes from day one. Cards for features not yet implemented (Conjugate in this MVP, and Write until F003 ships) MUST appear **visually disabled** with a "Próximamente" tag and a tooltip describing the mode. Tapping a disabled card MUST be a no-op (no lesson starts). This communicates the roadmap without dead-end flows.
- **FR-012**: On reveal, after the user answers (correctly, incorrectly, or skip), the canonical English spelling MUST be auto-spoken once (delay ≥ 200 ms after the reveal animation settles) regardless of which listening sub-mode the lesson is in. This is the "reinforcement" half of FR-008.

## Success Criteria

- **SC-001**: A student completes one 10-question Listening lesson (any sub-mode) in ≤ 4 minutes.
- **SC-002**: For at least 5 test users, the per-mode mastery curve diverges from read-mode (i.e., listening mode reveals different "weak" words than reading mode does).
- **SC-003**: The first audio of each question is heard within ≤ 300 ms of the question appearing.
- **SC-004**: `listen_type` accepts the correct spelling AND ≥ 90% of single-character typos for a curated test set of 20 words.

## Assumptions

- macOS TTS (`AVSpeechSynthesizer`) voice quality is acceptable for A1–C2 vocabulary. If too robotic for advanced words, defer to Feature 005 for higher-quality voice.
- The user has speakers/headphones available. Mute is a system-level setting.
- 300 words × 4 modes = 1,200 possible (word, mode) mastery cells. SQLite handles this trivially.

## Out of scope (for this feature)

- Writing modes (Spanish → English) → Feature 003
- Verb conjugation → Feature 004
- Sentence-level listening (full phrases vs single words) → potential Feature 006
- Recording the user's own pronunciation to compare → not in MVP roadmap

## Shared infrastructure introduced here (reused by Features 003+)

- `LessonMode` enum in `LessonKit` package
- `mode` column on `word_mastery` (composite PK becomes `(userId, wordId, mode)`)
- Backend `POST /v1/lessons` `mode` param
- Mode selector UI on Home
- Text-input answer support (for L3 — building this here saves later work in W3)
- Per-mode mastery selector logic in `wordSelector.ts`

## Migration plan

`0003_lesson_modes.sql`:
- `ALTER TABLE word_mastery ADD COLUMN mode TEXT NOT NULL DEFAULT 'read_pick_meaning'`
- New composite primary key on `(userId, wordId, mode)`
- Set `user.preferredMode` column with default `'read_pick_meaning'`
