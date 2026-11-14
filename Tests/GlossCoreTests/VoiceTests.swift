import XCTest
@testable import GlossCore

final class VoiceTests: XCTestCase {
    private let compactUS = VoiceInfo(id: "com.apple.voice.compact.en-US.Zelda", name: "Zelda", language: "en-US", quality: .standard)
    private let enhancedGB = VoiceInfo(id: "com.apple.voice.enhanced.en-GB.Quill", name: "Quill", language: "en-GB", quality: .enhanced)
    private let premiumUS = VoiceInfo(id: "com.apple.voice.premium.en-US.Mabel", name: "Mabel", language: "en-US", quality: .premium)
    private let robot = VoiceInfo(id: "com.apple.eloquence.en-US.Bolt", name: "Bolt", language: "en-US", quality: .standard)
    private let classic = VoiceInfo(id: "com.apple.speech.synthesis.voice.Gear", name: "Gear", language: "en-US", quality: .standard)
    private let novelty = VoiceInfo(id: "com.apple.voice.compact.en-US.Bubbles", name: "Bubbles", language: "en-US", quality: .standard, novelty: true)
    private let french = VoiceInfo(id: "com.apple.voice.premium.fr-FR.Lune", name: "Lune", language: "fr-FR", quality: .premium)

    func testBestQualityWinsOverAccent() {
        let all = [compactUS, robot, enhancedGB, premiumUS, french, novelty, classic]
        XCTAssertEqual(VoicePicker.ranked(all).map(\.name), ["Mabel", "Quill", "Zelda"])
        XCTAssertEqual(VoicePicker.pick(all, chosen: nil)?.name, "Mabel")
    }

    func testRoboticAndNoveltyVoicesAreLeftOut() {
        XCTAssertTrue(VoicePicker.ranked([robot, classic, novelty, french]).isEmpty)
    }

    func testChosenVoiceIsKeptWhileInstalled() {
        XCTAssertEqual(VoicePicker.pick([compactUS, premiumUS], chosen: compactUS.id)?.name, "Zelda")
        XCTAssertEqual(VoicePicker.pick([compactUS, premiumUS], chosen: "gone.voice")?.name, "Mabel")
        XCTAssertEqual(VoicePicker.pick([compactUS, premiumUS], chosen: "")?.name, "Mabel")
    }

    func testNeedsBetterVoiceOnlyWithStandardVoices() {
        XCTAssertTrue(VoicePicker.needsBetterVoice([compactUS, robot]))
        XCTAssertFalse(VoicePicker.needsBetterVoice([compactUS, enhancedGB]))
    }

    func testTitle() {
        XCTAssertEqual(premiumUS.title, "Mabel · Premium · US")
    }
}
