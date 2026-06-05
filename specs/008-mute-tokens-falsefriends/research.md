# F008 — Research

Reference: [team-personas.md](../team-personas.md)

## Mute toggle placement (Marisol + Priya)

Marisol: "Audio is part of the lesson but it's also the most-interrupted
affordance — every cafe/library session asks for a one-tap mute. Settings
is two hops too many in flow."

Priya: "M is fine as a bare-key shortcut — it doesn't collide with the
1-4 / 0 option shortcuts. Top-left of the chrome (next to X) keeps both
exit-class affordances together; users learn the cluster once."

## Token sweep scope (Mariana)

v1.8.0 deliberately shipped tokens without a full propagation ("ship the
API first, swap call-sites later"). The remaining 17 `.system(size:)`
literals across 11 files are the v1.9 backlog. Sizes 22–64 all map to one
of `.title3`/`.title`/`.largeTitle` with `minimumScaleFactor` between 0.5
and 0.7. No literal smaller than 22 was found.

cornerRadius migration: 8/12/16 cover ~60% of the literals. The remaining
6/10/14 stay literal — they're tactical (smaller chip radii, button
backgrounds) and don't fit the three-step scale.

## False-friend belt (Lucía)

Source: SLA literature on L1-Spanish → L2-English transfer. The ten belt
words are the ones that appear in every "Spanish false-friends" listicle
AND have CEFR placement at A2 or B1 (i.e. learners in our target band
encounter them naturally). Copy convention: open with "OJO" (Spanish
"heads up") so hispanohablantes recognise the stop-signal pattern.

Why post-answer rendering: presenting the warning BEFORE the answer
would prime the learner toward the correct meaning without testing
retrieval. The pedagogical win is the disambiguation landing AT the
moment the wrong mapping would otherwise rehearse.

## L1-pattern naming in feedbackHint (Lucía)

v1.8.0 shipped: `"Casi — 'goed' es el error típico, pero 'go' es
irregular. La forma correcta es **went**."`. The phrase "error típico"
is too generic — learners don't know WHY they wrote `goed`. Adding "**de
hispanohablantes**" names the L1 pattern (Spanish regular-verb past
`-é/-aste/-ó/-amos` collapses to English `-ed`). The learner can then
generalize: "ah, I was applying the Spanish rule".
