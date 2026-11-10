import AppKit
import SwiftUI

/// The app icon, drawn on a 1024 × 1024 canvas (macOS grid: an 824 pt rounded square with 100 pt margins).
/// A blue-violet tile with two frosted flashcards: the front one shows "Aa" and a mint check.
struct IconArt: View {
    static let canvas: CGFloat = 1024
    private let body824: CGFloat = 824

    var body: some View {
        ZStack {
            // Shadow under the tile.
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .frame(width: body824, height: body824)
                .blur(radius: 18)
                .offset(y: 14)

            tile
                .frame(width: body824, height: body824)
                .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 6))
        }
        .frame(width: Self.canvas, height: Self.canvas)
    }

    private var tile: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.22, green: 0.40, blue: 1.00), Color(red: 0.42, green: 0.27, blue: 0.98),
                                    Color(red: 0.58, green: 0.22, blue: 0.92)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 0.45, green: 0.95, blue: 0.90).opacity(0.55), .clear],
                           center: UnitPoint(x: 0.15, y: 0.10), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(red: 1.0, green: 0.45, blue: 0.75).opacity(0.45), .clear],
                           center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 520)
            // Top sheen.
            LinearGradient(colors: [Color.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)

            // Back card (tilted right, mint tint).
            card(tint: Color(red: 0.40, green: 0.95, blue: 0.85), opacity: 0.22)
                .rotationEffect(.degrees(9))
                .offset(x: 46, y: -30)

            // Front card (tilted left) with "Aa" and the spelling blanks.
            card(tint: .white, opacity: 0.20)
                .overlay(alignment: .center) {
                    VStack(spacing: 18) {
                        Text("Aa")
                            .font(.system(size: 230, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: Color(red: 0.15, green: 0.10, blue: 0.45).opacity(0.45), radius: 10, y: 6)
                        HStack(spacing: 22) {
                            ForEach(0..<4, id: \.self) { _ in
                                Capsule().fill(Color.white.opacity(0.85)).frame(width: 52, height: 14)
                            }
                        }
                    }
                    .offset(y: 6)
                }
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.98, blue: 0.85), Color(red: 0.20, green: 0.80, blue: 0.75)],
                                                 startPoint: .top, endPoint: .bottom))
                        Circle().stroke(Color.white.opacity(0.9), lineWidth: 8)
                        Image(systemName: "checkmark")
                            .font(.system(size: 78, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 148, height: 148)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
                    .offset(x: 46, y: 46)
                }
                .rotationEffect(.degrees(-6))
                .offset(x: -26, y: 26)
        }
    }

    private func card(tint: Color, opacity: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 64, style: .continuous)
        return shape
            .fill(tint.opacity(opacity))
            .background(shape.fill(Color.white.opacity(0.06)))
            .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.15)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 6))
            .frame(width: 470, height: 540)
            .shadow(color: Color(red: 0.10, green: 0.05, blue: 0.35).opacity(0.45), radius: 30, y: 18)
    }
}

/// The app icon at any size, for logos inside the app. Drawn once per size into an image: the vector art
/// has blurred shadows that are costly to draw again on every frame of the floating logo.
struct AppIconView: View {
    var size: CGFloat

    var body: some View {
        Image(nsImage: Self.image(size: size))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }

    @MainActor private static var cache: [CGFloat: NSImage] = [:]

    @MainActor static func image(size: CGFloat) -> NSImage {
        if let img = cache[size] { return img }
        let scale = max(NSScreen.main?.backingScaleFactor ?? 2, 2)
        let r = ImageRenderer(content: IconArt()
            .scaleEffect(size / IconArt.canvas * 1.2)
            .frame(width: size, height: size))
        r.scale = scale
        let img = r.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        cache[size] = img
        return img
    }
}

/// `--render-icon <folder.iconset>`: writes every size macOS needs; `iconutil` turns it into AppIcon.icns.
@MainActor
enum IconRenderer {
    static func run(to folder: String) -> Int32 {
        let url = URL(fileURLWithPath: folder)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let sizes: [(String, CGFloat)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024),
        ]
        for (name, px) in sizes {
            let r = ImageRenderer(content: IconArt())
            r.scale = px / IconArt.canvas
            guard let cg = r.cgImage else { print("could not render \(name)"); return 1 }
            let rep = NSBitmapImageRep(cgImage: cg)
            guard let data = rep.representation(using: .png, properties: [:]) else { return 1 }
            try? data.write(to: url.appendingPathComponent(name + ".png"))
        }
        print("Wrote \(sizes.count) icon sizes to \(folder)")
        return 0
    }
}
