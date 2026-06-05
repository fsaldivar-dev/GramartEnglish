import AVFoundation
import Foundation

/// English accent — locale flavor for the TTS voice.
public enum EnglishAccent: String, CaseIterable, Sendable {
    case usa = "en-US"
    case british = "en-GB"
}

/// F007 (v1.8.0). Named TTS rate presets. We expose two:
///
///   - `.normal` (≈ 0.42 of `AVSpeechUtterance.rate`): the historical
///     vocabulary-practice rate. Roughly 85% of Apple's default, matching
///     Translate's per-word audio cadence.
///   - `.slow` (≈ 0.35): the "tortuga" rate Lucía asked for so A1 learners
///     can self-correct pronunciation. Concretely, this is
///     `AVSpeechUtteranceMinimumSpeechRate * 0.4 +
///      AVSpeechUtteranceDefaultSpeechRate * 0.6` rounded to the nearest
///     hundredth (`AVSpeechUtterance` only accepts a Float in
///     [minimum, maximum]).
///
/// Pinned values live in `SpeechRateTests.swift`.
public enum SpeechRate: Sendable, Equatable {
    case normal
    case slow

    public var value: Float {
        switch self {
        case .normal: return 0.42
        case .slow: return 0.35
        }
    }
}

/// Local text-to-speech using macOS `AVSpeechSynthesizer`. No network, no
/// account, no telemetry — aligned with the privacy-first constitution.
///
/// **Concurrency:** the class is intentionally NOT `@MainActor`. SwiftUI
/// callsites (`.onAppear`, `.onChange`) are synchronous nonisolated closures
/// under Swift 5.9 strict concurrency, so an actor-isolated `speakEnglish`
/// can't be called from them. Instead we hop to `DispatchQueue.main` inside
/// the method — `AVSpeechSynthesizer` is single-thread-confined to main
/// anyway, so this funnel is the right place to enforce it.
public final class SpeechService: ObservableObject, @unchecked Sendable {
    public static let shared = SpeechService()

    /// UserDefaults key for the auto-speak mute preference (v1.4.1 F3).
    public static let muteDefaultsKey = "gramart.speech.muted"

    private let synth = AVSpeechSynthesizer()
    private let defaults: UserDefaults

    /// Currently selected accent. Default: en-US.
    public var accent: EnglishAccent = .usa

    /// When `true`, auto-fired `speakEnglish` calls (those without
    /// `isUserInitiated: true`) become no-ops. User taps on the 🔊 button
    /// still play. Persisted in UserDefaults under `muteDefaultsKey`.
    /// v1.4.1 F3 — system "Do Not Disturb" / Focus detection on macOS lacks
    /// a clean public API, so we ship the user-toggle only; system-quiet
    /// awareness is deferred to v1.5+.
    ///
    /// F009 v1.10.0 blocker fix (Priya): promoted from a UserDefaults
    /// computed property to `@Published` so SwiftUI views observing
    /// `SpeechService.shared` (notably `SpeakButton`) invalidate their
    /// body the same tick the flag flips — previously the icon only
    /// refreshed at the next question boundary, making ⌘M look broken
    /// on every currently-visible speaker button. The `didSet` keeps
    /// the UserDefaults persistence contract intact so the flag still
    /// survives relaunch.
    @Published public var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: Self.muteDefaultsKey) }
    }

    private static var cachedVoice: [EnglishAccent: AVSpeechSynthesisVoice] = [:]

    /// `defaults` is injectable for testing; production uses `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMuted = defaults.bool(forKey: Self.muteDefaultsKey)
    }

    /// Speaks the given English text. Cancels any utterance in progress so
    /// rapid taps replace each other instead of queueing.
    ///
    /// `AVSpeechUtteranceDefaultSpeechRate` is too fast for single-word
    /// vocabulary practice (sounds clipped/synthetic). We default to 0.42,
    /// roughly 85% of default, which is what Apple's own Translate app uses
    /// for single-word readings and matches the natural cadence of Google
    /// Translate per-word audio.
    ///
    /// - Parameter isUserInitiated: pass `true` from explicit user taps on
    ///   the 🔊 button. Defaults to `false` so auto-fire callsites
    ///   (`.onAppear`, `.onChange`) honor the mute toggle.
    /// F007 (v1.8.0) — named-rate overload. Same semantics as the
    /// `Float` variant, but call-sites use `.normal` / `.slow` so the
    /// "lento" button can't accidentally pick a different concrete rate
    /// than the audit tests pin.
    public func speakEnglish(_ text: String, rate: SpeechRate, isUserInitiated: Bool = false) {
        speakEnglish(text, rate: rate.value, isUserInitiated: isUserInitiated)
    }

    public func speakEnglish(_ text: String, rate: Float = 0.42, isUserInitiated: Bool = false) {
        // v1.4.1 F3: mute toggle short-circuits auto-fire only — manual taps
        // always play so users can replay a word even with auto-speak off.
        if isMuted && !isUserInitiated { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Hop to main so AVSpeechSynthesizer is always touched from the same
        // thread, regardless of how the caller is isolated.
        let runOnMain: () -> Void = { [weak self] in
            guard let self else { return }
            if self.synth.isSpeaking { self.synth.stopSpeaking(at: .immediate) }
            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = self.preferredEnglishVoice()
            utterance.rate = rate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            utterance.preUtteranceDelay = 0.05
            utterance.postUtteranceDelay = 0.05
            self.synth.speak(utterance)
        }
        if Thread.isMainThread { runOnMain() } else { DispatchQueue.main.async(execute: runOnMain) }
    }

    /// Returns the best available voice for the current accent, preferring
    /// premium > enhanced > default quality. Logs the chosen voice once per
    /// process so devs can confirm it's not falling back to a basic voice.
    private func preferredEnglishVoice() -> AVSpeechSynthesisVoice? {
        if let cached = Self.cachedVoice[accent] { return cached }
        let langPrefix = accent.rawValue          // "en-US" or "en-GB"
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == langPrefix }
            .sorted { lhs, rhs in
                func rank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
                    switch q {
                    case .premium: return 0
                    case .enhanced: return 1
                    default: return 2
                    }
                }
                let lr = rank(lhs.quality), rr = rank(rhs.quality)
                if lr != rr { return lr < rr }
                return lhs.name < rhs.name
            }
        let chosen = voices.first
            ?? AVSpeechSynthesisVoice(language: langPrefix)
            ?? AVSpeechSynthesisVoice(language: "en")
        if let c = chosen {
            Self.cachedVoice[accent] = c
            print("[SpeechService] using voice: \(c.name) [\(c.language)] quality=\(c.quality.rawValue) id=\(c.identifier)")
        }
        return chosen
    }
}
