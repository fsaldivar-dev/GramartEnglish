import AVFoundation
import Foundation

/// English accent — locale flavor for the TTS voice.
public enum EnglishAccent: String, CaseIterable, Sendable {
    case usa = "en-US"
    case british = "en-GB"
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
public final class SpeechService: @unchecked Sendable {
    public static let shared = SpeechService()

    private let synth = AVSpeechSynthesizer()

    /// Currently selected accent. Default: en-US.
    public var accent: EnglishAccent = .usa

    private static var cachedVoice: [EnglishAccent: AVSpeechSynthesisVoice] = [:]

    /// Speaks the given English text. Cancels any utterance in progress so
    /// rapid taps replace each other instead of queueing.
    ///
    /// `AVSpeechUtteranceDefaultSpeechRate` is too fast for single-word
    /// vocabulary practice (sounds clipped/synthetic). We default to 0.42,
    /// roughly 85% of default, which is what Apple's own Translate app uses
    /// for single-word readings and matches the natural cadence of Google
    /// Translate per-word audio.
    public func speakEnglish(_ text: String, rate: Float = 0.42) {
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
