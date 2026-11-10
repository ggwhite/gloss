import AppKit
import GlossCore
import SwiftUI

/// The state of the floating fix-my-English panel.
@MainActor
final class FixModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case copying
        case asking(String)
        case done(String, FixResult)
        case failed(String, needsPermission: Bool)
    }
    @Published var phase: Phase = .idle
    @Published var copied: String?
}

struct FixView: View {
    @ObservedObject var model: FixModel
    /// Inside the main window: no header, no own glass panel.
    var embedded = false
    var close: () -> Void = {}
    var retry: () -> Void = {}

    var body: some View {
        if embedded {
            inner
        } else {
            inner
                .padding(18)
                .frame(width: 460)
                .fontDesign(.rounded)
                .glassGroup(spacing: 10)
                .glassCard(radius: 34, tint: Theme.accent, strength: 0.10)
        }
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !embedded { panelHeader }
            phaseView
        }
    }

    private var panelHeader: some View {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .glass(Circle(), tint: Theme.violet, strength: 0.85)
                Text("Fix my English").font(.system(size: 16, weight: .bold))
                Spacer()
                Button { close() } label: { Image(systemName: "xmark") }
                    .buttonStyle(GlassCircleStyle(size: 26))
                    .keyboardShortcut(.cancelAction)
            }
    }

    @ViewBuilder private var phaseView: some View {
            switch model.phase {
            case .idle where embedded:
                EmptyView()
            case .idle, .copying:
                ProgressView("Copying your selection…")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard(radius: 24, strength: 0.06)
            case .asking(let original):
                originalBox(original)
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Asking Claude… (up to \(Int(FixPrompt.timeout)) s)").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            case .done(let original, let result):
                originalBox(original)
                resultBox(title: "Fixed", text: result.fixed, tint: Theme.good).appearIn(delay: 0.05)
                resultBox(title: "Shorter", text: result.short, tint: Theme.blue).appearIn(delay: 0.15)
                mistakes(result.mistakes).appearIn(delay: 0.25)
            case .failed(let message, let needsPermission):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(14)
                    .glassCard(radius: 24, tint: Theme.warn, strength: 0.1)
                HStack {
                    if needsPermission {
                        Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                            .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true))
                            .keyboardShortcut(.defaultAction)
                    }
                    Button("Try again") { retry() }
                        .buttonStyle(GlassPillStyle())
                }
            }
    }

    private func originalBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.quote").foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(radius: 22, strength: 0.04)
    }

    private func resultBox(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title.uppercased()).font(.caption2.weight(.heavy)).kerning(0.8).foregroundStyle(tint)
                Spacer()
                ListenButton(text: text)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    model.copied = title
                } label: {
                    Label(model.copied == title ? "Copied" : "Copy", systemImage: model.copied == title ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(GlassPillStyle(tint: tint, prominent: true, compact: true))
            }
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .glassCard(radius: 24, tint: tint, strength: 0.10)
    }

    @ViewBuilder private func mistakes(_ items: [FixResult.Item]) -> some View {
        if items.isEmpty {
            Label("No mistakes found.", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.good)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("MISTAKES").font(.caption2.weight(.heavy)).kerning(0.8).foregroundStyle(.secondary)
                ForEach(Array(items.enumerated()), id: \.offset) { i, m in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(m.from).strikethrough(color: Theme.bad).foregroundStyle(Theme.bad)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                            Text(m.to).foregroundStyle(Theme.good).fontWeight(.semibold)
                            Spacer()
                            if !m.category.isEmpty {
                                Text("#\(m.category)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .glass(Capsule(), tint: Theme.accent, strength: 0.15)
                            }
                        }
                        .font(.system(.callout, design: .monospaced))
                        Text(m.why_zh).font(.caption).foregroundStyle(.secondary)
                    }
                    if i < items.count - 1 { Divider().opacity(0.4) }
                }
            }
            .padding(12)
            .glassCard(radius: 24, strength: 0.04)
        }
    }
}

/// A borderless panel that can still take key focus (for Esc and the Copy buttons).
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the floating panel and runs the copy → claude → show flow.
@MainActor
final class FixController {
    let model = FixModel()
    private var panel: NSPanel?
    private var task: Task<Void, Never>?

    func trigger() {
        task?.cancel()
        model.copied = nil
        model.phase = .copying
        task = Task { [weak self] in
            guard let self else { return }
            let text: String
            do {
                text = try await SelectionGrabber.copySelection()
            } catch SelectionGrabber.Failure.noPermission {
                Permissions.requestAccessibility()
                self.show()
                self.model.phase = .failed(SelectionGrabber.Failure.noPermission.localizedDescription, needsPermission: true)
                return
            } catch {
                self.show()
                self.model.phase = .failed(error.localizedDescription, needsPermission: false)
                return
            }
            self.model.phase = .asking(text)
            self.show()
            do {
                let result = try await ClaudeRunner.fix(text)
                guard !Task.isCancelled else { return }
                self.model.phase = .done(text, result)
            } catch {
                guard !Task.isCancelled else { return }
                self.model.phase = .failed(error.localizedDescription, needsPermission: false)
            }
            self.panel?.setContentSize(self.panel?.contentView?.fittingSize ?? .zero)
        }
    }

    func show() {
        if panel == nil {
            let p = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
                            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.isMovableByWindowBackground = true
            p.appearance = Theme.darkAppearance
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.isReleasedWhenClosed = false
            p.becomesKeyOnlyIfNeeded = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let host = NSHostingView(rootView: FixView(model: model, close: { [weak self] in self?.close() },
                                                       retry: { [weak self] in self?.close(); self?.trigger() })
                .trackWindowVisibility())
            host.sizingOptions = [.preferredContentSize]
            host.wantsLayer = true
            host.layer?.backgroundColor = .clear
            p.contentView = host
            panel = p
            positionNearMouse(p)
        }
        if panel?.isVisible == false, let panel { positionNearMouse(panel) }
        panel?.orderFrontRegardless()
        panel?.makeKey()
    }

    func close() {
        task?.cancel()
        panel?.orderOut(nil)
    }

    private func positionNearMouse(_ p: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { p.center(); return }
        let size = p.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 20)
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        p.setFrameOrigin(origin)
    }
}

/// "Listen" pill that ripples while its sentence is spoken.
struct ListenButton: View {
    let text: String
    @ObservedObject private var pronouncer = Pronouncer.shared

    var body: some View {
        Button { pronouncer.say(text) } label: {
            Label("Listen", systemImage: "speaker.wave.3.fill")
                .symbolEffect(.variableColor.iterative.reversing, isActive: pronouncer.speaking == text)
        }
        .buttonStyle(GlassPillStyle(compact: true))
    }
}
