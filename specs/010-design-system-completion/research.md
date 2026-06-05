# F010 — Research notes (v1.11.0)

## Token rounding policy

Mariana's rule, ratified in this cycle: when a raw literal sits
between scale steps, **round to the lower step**. The two `14`
literals in `ModeCard.swift` were the test case — `Radius.md` (12)
won over `Radius.lg` (16). Rationale: chip rhythm at small sizes is
more sensitive to over-rounding than to under-rounding; the F007
visual hierarchy was built around the lower-step bias.

For tint opacities, the closest token wins (0.15 → `Tint.soft` = 0.12
beats `Tint.medium` = 0.18 by Δ 0.03 < 0.03).

## Why no `Radius.xl`

The audit found zero literals in the 18-20pt range; `Radius.lg` (16)
is the current ceiling and the catalog stays at three steps. Adding
a fourth would create a "what do we use this for?" ambiguity Mariana
specifically warned against in v1.8.

## Dark warm-tune contrast verification

Calculated WCAG 2.1 relative luminance against `#1E1E1E` (Dark Aqua
window content; L ≈ 0.0118):

- `#F5C242` (warning) → L ≈ 0.583 → ratio (0.633 / 0.0618) ≈ **10.24:1**
- `#EF5B5B` (error)   → L ≈ 0.266 → ratio (0.316 / 0.0618) ≈ **5.11:1**

Both clear AA (4.5:1). The error ratio drops from the v1.10
`#F87171` value (~5.4:1) but remains compliant; the warmer coral
trades a sliver of contrast for the latina-warm palette feel Mariana
specified.

## Lucía's pedagogical rationale

- `embarrassed` / `embarazada` is the single most-cited Spanish-English
  false-friend in the literature. The v1.9 copy was correct but
  clinical ("esperando un bebé"); Lucía's refined copy names the
  social cost ("el más peligroso socialmente") so the warning lands
  emotionally as well as semantically.
- `record` vs `recordar` was overdue at A2 — `record` is high-frequency
  (CEFR A2 verb list) and the trap is symmetric (Spanish speakers say
  "record me to call" when they mean "remind me").
- `attend` / `atender` and `discuss` / `discutir` are the canonical
  B1 office-register traps. Lucía's locked copy emphasizes the action
  (attend = asistir a un evento) and the register (discuss is not
  combative, argue is).

## Resume CTA design (Priya)

Priya's P1: the existing F007 resume banner in `LessonFlowView`
only fires when the lesson reopens with a `resumeId`. The new path
covers the case where a user (a) abandons lesson A, (b) starts and
completes lesson B, (c) hits the summary screen. Without the
"Continuar lección anterior" card, A silently rots until the user
returns to Home and notices the resume tile.

The card is shown OVER the existing CTAs because Priya's user
research (n=5, Spanish-language LATAM cohort) consistently showed
learners scroll past the missed-words list and stop at the first
prominent button. Putting the resume CTA above the "Empezar otra
lección" primary preserves the click-through hierarchy.

See `specs/team-personas.md` for the full panel.
