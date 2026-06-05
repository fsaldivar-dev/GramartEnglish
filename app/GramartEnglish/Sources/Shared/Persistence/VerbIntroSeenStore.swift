import Foundation

/// F006 (v1.7.0). Per-Mac persistence for "has the learner already seen the
/// pre-conjugation intro card for this verb?".
///
/// Storage: a Set<String> of verb bases, persisted in UserDefaults under
/// `gramart.verbIntro.seen`. We accept the small read/write overhead of
/// reflating from `[String]` on every call because:
///   - the set rarely exceeds ~70 entries (verb corpus size),
///   - the call site (`hasSeen` once per question, `markSeen` once per
///     dismissal) is decisively not hot,
///   - keeping no in-memory cache means tests with a fresh UserDefaults suite
///     see the new state immediately, without a singleton-busting reset hook.
///
/// We expose `init(defaults:)` so unit tests can pass an isolated
/// `UserDefaults(suiteName:)`. The `shared` instance binds to `.standard` and
/// is the production singleton.
public final class VerbIntroSeenStore {

    public static let shared = VerbIntroSeenStore()

    static let defaultsKey = "gramart.verbIntro.seen"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns true if the learner has already dismissed the intro for this
    /// verb base on this Mac.
    public func hasSeen(_ base: String) -> Bool {
        load().contains(base)
    }

    /// Records the verb base as seen. Idempotent. Persists synchronously so a
    /// follow-up `hasSeen` (in the same render pass) reflects the change.
    public func markSeen(_ base: String) {
        var current = load()
        current.insert(base)
        save(current)
    }

    /// Test affordance and future reset-me hook. Production code does not call
    /// this — there is no in-app surface for "forget what I've seen".
    public func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    // MARK: - Private

    private func load() -> Set<String> {
        guard let stored = defaults.array(forKey: Self.defaultsKey) as? [String] else { return [] }
        return Set(stored)
    }

    private func save(_ value: Set<String>) {
        // Sort for deterministic on-disk shape — helps diffing UserDefaults
        // plists when investigating behavior across launches.
        defaults.set(Array(value).sorted(), forKey: Self.defaultsKey)
    }
}
