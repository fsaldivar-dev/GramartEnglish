# Accessibility audit — Vocabulary Lesson MVP

Aligned with Constitution Principle VII (Accessibility). Each row is a manual check; mark with the date of the run and the reviewer initials. Re-run before every release.

## VoiceOver (each interactive element has a meaningful label)

| Screen | Elements | Last verified | By | Status |
|--------|----------|---------------|-----|--------|
| Welcome | "Start placement test" button, "Skip and pick a level manually" link, headline, bullets | — | — | ⏳ |
| Placement question | Word (header role), 4 option cards labelled "Option 1: …", "Skip" | — | — | ⏳ |
| Placement result | Estimated level (header), per-level rows ("Level X: N correct out of M"), primary/secondary buttons | — | — | ⏳ |
| Home | Level badge, stats row (mastered/to-review/lessons), Start/Resume buttons, Last lesson card, gear | — | — | ⏳ |
| Lesson question | Progress header, word (header), 4 option cards, "Exit lesson" close icon | — | — | ⏳ |
| Answer feedback | "Correct" / "Not quite" combined element, 4 answer rows (with correct/your-answer hint), definition card, "See how this word is used" link, Next button | — | — | ⏳ |
| Examples panel | Sheet title (word + level), shimmer loading region, example cards with highlighted target word, attribution, fallback banner (when shown), close button | — | — | ⏳ |
| Lesson summary | Score (label "Score: N out of 10"), tone message, missed-words list, primary/secondary buttons | — | — | ⏳ |
| Settings | Tab labels, segmented level picker, Apply button, Reset destructive button, confirmation dialog, About fields | — | — | ⏳ |
| Ollama offline indicator | Label "AI helper offline. Quiz still works." | — | — | ⏳ |

## Keyboard navigation (every flow completable without a mouse)

- [ ] Welcome → `↩` starts placement; `Tab` reaches skip link.
- [ ] Placement question → keys `1`–`4` choose options; `Esc` not destructive.
- [ ] Placement result → `↩` accepts; `Tab` reaches "Pick a different level".
- [ ] Home → `↩` triggers Resume if present, otherwise Start lesson; `⌘,` opens Settings.
- [ ] Lesson question → keys `1`–`4` answer; exit affordance reachable via `Tab`.
- [ ] Answer feedback → `↩` advances; `⌘E` opens Examples panel; focus returns to Next on close.
- [ ] Examples panel → `Esc` closes; loading state does not trap focus.
- [ ] Lesson summary → `↩` starts another lesson.
- [ ] Settings → `Tab` between tabs and fields; `Esc`/Done dismisses; Reset confirmation reachable.

Document any shortcut in [Shortcuts.md](../../../app/GramartEnglish/Sources/Shared/Accessibility/Shortcuts.md).

## Dynamic Type / Increase Contrast / Reduce Motion

Manual check at System Settings → Accessibility:

- [ ] Default + larger text (Display → Increase / Decrease size or text-size keyboard shortcuts): no clipping in lesson cards, summary, examples panel.
- [ ] Reduce Motion ON: transitions collapse to fades (per `A11yTransition.slideOrFade()`).
- [ ] Increase Contrast ON: focus ring darkens (per `FocusRingModifier`).
- [ ] Reduce Transparency ON: backgrounds remain readable (no over-translucent panels).
- [ ] Color is never the only signal — correct/incorrect badges combine icon + text + color.

## Color & contrast (WCAG AA on the system palette)

- [ ] All text on `.background.secondary` cards passes 4.5:1.
- [ ] Accent color on Light + Dark passes 4.5:1 for body, 3:1 for large text.
- [ ] Fallback banner foreground is readable on its tinted background.

## Audit log

| Date | Reviewer | Build | Notes |
|------|----------|-------|-------|
| YYYY-MM-DD | (initials) | (commit) | First pass scheduled before MVP release |
