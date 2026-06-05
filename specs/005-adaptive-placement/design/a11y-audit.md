# F005 Accessibility Audit

**Status**: Final — completed during Phase 5 polish.

Covers only what F005 adds. F001/F002/F003 audits remain authoritative for
unchanged screens (Home, Lesson modes, Settings, MyWords).

## Screens audited

### 1. `PlacementSelfReportView` (NEW)

| Concern | Implementation | Status |
|---|---|---|
| VoiceOver reads a header | `accessibilityAddTraits(.isHeader)` on the prompt text | ✅ |
| Each anchor button has a distinct VoiceOver label | `accessibilityLabel("Opción N: <label>. <subtitle>")` | ✅ |
| Keyboard shortcuts work without modifiers | `keyboardShortcut("1"..."3")`, `"0"` for skip | ✅ |
| Tap target ≥ 44 pt | `minHeight: 60` on each anchor; skip button has 8 pt vertical padding (use VoiceOver / kbd to activate instead of pointer-only) | ⚠ Skip button is small; mitigated by keyboard `0` |
| The whole screen exposes a single VO summary | `.accessibilityElement(children: .contain)` + `accessibilityLabel("Pregunta inicial: ¿Has estudiado inglés antes?")` | ✅ |
| Color is not the only cue | Index number rendered in monospaced font; subtitle conveys the CEFR range too | ✅ |

### 2. `PlacementQuestionView` (UNCHANGED — referenced)

No behavioural change. The progress label "Pregunta X de Y" now shows
`X de hasta 30` semantics (max is the worst case). VoiceOver continues to
read it on every question change because of the existing `.onChange(of:
question.id)` re-announcement path. F001 audit applies.

### 3. "Calibrando…" loading badge (added to `placementBody`)

The `.loading` / `.submitting` branches show a `ProgressView` plus a
secondary-foreground text. Because the badge is purely transient (typically
< 200 ms between questions on local backend), it does NOT need its own
accessibility announcement — VoiceOver users hear it incidentally if they're
already focused on the loading region. The next `.question(...)` transition
re-focuses on the new question id, mirroring F001 behaviour.

## What we did NOT audit

- **Result screen** — unchanged in F005; F001 audit applies.
- **Settings level override** — unchanged in F005; F003 audit applies.

## Future work

- A dedicated "Repetir test" button on the result screen would let mobility-
  impaired users re-run placement without going Home → Welcome. Deferred.
- A subtle "items remaining" announcement at item 12 ("Casi listo…") would
  improve perceived progress. Deferred.
