import AppKit
import AVFoundation
import GlossCore
import Combine
import SwiftUI

/// Says English words aloud with the most natural installed voice (on the Mac, no network).
@MainActor
final class Pronouncer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Pronouncer()

    /// Speech speed as a share of the system default. See MECHANICS.md.
    static let rateFactor: Float = 0.9
    /// The voice id from Settings; empty picks the best one. Set by AppSettings.
    nonisolated(unsafe) static var chosenVoice = ""
    /// System Settings → Accessibility → Spoken Content, where voices are downloaded.
    static let voicesSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent")!

    /// English voices worth offering, best first. Read again when Gloss becomes active
    /// (a voice downloaded meanwhile shows up).
    @Published private(set) var voices: [VoiceInfo] = []
    private var systemVoices: [String: AVSpeechSynthesisVoice] = [:]

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
        reloadVoices()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Pronouncer.shared.reloadVoices() }
        }
    }

    func reloadVoices() {
        var map: [String: AVSpeechSynthesisVoice] = [:]
        let infos: [VoiceInfo] = AVSpeechSynthesisVoice.speechVoices().map { v in
            map[v.identifier] = v
            let q: VoiceInfo.Quality = v.quality == .premium ? .premium : v.quality == .enhanced ? .enhanced : .standard
            return VoiceInfo(id: v.identifier, name: v.name, language: v.language, quality: q,
                             novelty: v.voiceTraits.contains(.isNoveltyVoice) || v.voiceTraits.contains(.isPersonalVoice))
        }
        systemVoices = map
        let ranked = VoicePicker.ranked(infos)
        if ranked != voices { voices = ranked }
    }

    /// The voice Gloss speaks with now.
    var current: VoiceInfo? { VoicePicker.pick(voices, chosen: Self.chosenVoice) }
    /// True when only Standard (compressed, robotic) voices are installed.
    var needsBetterVoice: Bool { VoicePicker.needsBetterVoice(voices) }

    func say(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lastSpoken = t
        spokenCount += 1
        guard !muted else { return }
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: t)
        u.voice = current.flatMap { systemVoices[$0.id] } ?? AVSpeechSynthesisVoice(language: "en-US")
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
