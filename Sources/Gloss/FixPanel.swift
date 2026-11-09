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
    var close: () -> Void = {}
    var retry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(Color.accentColor)
                Text("Fix my English").font(.headline)
                Spacer()
                Button { close() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
            }
            switch model.phase {
            case .idle, .copying:
                ProgressView("Copying your selection…")
            case .asking(let original):
                originalBox(original)
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Asking Claude… (up to \(Int(FixPrompt.timeout)) s)").foregroundStyle(.secondary)
                }
            case .done(let original, let result):
                originalBox(original)
                resultBox(title: "Fixed", text: result.fixed)
                resultBox(title: "Shorter", text: result.short)
                mistakes(result.mistakes)
            case .failed(let message, let needsPermission):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                HStack {
                    if needsPermission {
                        Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                            .keyboardShortcut(.defaultAction)
                    }
                    Button("Try again") { retry() }
                }
            }
        }
        .padding(16)
        .frame(width: 460)
    }

    private func originalBox(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
    }

    private func resultBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(model.copied == title ? "Copied ✓" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    model.copied = title
                }
                .controlSize(.small)
            }
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
    }

    @ViewBuilder private func mistakes(_ items: [FixResult.Item]) -> some View {
        if items.isEmpty {
            Label("No mistakes found.", systemImage: "checkmark.circle").foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Mistakes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(items.enumerated()), id: \.offset) { _, m in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(m.from).strikethrough(color: .red).foregroundStyle(.red)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                            Text(m.to).foregroundStyle(.green)
                            Spacer()
                            if !m.category.isEmpty {
                                Text("#\(m.category)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            }
                        }
                        .font(.system(.callout, design: .monospaced))
                        Text(m.why_zh).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
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
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
                            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
                            backing: .buffered, defer: false)
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.isReleasedWhenClosed = false
            p.becomesKeyOnlyIfNeeded = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let host = NSHostingView(rootView: FixView(model: model, close: { [weak self] in self?.close() },
                                                       retry: { [weak self] in self?.close(); self?.trigger() }))
            host.sizingOptions = [.preferredContentSize]
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
