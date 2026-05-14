import AVFoundation
import Foundation

/// English accent — locale flavor for the TTS voice.
public enum EnglishAccent: String, CaseIterable, Sendable {
    case usa = "en-US"
    case british = "en-GB"
}

/// Local text-to-speech using macOS `AVSpeechSynthesizer`. No network, no
/// account, no telemetry — aligned with the privacy-first constitution.
@MainActor
public final class SpeechService {
    public static let shared = SpeechService()

    private let synth = AVSpeechSynthesizer()

    /// Currently selected accent. Default: en-US.
    public var accent: EnglishAccent = .usa

    /// Speaks the given English text. Cancels any utterance in progress so
    /// rapid taps replace each other instead of queueing.
    ///
    /// `AVSpeechUtteranceDefaultSpeechRate` is too fast for single-word
    /// vocabulary practice (sounds clipped/synthetic). We default to 0.42,
    /// roughly 85% of default, which is what Apple's own Translate app uses
    /// for single-word readings and matches the natural cadence of Google
    /// Translate per-word audio.
    public func speakEnglish(_ text: String, rate: Float = 0.42) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredEnglishVoice()
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        // Small silence padding so single-word utterances don't sound abrupt.
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05
        synth.speak(utterance)
    }

    /// Returns the best available voice for the current accent, preferring
    /// premium > enhanced > default quality. Logs the chosen voice once per
    /// process so devs can confirm it's not falling back to a basic voice.
    private func preferredEnglishVoice() -> AVSpeechSynthesisVoice? {
        if let cached = Self.cachedVoice[accent] { return cached }
        let langPrefix = accent.rawValue          // "en-US" or "en-GB"
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == langPrefix }
            // Premium > enhanced > default, then by name for stability.
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

    private static var cachedVoice: [EnglishAccent: AVSpeechSynthesisVoice] = [:]
}
