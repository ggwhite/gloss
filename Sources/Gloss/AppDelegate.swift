import AppKit
import Combine
import GlossCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Seconds between due/nudge checks and the fallback vault poll. See MECHANICS.md.
    static let tick: TimeInterval = 60

    let settings = AppSettings()
    lazy var model = AppModel(settings: settings, store: StateStore(url: StateStore.defaultURL))
    let router = Router()
    let notifier = Notifier()
    let fix = FixController()
    private lazy var watcher = VaultWatcher { [weak self] in self?.model.reloadVault() }
    private var timer: Timer?
    private var windows: [String: NSWindow] = [:]
    private var bag: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        router.showStats = { [weak self] in self?.showWindow("stats", title: "Gloss Stats") { StatsView() } }
        router.showSettings = { [weak self] in
            guard let self else { return }
            self.showWindow("settings", title: "Gloss Settings") { SettingsView(settings: self.settings) }
        }
        router.showQuizWindow = { [weak self] in self?.showQuizWindow() }
        router.fixEnglish = { [weak self] in self?.fix.trigger() }
        router.hotKeyLabel = { [weak self] in self?.settings.hotKey.display ?? "" }

        notifier.onOpen = { [weak self] in self?.showQuizWindow() }
        notifier.setUp()

        HotKeyCenter.shared.onPress = { [weak self] in self?.fix.trigger() }
        HotKeyCenter.shared.register(settings.hotKey)

        watcher.watch(Vault.resolve(settings.vaultPath))
        settings.$vaultPath.removeDuplicates().dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] path in self?.watcher.watch(Vault.resolve(path)) }
            .store(in: &bag)

        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickNow() }
        }
        tickNow()
    }

    /// Reloads the vault when it changed (polling fallback), updates the badge, and sends a nudge when it is time.
    func tickNow() {
        model.reloadVault()
        model.refreshDue()
        guard settings.nudgesOn else { return }
        let now = Date()
        if NudgePolicy.shouldNudge(now: now, lastNudge: settings.lastNudge, intervalMinutes: settings.nudgeMinutes,
                                   dueCount: model.dueCount, quiet: settings.quietHours, calendar: .current) {
            settings.lastNudge = now
            notifier.post(due: model.dueCount, example: model.dueCards().first.map(CardPrompt.text(for:)))
        }
    }

    private func showQuizWindow() {
        showWindow("quiz", title: "Gloss Quiz") { QuizView() }
    }

    private func showWindow<V: View>(_ id: String, title: String, @ViewBuilder content: () -> V) {
        let window: NSWindow
        if let w = windows[id] {
            window = w
        } else {
            let root = content().environmentObject(model).environmentObject(router)
            let host = NSHostingController(rootView: root)
            window = NSWindow(contentViewController: host)
            window.title = title
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.center()
            windows[id] = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
