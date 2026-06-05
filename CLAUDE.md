<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:

- Active feature: `009-falsefriend-bias-darkmode-assets` (v1.10.0 — Dark Mode semantic colors via asset catalog, A1+B1 false-friend belt v2, +15% selection bias on non-mastered belt words, per-question muted-state indicator on every SpeakButton)
- Plan: [specs/009-falsefriend-bias-darkmode-assets/plan.md](specs/009-falsefriend-bias-darkmode-assets/plan.md)
- Spec: [specs/009-falsefriend-bias-darkmode-assets/spec.md](specs/009-falsefriend-bias-darkmode-assets/spec.md)
- Data model delta: [specs/009-falsefriend-bias-darkmode-assets/data-model.md](specs/009-falsefriend-bias-darkmode-assets/data-model.md)
- Research: [specs/009-falsefriend-bias-darkmode-assets/research.md](specs/009-falsefriend-bias-darkmode-assets/research.md)
- F008 (shipped, mute toggle + tokens + false-friend belt v1): [specs/008-mute-tokens-falsefriends/](specs/008-mute-tokens-falsefriends/)
- F007 (shipped, persistence + tokens + prosody): [specs/007-persistence-prosody-tokens/](specs/007-persistence-prosody-tokens/)
- Evaluator personas: [specs/team-personas.md](specs/team-personas.md)
- F006 (shipped, verb intro card): [specs/006-verb-intro-card/](specs/006-verb-intro-card/)
- F004 (shipped, conjugate_pick_form): [specs/004-verb-conjugation/](specs/004-verb-conjugation/)
- F005 (shipped, adaptive placement): [specs/005-adaptive-placement/](specs/005-adaptive-placement/)
- F003 (shipped, write modes): [specs/003-writing-modes/](specs/003-writing-modes/)
- F002 (shipped, listening + per-mode mastery): [specs/002-listening-modes/](specs/002-listening-modes/)
- MVP foundation (still authoritative for unchanged areas): [specs/001-vocabulary-lesson-mvp/](specs/001-vocabulary-lesson-mvp/)
- Constitution: [.specify/memory/constitution.md](.specify/memory/constitution.md)

**Mastery is per-(word, mode)** as of Feature 002. A word can be mastered in `read_pick_meaning` and still be "to-review" in `listen_pick_word`, `write_type_word`, or `conjugate_pick_form`. F003 added write modes (Spanish prompt → English answer); F005 made placement adaptive; F004 v1.6.0 added `conjugate_pick_form` (Spanish verb infinitive → English past form, simple_past only, A2+B1, 60 verbs). F006 v1.7.0 added a per-Mac, per-verb "Conoce el verbo" pre-conjugation micro-card. F007 v1.8.0 added: lesson-state persistence to `~/Library/Application Support/GramartEnglish/lesson-state.json` (survives Cmd+Q), `SpeechRate.normal/.slow` prosody buttons, `DesignTokens.swift` (Spacing/Radius/Tint/Semantic), and a distractor-hygiene fix that removes `goed`/`runed` from `conjugate_pick_form` options and surfaces them as an `AnswerResult.feedbackHint` instead. F008 v1.9.0 added: a mute toggle in every lesson chrome (`⌘M` shortcut, bound to `SpeechService.shared.isMuted`; bare `M` was patched out post-QA to avoid collision with typed-answer input), full propagation of design tokens through `Sources/Features/` (lint test in `DesignTokenContractTests`), an optional Spanish false-friend warning (`falseFriendEs?: String`) surfaced in `AnswerFeedbackView` for 10 belt words across A2 + B1 (pure Spanish copy, rendered as a `lightbulb.fill` chip), and distinct `onStartAnother`/`onBackHome` callbacks on `LessonSummaryView` so "Empezar otra" commits straight to a new lesson. F009 v1.10.0 added: `Semantic.success/warning/error` resolve through an `Assets.xcassets` colorset (light + dark variants, WCAG AA on macOS window background) with an SPM-build fallback that synthesises a dynamic NSColor on `ColorScheme`, 6 new false-friend belt entries (A1: `large`/`rope`/`once`/`soap`; B1: `constipated`/`molest`), a `FALSE_FRIEND_BIAS_FACTOR = 1.15` (Efraimidis-Spirakis weighted shuffle) that lifts non-mastered belt words +15 % during `selectLessonWords`, and a per-question muted-state indicator on every `SpeakButton` (icon swaps to `speaker.slash.fill`, a11y label appends "(audio silenciado)"). `schemaVersion` stays at 3.
<!-- SPECKIT END -->
