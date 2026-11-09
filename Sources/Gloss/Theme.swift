import AppKit
import SwiftUI

/// The dark blue-violet palette used everywhere. See MECHANICS.md ("Look").
enum Theme {
    /// Main accent: blue-violet.
    static let accent = Color(red: 0.49, green: 0.44, blue: 1.00)
    static let blue = Color(red: 0.33, green: 0.58, blue: 1.00)
    static let violet = Color(red: 0.69, green: 0.42, blue: 1.00)
    /// Right answers: cool mint, so it sits well with blue.
    static let good = Color(red: 0.38, green: 0.92, blue: 0.84)
    /// Wrong answers and the due badge: rose.
    static let bad = Color(red: 1.00, green: 0.40, blue: 0.62)
    /// Hints and warnings: soft amber.
    static let warn = Color(red: 1.00, green: 0.74, blue: 0.42)

    static let navy = Color(red: 0.05, green: 0.06, blue: 0.17)
    static let plum = Color(red: 0.14, green: 0.07, blue: 0.29)

    /// Text buttons inside tiles ("Start", "Open Stats").
    static let link = Color(red: 0.47, green: 0.78, blue: 1.00)

    /// The tone laid over window and popover glass: deep indigo into violet, with a glow at the bottom right.
    static var wash: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.06, blue: 0.24).opacity(0.86),
                                    Color(red: 0.26, green: 0.10, blue: 0.55).opacity(0.80)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 0.55, green: 0.25, blue: 0.95).opacity(0.45), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color(red: 0.20, green: 0.35, blue: 0.95).opacity(0.25), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 320)
        }
    }

    static let darkAppearance = NSAppearance(named: .darkAqua)

    /// Corner radius of the menu bar popover window. See MECHANICS.md ("Look").
    static let popoverRadius: CGFloat = 22
}
