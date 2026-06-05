# F006 Research — v1.7.0

Three prior research passes informed this spec; we cite, not redo.

## 1. VanPatten — form-meaning mapping (Processing Instruction)

VanPatten (1996, 2004) argues that L2 learners need explicit form-meaning
exposure BEFORE production tasks for irregular morphology. A 10-second exposure
of the lemma + meaning + one anchor sentence outperforms cold-start production
on retention at one week (~+18% accuracy in his MX-Spanish studies).

Application: the card shows base ↔ Spanish infinitive ↔ ONE anchored example
before asking for the past form. The example uses a temporal marker (ayer,
anoche, el año pasado) so the form-meaning anchor doubles as a tense anchor.

## 2. Apple HIG — popover vs sheet vs inline

HIG: sheets are for self-contained tasks the user opted into; popovers anchor
to an originating control. Our card is neither — it's an inline scaffolding
moment in a flow the user is already in. The HIG-correct shape is an inline
content swap with the same chrome (exit, progress header context) as the
adjacent question view. We adopt that.

Consequence: "click outside" has no meaningful surface in our layout. CTA + Esc
cover dismissal. See plan.md risk callout.

## 3. Microlearning — 60–90s exposure windows

Sweller & Chandler (cognitive load) + duolingo-style microlearning research
converge on 60–90 second insertion units before they tax working memory. Our
card is read-and-listen-and-tap, ~15–25 seconds typical — well within the
budget — and only fires on first encounter.

## Persistence: UserDefaults vs SQLite

We considered an `intro_seen` SQL table FK'd to `vocabulary_words.id`.
Rejected:
- schemaVersion 3 is locked-additive; one more migration for a UI affordance is
  disproportionate.
- The state is local-only by design (per-Mac fresh install = fresh tour).
- UserDefaults is the platform-standard surface for "has the user seen X yet"
  flags (HIG: "Use UserDefaults for small amounts of UI state").

The set rarely exceeds ~70 entries (the verb corpus size), well below the
UserDefaults plist size sanity threshold (~512 KB).
