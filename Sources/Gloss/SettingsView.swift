import AppKit
import ApplicationServices
import GlossCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("How Gloss works") {
                explain("tablecells", Theme.link, "Where the words come from",
                        "The table under “## 拼字” in 單字.md (and “## 用字” if that deck is on): the 中文 column is the question, 正確拼法 is the answer, 記法 is the hint shown after a mistake. \(model.entries.count) cards right now. Gloss only reads the file.")
                explain("checkmark.circle", Theme.good, "How an answer is checked — no AI",
                        "Your typing must match 正確拼法 exactly, ignoring upper/lower case and extra spaces. When it doesn't, a letter-by-letter comparison (edit distance) marks the letters that differ.")
                explain("sparkles", Theme.violet, "When AI is used",
                        "Only for Fix My English: the text you select or paste goes to the claude command (Claude Code) on this Mac. The quiz, schedule, stats and pronunciation (the macOS voice) all run offline.")
            }
            Section("Vault (read-only)") {
                HStack {
                    TextField("Folder", text: $settings.vaultPath)
                    Button("Choose…", action: chooseFolder)
                        .buttonStyle(GlassPillStyle(compact: true))
                }
                Text(vaultSummary).font(.caption).foregroundStyle(.secondary)
                ForEach(model.snapshot.problems, id: \.self) { p in
                    Text(p).font(.caption).foregroundStyle(Theme.warn)
                }
            }
            Section("Decks") {
                Toggle("Spelling (## 拼字) — \(model.snapshot.decks[.spelling]?.count ?? 0) cards", isOn: $settings.spellingDeck)
                Toggle("Word choice (## 用字) — \(model.snapshot.decks[.usage]?.count ?? 0) cards", isOn: $settings.usageDeck)
                Stepper("New cards per day: \(settings.newPerDay)", value: $settings.newPerDay, in: 0...200, step: 5)
            }
            Section("Pronunciation") {
                Toggle("Say the word after each answer", isOn: $settings.speakOnAnswer)
                Toggle("Say the word when a card appears (dictation mode)", isOn: $settings.speakOnShow)
                HStack {
                    Text("Voice: system English (en-US). Press ⌘P on a card to hear it.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { Pronouncer.shared.say("pronunciation") } label: { Label("Test", systemImage: "speaker.wave.2.fill") }
                        .buttonStyle(GlassPillStyle(compact: true))
                }
            }
            Section("Reminders") {
                Toggle("Remind me when cards are due", isOn: $settings.nudgesOn)
                Stepper("Every \(settings.nudgeMinutes) minutes", value: $settings.nudgeMinutes, in: 5...480, step: 5)
                    .disabled(!settings.nudgesOn)
                HStack {
                    Text("Quiet hours")
                    Spacer()
                    DatePicker("From", selection: minutesBinding($settings.quietStart), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("to")
                    DatePicker("To", selection: minutesBinding($settings.quietEnd), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .disabled(!settings.nudgesOn)
            }
            Section("Shortcuts") {
                HStack {
                    Text("Open Gloss (from anywhere)")
                    Spacer()
                    HotKeyRecorder(combo: $settings.openHotKey, defaultCombo: .openDefault)
                }
                HStack {
                    Text("Fix my English")
                    Spacer()
                    HotKeyRecorder(combo: $settings.hotKey, defaultCombo: .default)
                }
                HStack {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? Theme.good : Theme.warn)
                    Text(trusted ? "Accessibility permission granted" : "Needs Accessibility permission to copy your selection")
                    Spacer()
                    if !trusted {
                        Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                            .buttonStyle(GlassPillStyle(tint: Theme.accent, prominent: true, compact: true))
                    }
                }
            }
            Section("General") {
                Toggle("Show in the Dock and ⌘Tab while the Gloss window is open", isOn: $settings.dockWhileOpen)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(Theme.warn) }
                Text("Progress: ~/Library/Application Support/Gloss/state.json").font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .fontDesign(.rounded)
        .frame(minWidth: 520, maxWidth: 760)
        .frame(maxWidth: .infinity)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = AXIsProcessTrusted()
        }
    }

    private func explain(_ icon: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var vaultSummary: String {
        let s = model.snapshot
        return "\(model.resolvedVaultPath) · \(s.decks[.spelling]?.count ?? 0) spelling, \(s.decks[.usage]?.count ?? 0) word-choice cards, \(s.mistakes.count) mistake lines"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = Vault.resolve(settings.vaultPath)
        if panel.runModal() == .OK, let url = panel.url {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            settings.vaultPath = url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
        }
    }

    private func minutesBinding(_ b: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(b.wrappedValue * 60)) },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                b.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not change it: \(error.localizedDescription) (run Gloss from the .app bundle)."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// A button that records the next shortcut pressed.
struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo
    var defaultCombo: HotKeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(recording ? "Press a shortcut…" : combo.display) { recording ? stop() : start() }
                .frame(minWidth: 120)
            if combo != defaultCombo {
                Button("Reset") { combo = defaultCombo }
            }
        }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil } // Esc cancels
            if let c = HotKeyCombo(event: event) {
                combo = c
                stop()
                return nil
            }
            return event
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

enum Permissions {
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Asks macOS to show its permission prompt (once) and returns the current state.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
