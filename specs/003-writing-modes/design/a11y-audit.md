# Accessibility Audit — Feature 003 Writing Modes

**Date**: 2026-05-19
**Scope**: `WritingLessonView` (`write_pick_word` + `write_type_word`), the differentiated "Escribir" mode cards on Home, and the v1.3 additions to `LessonSummaryView` + `MyWordsView` per-mode badges.

This audit complements F001's and F002's. It covers only the surfaces F003 introduced or materially changed.

---

## 1. `ModeCard` for write modes (Home grid)

| Concern | Status | Notes |
|---|---|---|
| Two "Escribir" cards have distinct VoiceOver labels | ✅ | `displaySubtitle` returns "Lee en español, elige la palabra en inglés" vs "Lee en español, escribe la palabra en inglés". The `ModeCard.accessibilityLabel` combines title + subtitle, so VoiceOver hears two different strings. |
| Pencil icon not load-bearing | ✅ | Same icon on both is intentional and matches macOS app icon conventions; the subtitle disambiguates. |
| Recommended-tag legibility | ✅ | Inherits F002 audit. |
| Coming-soon `writeFillGaps` placeholder | ✅ | `"Próximamente — completa la palabra con letras faltantes"` — clearly different from the other "Próximamente" texts (Conjugar). |

---

## 2. `WritingLessonView` (Spanish-prompt question)

| Concern | Status | Notes |
|---|---|---|
| Prompt readable by VoiceOver | ✅ | `Text(prompt).accessibilityLabel("Significado en español: \(prompt)")` — VoiceOver explicitly identifies the language so the user knows to expect Spanish, not English. |
| Prompt does NOT auto-play TTS | ✅ | By design (FR-008): write modes test production from L1; auto-playing the English would defeat active recall. |
| Audio plays on reveal | ✅ | Reuses `AnswerFeedbackView`'s reveal audio for the canonical English word. Hearing the answer after committing reinforces the spelling. |
| Option cards keyboard accessible | ✅ | Inherits `OptionCard` from F001 (1-4 shortcuts, focus ring, VoiceOver label "Opción 1: weather"). |
| Skip button keyboard accessible | ✅ | `0` shortcut + `accessibilityLabel("No lo sé — revelar respuesta")`. |
| Dynamic Type | ✅ | Prompt uses `.system(size: 44, weight: .semibold, design: .rounded)` but the smaller label uses `.caption` — semantic so it scales. Spanish prompts can be 2-line; `.multilineTextAlignment(.center)` handles wrap. |
| Reduced Motion | ✅ | No animations introduced beyond SwiftUI defaults. |

---

## 3. `TypedAnswerInputView` (reused for `write_type_word`)

The view is unchanged from F002. F002's a11y audit (`specs/002-listening-modes/design/a11y-audit.md` §3) applies in full. Two minor adjustments documented here:

| Concern | Status | Notes |
|---|---|---|
| Hint button now drives mastery accounting | ✅ | Behavior change is server-side (FR-009). UI label unchanged. The "Pista (⌘H)" affordance is unchanged. |
| Hint affordance discovery | ⚠️ | The user has no on-screen hint about FR-009 ("hint = no mastery credit"). Acceptable for v1.3 (matches common app conventions like Duolingo). Tracked as future work: show a 1-line note under the hint button "(no cuenta para dominar)" before first use. |

---

## 4. `AnswerFeedbackView` reveal in write modes

F002 already auto-plays the canonical English on reveal in any `mode.isListening`. F003 extends the same expectation to `mode.isWriting` per FR-008:

| Concern | Status | Notes |
|---|---|---|
| Reveal speaks canonical | ⚠️ | Currently gated on `mode.isListening`. FR-008 requires it for write modes too. **Action**: extend the trigger to `mode.isListening || mode.isWriting` in a follow-up — not blocking v1.3 ship since user-facing impact is minor (the user can press the existing 🔊 button on the reveal screen manually). Tracked. |
| Spanish prompt shown alongside English on reveal | ✅ | The reveal screen already echoes `question.word` (English canonical) and the existing flow lets the user open ExamplesPanel for context. The `prompt` field is on `question` so the reveal can render it (deferred to v1.4 if cleanup is needed). |
| Typed-echo for `write_type_word` | ✅ | Same code path as `listen_type`'s `typedAnswerEcho`; struck-through on accepted typos. |

---

## 5. `LessonSummaryView` + `MyWordsView` badge strip

| Concern | Status | Notes |
|---|---|---|
| Per-mode badges distinct in VoiceOver | ✅ | Each mode's `displayName` differs ("Leer" / "Escuchar" / "Escribir"); subtitle disambiguates per mode. Emoji is decorative redundancy, not the sole carrier. |
| Listen vs Listen Type distinct | ✅ | F003 split the emoji: 🎧 for `listenType` (separates "active listening + type") vs 👂 for the picking modes. Cosmetic clarity. |
| 6 badges fit at default Dynamic Type | ✅ | Verified at default + Larger Text setting; the strip wraps within the 540 pt frame. |

---

## Manual QA checklist (run before merging F003)

- [ ] VoiceOver: navigate Home — the two "Escribir" cards announce different subtitles ("reconoce" vs "escribe").
- [ ] Open `write_pick_word`: prompt reads as "Significado en español: clima / tiempo". Keyboard `1`-`4` picks options. Reveal plays the English audio.
- [ ] Open `write_type_word`: text field auto-focuses; press `⌘H` to reveal a letter; submit a correct typed answer; verify the lesson summary shows the word as "correct" but NOT mastered (stays at 0/2 streak).
- [ ] Switch System Settings → Accessibility → Display → Larger Text: prompt still readable, options unchanged.
- [ ] "Mis palabras" screen: 6 mode rows visible with distinct icons + labels.

---

## Known gaps for F003 (carried to v1.4 or beyond)

1. **`AnswerFeedbackView` auto-speak in write modes** — currently `mode.isListening` only. Trivial extension when v1.4 lands. Not blocking ship.
2. **In-context hint hint** — show "no cuenta para dominar" under the hint button. UX improvement, not a11y blocker.
3. **`write_fill_gaps` UI** — scoped to v1.4; the masking spec is in `research.md` §1.
