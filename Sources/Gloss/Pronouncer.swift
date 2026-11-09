import AVFoundation
import Combine
import SwiftUI

/// Says English words aloud with the system voice (no network).
@MainActor
final class Pronouncer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Pronouncer()

    /// Speech speed as a share of the system default. See MECHANICS.md.
    static let rateFactor: Float = 0.85
    static let language = "en-US"

    private let synth = AVSpeechSynthesizer()
    /// Screenshot and self-test record what would be said instead of making a sound.
    var muted = false
    private(set) var lastSpoken: String?
    private(set) var spokenCount = 0
    /// The text being spoken now; speaker buttons animate while it matches.
    @Published private(set) var speaking: String?

    override init() {
        super.init()
        synth.delegate = self
    }

    func say(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lastSpoken = t
        spokenCount += 1
        guard !muted else { return }
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: Self.language)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * Self.rateFactor
        speaking = t
        synth.speak(u)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in if self.speaking == text { self.speaking = nil } }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in if self.speaking == text { self.speaking = nil } }
    }
}

/// A round speaker button that ripples while its text is being spoken.
@MainActor
struct SpeakerButton: View {
    let text: String
    var size: CGFloat = 30
    @ObservedObject private var pronouncer = Pronouncer.shared

    var body: some View {
        Button { pronouncer.say(text) } label: {
            Image(systemName: "speaker.wave.3.fill")
                .symbolEffect(.variableColor.iterative.reversing, isActive: pronouncer.speaking == text)
        }
        .buttonStyle(GlassCircleStyle(size: size))
        .help("Hear “\(text)”")
        .accessibilityLabel("Pronounce")
    }
}
