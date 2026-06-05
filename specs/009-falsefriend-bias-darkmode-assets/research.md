# F009 — research notes

The v1.9.0 5-panel review (Lucía / Mariana / Marisol / Priya / QA) flagged
the following items as locked-scope for v1.10.0. The four items below
are the unanimous-PR3+ list.

## Panel-by-panel summary

### Lucía (pedagogy + L1 transfer)

> The belt is finally shipping, but the gap is in A1 — `large`/`rope`/
> `once`/`soap` get hit on day 1 of self-study and currently have no
> "OJO" cue. `constipated` and `molest` are the two most socially-costly
> B1 traps — they go in next. And the `success` copy uses `(event)`
> in English parentheses — the rest of the belt is pure Spanish; fix the
> typo.

### Mariana (visual + dark mode)

> `.green`/`.orange`/`.red` against `windowBackgroundColor` in Dark Mode
> all look the same shade — about 2.8:1 contrast. The TODO from v1.8.0
> needs to land. Hex picks (`#0E7C3A` `#4ADE80` `#B45309` `#FBBF24`
> `#B91C1C` `#F87171`) are AA on both backgrounds and avoid the
> oversaturated digital primaries that Apple's HIG warns against for
> educational content.

### Priya (privacy + trust)

> The mute glyph dimming in v1.9.0 is good, but a learner who's used to
> seeing the speaker icon won't read "dimmed" as "muted" — they need the
> slash. Match what `MuteToggleButton` already does. The icon change
> + "(audio silenciado)" suffix is the trust signal.

### Marisol (motor + a11y)

> No new shortcuts asked for. Just make sure `SpeakButton`'s tap behaviour
> stays unchanged — taps still play, mute is auto-fire only (v1.4.1 F3).

### QA

> Bias selection needs a seeded statistical test, not a deterministic one
> — 50-run sample with `seed = run-index` should yield ≥ 80 % of runs
> with at least one false-friend in the first 10 slots.

## Bias-factor sizing

We picked `1.15` (15 %) over alternatives:
- `1.10` is below the noise floor of a 40-word pool — the test would flake.
- `1.25` over-represents the belt in mixed-level review lessons.
- `1.15` lands roughly +1 false-friend per ~7 lessons on a balanced corpus, matching Lucía's "OJO cue once per week of practice" target.

The bias is uncompounded across appearances (mastery erases it once the
word is mastered), so streak distortion is bounded.

## Asset-catalog contrast verification

We compute relative luminance per WCAG 2.1 §1.4.3:
- `srgb_linear(c) = c/12.92 if c ≤ 0.03928 else ((c+0.055)/1.055)^2.4`
- `L = 0.2126*Rl + 0.7152*Gl + 0.0722*Bl`
- `contrast = (Llight + 0.05) / (Ldark + 0.05)`

Both light and dark sets pass at ≥ 4.5:1; see `SemanticColorsTests`.

## Out-of-scope alternatives considered

- **Adaptive bias by user-history** — defer to v1.11+; needs a per-user
  miss-rate column. v1.10 ships a flat constant.
- **In-app dark-mode toggle** — system setting drives appearance; no
  override in v1.10.
