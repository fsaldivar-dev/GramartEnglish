# Accessibility Audit — Feature 002 Listening Modes

**Date**: 2026-05-14
**Scope**: `ModeCard`, `ListeningLessonView`, `TypedAnswerInputView`, `AnswerFeedbackView` (mode-aware reveal), `MyWordsView`.

This audit complements Feature 001's. It covers only the surfaces F002 introduced or materially changed.

---

## 1. `ModeCard` (Home grid, 4 shipped + 2 coming-soon)

| Concern | Status | Notes |
|---|---|---|
| VoiceOver label | ✅ | `accessibilityLabel` combines title + subtitle + state ("Recomendado para ti" or "Próximamente — no disponible") + "N palabras por dominar". |
| Hit target ≥ 44 pt | ✅ | Card min-height 150 pt; entire surface is tappable via `contentShape` implied by `Button`. |
| Keyboard activation | ✅ | Standard SwiftUI `Button` — Space/Return activates when focused. |
| Disabled state announced | ✅ | `comingSoon` and `!isEnabled` both call `.disabled(true)`; VoiceOver appends "dimmed". The "Próximamente" pill is also rendered. |
| Tap on disabled is inert | ✅ | Action gated by `if isEnabled && !comingSoon`. Covered by `ModeCardComingSoonTests.testDefaultComingSoonActionIsNoOp`. |
| Recommended tag visible w/o color | ✅ | Tag has text "Recomendado para ti" + border, not color alone. |
| Dynamic Type | ✅ | All text uses semantic fonts (`.title3`, `.callout`, `.caption2`); icons use `Image(systemName:)` which scales. |
| Reduced motion | ✅ | No animations on the card. |
| Color contrast | ⚠️ | Tint-color pill on subtle background — borderline. Verify against system dark mode. **Action**: snapshot in System Settings → Display → Increase contrast and confirm. |
| Tooltips on hover | ✅ | `.help(...)` reveals "Estará disponible en una próxima versión" for coming-soon. |

---

## 2. `ListeningLessonView` (3 listening modes)

| Concern | Status | Notes |
|---|---|---|
| Audio plays on appear | ✅ | `.onAppear { SpeechService.shared.speakEnglish(question.word) }`. FR-006. |
| Audio re-plays on question change | ✅ | `.onChange(of: question.id) { ... }`. |
| Manual repeat | ✅ | Big speaker button + `S` keyboard shortcut. |
| Speaker button VoiceOver | ✅ | Label "Reproducir audio en inglés", hint "Presiona S para repetir el audio". |
| Skip path | ✅ | "No lo sé" button with `0` shortcut. |
| Options keyboard nav | ✅ | Inherits `OptionCard` 1-4 shortcuts from F001. |
| Caption track for hearing-impaired users | ❌ | **Known limitation**: there is no on-screen text caption of what was spoken. Mitigation: the user can press `S` to repeat. Future work: render the canonical word visually after a configurable delay (e.g., 5 s of silence) for users who have not enabled VoiceOver but cannot hear. Tracked as accessibility debt. |
| `prefersCrossFadeTransitions` (reduced motion) | ✅ | SwiftUI default transitions; nothing animated explicitly. |
| Voice gracefully degrades | ✅ | `SpeechService.preferredEnglishVoice` falls back through 3 tiers (premium → enhanced → any en-US → any en). |

**Caption-track gap is the main known a11y issue for F002 and is documented for F003 follow-up.**

---

## 3. `TypedAnswerInputView` (listen_type)

| Concern | Status | Notes |
|---|---|---|
| Focus on appear | ✅ | `@FocusState` set to true in `.onAppear`. |
| Focus moves with question | ✅ | `.onChange(of: questionId)` re-focuses + clears field. |
| Submit on Return | ✅ | `.onSubmit(submit)`. |
| Empty submit routes to skip | ✅ | Covered by `ListeningLessonViewModelTests.testEmptyTypedAnswerFallsThroughToSkip` and unit-tested in `submit()`. |
| Autocorrect off | ✅ | `.autocorrectionDisabled(true)`. |
| Monospaced font | ✅ | Distinguishes l vs 1, O vs 0. |
| Hint button accessible | ✅ | "Pista" label + hint "Revela una letra más de la palabra"; disabled when `hintChars >= canonical.count`. `H` keyboard shortcut. |
| Hint never auto-reveals | ✅ | User-initiated only. |
| Skip "No lo sé" | ✅ | Same `0` shortcut as option modes for muscle-memory consistency. |
| Submit button disabled when empty | ✅ | Reduces accidental empty submissions; also helps VoiceOver users by reflecting the actual valid state. |

---

## 4. `AnswerFeedbackView` (mode-aware reveal)

| Concern | Status | Notes |
|---|---|---|
| Auto-speak canonical on reveal | ✅ | Only for `mode.isListening`, with 250 ms debounce so the layout settles. FR-008 / FR-012. |
| Typo echo struck through | ✅ | Strikethrough is decorative; `accessibilityLabel` says "Lo que escribiste: <typo>, tachado". |
| Option list hidden in typed mode | ✅ | `if !mode.isTyped { AnswerRow… }` — no empty `options` array rendered. |
| Correct/incorrect badge has icon + text | ✅ | Not color-alone (FR-011). |
| Examples sheet keyboard shortcut | ✅ | `⌘E` opens examples. |

---

## 5. `MyWordsView` (new T056 screen)

| Concern | Status | Notes |
|---|---|---|
| Sheet dismissible | ✅ | `xmark.circle` button + `Escape` (`keyboardShortcut(.cancelAction)`). |
| Each row VoiceOver-grouped | ✅ | `accessibilityElement(children: .combine)` + label "Leer: 12 palabras dominadas". |
| Emoji badge not load-bearing | ✅ | Mode name + count carry the meaning; emoji is decorative redundancy. |
| Scrollable on small windows | ✅ | Top-level `ScrollView`. |

---

## Manual QA checklist (run before merging F002)

- [ ] Turn on VoiceOver (`⌘F5`) and tab through Home → all 6 cards are reachable, focus order is left-to-right top-to-bottom.
- [ ] Press Space on a coming-soon card → nothing happens, no audio feedback for activation.
- [ ] Start a listening lesson → audio plays automatically; press `S` to repeat; press a number key to answer.
- [ ] Start a listen_type lesson → text field is focused; press `H` twice → 2 letters revealed with bullets for the rest; type a word with one typo → accepted; reveal screen shows typo struck through.
- [ ] Settings → Accessibility → Display → Increase contrast → re-check ModeCard borders are visible.
- [ ] Resize the window to ~480 pt wide → mode grid still readable, no truncation.

---

## Future work (post-F002)

1. **Caption track for listening modes** — render the canonical word visually after a 5 s delay if the user has not answered. For hearing-impaired users this turns the listening modes back into a reading exercise rather than locking them out.
2. **Adjustable TTS rate** in Settings — some learners want slower playback. The `SpeechService.speakEnglish(_:rate:)` already accepts a rate parameter; expose it in the UI.
3. **High-contrast asset variants** for the Recomendado pill and ModeCard borders.
