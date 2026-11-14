import Foundation

/// One installed speech voice, as Gloss sees it (kept free of AVFoundation so it can be tested).
public struct VoiceInfo: Equatable, Sendable {
    public enum Quality: Int, Comparable, Sendable {
        case standard = 1, enhanced = 2, premium = 3
        public static func < (a: Quality, b: Quality) -> Bool { a.rawValue < b.rawValue }
        public var label: String {
            switch self { case .standard: "Standard"; case .enhanced: "Enhanced"; case .premium: "Premium" }
        }
    }
    public let id: String
    public let name: String
    public let language: String
    public let quality: Quality
    public let novelty: Bool

    public init(id: String, name: String, language: String, quality: Quality, novelty: Bool = false) {
        self.id = id; self.name = name; self.language = language; self.quality = quality; self.novelty = novelty
    }

    /// Old robotic engines: the Eloquence voices (Eddy, Flo, Reed...) and the classic ones (Fred, Ralph...).
    public var isRobotic: Bool {
        id.hasPrefix("com.apple.eloquence.") || id.hasPrefix("com.apple.speech.synthesis.voice.")
    }

    /// "Ava · Premium · US"
    public var title: String {
        let region = language.split(separator: "-").dropFirst().first.map(String.init) ?? language
        return "\(name) · \(quality.label) · \(region)"
    }
}

/// Picks the most natural English voice. See MECHANICS.md ("Pronunciation").
public enum VoicePicker {
    /// English voices worth offering, best first.
    public static func ranked(_ voices: [VoiceInfo]) -> [VoiceInfo] {
        voices.filter { $0.language.hasPrefix("en") && !$0.novelty && !$0.isRobotic }
            .sorted { a, b in
                let sa = score(a), sb = score(b)
                return sa != sb ? sa > sb : a.name < b.name
            }
    }

    /// The chosen voice when it is still installed, otherwise the best one.
    public static func pick(_ voices: [VoiceInfo], chosen: String?) -> VoiceInfo? {
        if let chosen, !chosen.isEmpty, let v = voices.first(where: { $0.id == chosen }) { return v }
        return ranked(voices).first
    }

    /// True when no Enhanced or Premium English voice is installed (the user should download one).
    public static func needsBetterVoice(_ voices: [VoiceInfo]) -> Bool {
        !ranked(voices).contains { $0.quality >= .enhanced }
    }

    static func score(_ v: VoiceInfo) -> Int {
        let accent: Int
        switch v.language {
        case "en-US": accent = 20
        case "en-GB": accent = 15
        default: accent = 5
        }
        return v.quality.rawValue * 100 + accent
    }
}
