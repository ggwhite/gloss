import AppKit
import Combine
import GlossCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The running delegate (SwiftUI wraps it, so NSApp.delegate is not this object).
    private(set) static weak var current: AppDelegate?
    /// Seconds between due/nudge checks and the fallback vault poll. See MECHANICS.md.
    static let tick: TimeInterval = 60

    let settings = AppSettings()
    lazy var model = AppModel(settings: settings, store: StateStore(url: StateStore.defaultURL))
    let router = Router()
    let notifier = Notifier()
    lazy var fix = FixController(settings: settings)
    let nav = Navigator()
    private lazy var watcher = VaultWatcher { [weak self] in self?.model.reloadVault() }
    private var timer: Timer?
    private var bag: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.current = self
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = Theme.darkAppearance
        router.showStats = { [weak self] in self?.open(.stats) }
        router.showSettings = { [weak self] in self?.open(.settings) }
        router.showQuizWindow = { [weak self] in self?.open(.quiz) }
        router.fixEnglish = { [weak self] in self?.fix.trigger() }
        router.hotKeyLabel = { [weak self] in self?.settings.hotKey.display ?? "" }
        router.openHotKeyLabel = { [weak self] in self?.settings.openHotKey.display ?? "" }
        router.showOverview = { [weak self] in self?.open(.overview) }

        notifier.onOpen = { [weak self] in self?.open(.quiz) }
        notifier.setUp()

        settings.$dockWhileOpen.removeDuplicates().dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.setInAppSwitcher(self?.mainWindow?.isVisible ?? false) }
            }
            .store(in: &bag)
                settings.$hotKey.removeDuplicates()
            .sink { combo in HotKeyCenter.shared.register(.fixEnglish, combo) { [weak self] in self?.fix.trigger() } }
            .store(in: &bag)
        settings.$openHotKey.removeDuplicates()
            .sink { combo in HotKeyCenter.shared.register(.openMenu, combo) { [weak self] in self?.toggleOverview() } }
            .store(in: &bag)

        watcher.watch(Vault.resolve(settings.vaultPath))
        settings.$vaultPath.removeDuplicates().dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] path in self?.watcher.watch(Vault.resolve(path)) }
            .store(in: &bag)

        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickNow() }
        }
        tickNow()

        // First launch: show the overview once, with the "where to find me" note.
        if PopoverInspector.outputPath != nil {
            PopoverInspector.start()
        } else if !settings.welcomeDone {
            open(.overview)
        }
    }

    /// Opening Gloss.app again while it runs shows the overview (there is no Dock icon to click).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain()
        return false
    }

    /// Shows the one main window on a page. The menu, shortcuts, notifications and reopening all use it.
    func open(_ page: Page) {
        nav.page = page
        showMain()
    }

    private func toggleOverview() {
        if let w = mainWindow, w.isVisible, w.isKeyWindow {
            w.orderOut(nil)
            setInAppSwitcher(false)
        } else {
            open(.overview)
        }
    }

    /// A menu bar app (LSUIElement) is left out of ⌘Tab and the Dock. While the Gloss window is open it
    /// becomes a regular app so ⌘Tab reaches it; when the window closes it goes back to the menu bar only.
    private func setInAppSwitcher(_ on: Bool) {
        let wanted: NSApplication.ActivationPolicy = on && settings.dockWhileOpen ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
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

    private var mainWindow: NSWindow?

    /// Creates the main window once; later calls bring it to the front.
    func showMain() {
        let window: NSWindow
        if let w = mainWindow {
            window = w
        } else {
            let root = MainWindowView()
                .environmentObject(model)
                .environmentObject(router)
                .environmentObject(nav)
                .tint(Theme.accent)
                .background(AnimatedWash().ignoresSafeArea())
                .trackWindowVisibility()
                .background(WindowGlassBackground(material: .hudWindow).ignoresSafeArea())
            let host = NSHostingController(rootView: root)
            host.sizingOptions = [.minSize]
            window = NSWindow(contentViewController: host)
            window.title = "Gloss"
            window.setContentSize(NSSize(width: 1000, height: 760))
            window.setFrameAutosaveName("GlossMainWindow")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
            window.appearance = Theme.darkAppearance
            window.isReleasedWhenClosed = false
            if !window.setFrameUsingName("GlossMainWindow") { window.center() }
            mainWindow = window
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                   queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setInAppSwitcher(false) }
            }
        }
        setInAppSwitcher(true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
