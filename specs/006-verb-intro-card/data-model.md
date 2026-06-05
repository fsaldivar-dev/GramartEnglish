# F006 Data Model Delta

## No schema delta

`schemaVersion` stays at **3**. No SQL migration is needed.

## Server DTO — `VerbIntro`

```ts
interface VerbIntro {
  base: string;        // English infinitive ("go")
  es: string;          // Spanish infinitive ("ir")
  exampleEs: string;   // Spanish sentence with slot filled
                       // (server replaces `___` with the past form)
  exampleEn: string;   // English sentence in past simple
  audioBase: string;   // filename to feed the audio button
}
```

Derived from `VerbRow` via `VerbRepository.lookupByBase(base)`:

| VerbIntro field | VerbRow source |
|---|---|
| base | base |
| es | es |
| exampleEs | example_es (slot `___` preserved — see route comment) |
| exampleEn | example_en (already conjugated) |
| audioBase | audio_base |

The slot-fill is server-side so the client gets a "ready to read" sentence.
The Conjugation question still uses the unfilled `exampleEs` (with `___`) —
the two surfaces are intentionally different: the intro shows the answer
in context to ground meaning; the question hides it.

## Client state — `verbIntroSeen`

```swift
// UserDefaults key: "gramart.verbIntro.seen"
// Storage: [String] (Codable array; Set<String> at runtime)
```

API:
```swift
final class VerbIntroSeenStore {
    static let shared: VerbIntroSeenStore
    func hasSeen(_ base: String) -> Bool
    func markSeen(_ base: String)
    func reset()   // test-only / future reset-me hook
}
```

Mutation timing: `markSeen` is called from the dismissal callback BEFORE
`pendingIntro` is cleared, so a race-free re-render never re-shows the card.

## ViewModel state delta

```swift
@Published private(set) var pendingIntro: VerbIntro?
```

Gating predicate (pseudocode):
```swift
func nextOrIntro(_ question: LessonQuestion) async {
  guard mode == .conjugatePickForm,
        let base = question.verbBase,
        !VerbIntroSeenStore.shared.hasSeen(base) else {
    phase = .answering(state)
    return
  }
  let intro = try? await client.fetchVerbIntro(base: base)
  if let intro { pendingIntro = intro }
  else { phase = .answering(state) } // 404 → degrade gracefully
}
```
